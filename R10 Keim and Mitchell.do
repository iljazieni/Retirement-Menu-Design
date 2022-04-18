************ Keim and Mitchell ***********

use "$temp/collapse2.dta", clear

keep ScrubbedID steady_pre steady_pre_sc smart
bys ScrubbedID: keep if _n == 1
tempfile steady_pre_list 
save "`steady_pre_list'"

use "$temp/full_data.dta", clear
merge m:1 ScrubbedID using "`steady_pre_list'"
// assert _m != 2
// filter to observations in final data (including the smart/steady investors)
keep if _m == 3
drop _m

merge m:1 Fund using "$temp/funds_2016_2017"
gen steady_fund = (_m == 3)
drop _m

// filter to pre- and post-reform
keep if inlist(date, 672, 684, 696)

{ // clean variables
la define steady_pre 0 "Streamlined group" ///
1 "Non-streamlined group"
la val steady_pre steady_pre

// merge in total assets
merge m:1 ScrubbedID date using "$temp/asset_list"
assert _m != 1
keep if _m == 3
drop _m
gen FundsHeld = round(total_assets * port_weight, .01)

keep ScrubbedID date Fund FundsHeld total_assets port_weight steady_pre steady_pre_sc steady_fund AgeasofNov2018 RoundedSalary Gender
gen counter = 1
bys ScrubbedID date: gen n_funds = _N
bys Fund steady_pre date: gen fund_counter = (_n == 1)
gen dropped_dollars = (-1 * (steady_fund-1)) * FundsHeld
gen steady_dollars = steady_fund*FundsHeld

gen female = (Gender == "F")
gen male = (Gender == "M")
gen unknown_gender = (male == 0 & female == 0)

gen age2016 = AgeasofNov2018 - 2
gen age20s = (age2016 < 30)
gen age30s = (age2016 >= 30 & age2016 < 40)
gen age40s = (age2016 >= 40 & age2016 < 50)
gen age50s = (age2016 >= 50 & age2016 < 60)
gen age60s = (age2016 >= 60 & age2016 < 70)
gen age70s = (age2016 >= 70 & age2016 < .)

la var age20s "Age under 30" 
la var age30s "Age 30-39" 
la var age40s "Age 40-49" 
la var age50s "Age 50-59" 
la var age60s "Age 60-69" 
la var age70s "Age 70+" 

la var female "Female"
la var male "Male"
la var unknown_gender "Gender unknown"

la var female "Female"
la var male "Male"
la var unknown_gender "Gender unknown"

}

merge m:1 ScrubbedID using "$temp/plan_defaulted17"
replace plan_defaulted17 = 2 if steady_pre == 1
drop _m

merge m:1 ScrubbedID using "$temp/plan_defaulted18"
replace plan_defaulted18 = 2 if steady_pre == 1
drop _m

preserve
	bys ScrubbedID date: gen temp1 = (_n == 1)
	drop if date == 696
	bys ScrubbedID: egen temp2 = total(temp1)
	assert temp2 == 2 if date != 696
	drop temp*
restore

la val plan_defaulted17 plan_defaulted17
la define plan_defaulted17 0 "Streamlined: Active choice" ///
1 "Streamlined: Passive choice" ///
2 "Non-streamlined"

save "$temp/r10_temp", replace


** Figure 4 **

preserve 

keep if inlist(date,672)

bys ScrubbedID: keep if _n == 1

la var n_funds "No. funds per person"

gen sal50 = (RoundedSalary > 0 & RoundedSalary <= 50000)
gen sal100 = (RoundedSalary > 50000 & RoundedSalary <= 100000)
gen sal150 = (RoundedSalary > 100000 & RoundedSalary <= 200000)
gen saltop = (RoundedSalary > 150000 & RoundedSalary < .)
gen salmissing = (RoundedSalary == 0 | missing(RoundedSalary))

la var sal50 "Salary 50,000 or under"
la var sal100 "Salary 50,000-100,000"
la var sal150 "Salary 100,000-150,000"
la var saltop "Salary over 150,000"
la var salmissing "Salary data missing"

local summary_vars "age20s age30s age40s age50s age60s age70s female male sal50 sal100 sal150 saltop n_funds"

eststo stream: quietly estpost summarize ///
    `summary_vars' if steady_pre == 0 
eststo nstream: quietly estpost summarize ///
    `summary_vars' if steady_pre == 1 
eststo diff: quietly estpost ttest ///
    `summary_vars', by(steady_pre) unequal

esttab stream nstream diff using "$output\91 - Differences in Streamlined Individual Characteristics (KM Figure 4).rtf", replace ///
	cells("mean(pattern(1 1 0) fmt(2) label(Mean)) b(star pattern(0 0 1) fmt(2) label(Difference))") ///
	modelwidth(20) ///
label                               ///
	title("Differences in Streamlined Individual Characteristics")       ///
	nonumbers mtitles("Streamlined Group" "Non-Streamlined Group" "T-Test")  ///
	addnote("Statistics are for January 2016 portfolios of individuals that appear in both 2016 and 2017." ///
"Individuals with all assets invested in TDFs or in funds that were still available after reforms are included." ///
"Ages are as of November 2016." ///
"Note: *p<0.10, **p<0.05, ***p<0.01") /// 
star(* 0.10 ** 0.05 *** 0.01)

restore 

** Figure 44: Difference in Mean Allocation Post-Pre Reform ** 

preserve

use "$temp/r10_temp", replace

keep if inlist(date,672,684)

merge m:1 Fund using "$temp/fundtypes1"
assert _m != 1
keep if _m == 3
drop _m

collapse (sum) port_weight (mean) plan_defaulted17, by(ScrubbedID fund_type date)

// fill in missing fund types for each person so that we calculate a correct average
gen double id = ScrubbedID + date/1000
tsset id fund_type
tsfill, full
tostring id, force replace
drop ScrubbedID date
gen ScrubbedID = substr(id,1,strpos(id,".")-1)
gen date = substr(id,strpos(id,".")+1,3)
destring ScrubbedID date, replace
order ScrubbedID date
replace port_weight = 0 if missing(port_weight)
gen temp = plan_defaulted17
replace temp = 0 if missing(temp)
drop plan_defaulted17
bys ScrubbedID: egen plan_defaulted17 = max(temp)
drop temp id

sort ScrubbedID fund_type date
by ScrubbedID fund_type: replace port_weight = port_weight - port_weight[_n-1] if _n == 2
rename port_weight delta_port_weight
by ScrubbedID fund_type: keep if _n == 2
assert date == 684
drop date
bys ScrubbedID: gen count = (_n == 1)

gen p_val = .
gen n = _n 

forvalues i = 1/9 {
    
	forvalues j = 0/2 {
		
		di "t-test for fund type `i' and plan defaulted `j'"
		ttest delta_port_weight == 0 if plan_defaulted17 == `j' & fund_type == `i'
		local p_`i'_`j' = r(p)
		di  "p_`i'_`j' is `p_`i'_`j''" 
		replace p_val = `p_`i'_`j'' if plan_defaulted17 == `j' & fund_type == `i'
		
	}
}


collapse (count) count (mean) delta_port_weight p_val, by(fund_type plan_defaulted17)
replace delta_port_weight = round(delta_port_weight, .001)

sort plan_defaulted17 fund_type 

reshape wide count delta_port_weight p_val, i(fund_type) j(plan_defaulted17)

decode fund_type, gen(fund_type_string)
order fund_type_string
la var fund_type_string "Fund Type"
set obs `=_N+1'
gen row = _n
summ row
local maxrow = r(max)
replace fund_type_string = "N" if row == `maxrow'
replace delta_port_weight0 = count0[_n-1] if row == `maxrow'
replace delta_port_weight1 = count1[_n-1] if row == `maxrow'
replace delta_port_weight2 = count2[_n-1] if row == `maxrow'
tostring delta_port_weight*, replace force

forvalues i = 0/2 {
	 replace delta_port_weight`i' = "-0." + substr(delta_port_weight`i',3,3) if substr(delta_port_weight`i',1,1) == "-" & substr(delta_port_weight`i',1,2) != "-0" & row != `maxrow'
	replace delta_port_weight`i' = "0." + substr(delta_port_weight`i',2,3) if substr(delta_port_weight`i',1,1) == "." & row != `maxrow'
	replace delta_port_weight`i' = delta_port_weight`i' + "00" if length(delta_port_weight`i') == 3 & substr(delta_port_weight`i',1,1) != "-"  & row != `maxrow'
	replace delta_port_weight`i' = delta_port_weight`i' + "0" if length(delta_port_weight`i') == 4 & substr(delta_port_weight`i',1,1) != "-"  & row != `maxrow'
	replace delta_port_weight`i' = delta_port_weight`i' + "00" if length(delta_port_weight`i') == 4 & substr(delta_port_weight`i',1,1) == "-"  & row != `maxrow'
	replace delta_port_weight`i' = delta_port_weight`i' + "0" if length(delta_port_weight`i') == 5 & substr(delta_port_weight`i',1,1) == "-"  & row != `maxrow'
	replace delta_port_weight`i' = "0.000" if delta_port_weight`i' == "0" & row != `maxrow'
}

drop count* row
tostring delta_port_weight*, replace force
/*
forvalues i = 1/9 {
	forvalues j = 0/2 {
		replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .1
		replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .05
		replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .01
	}
}
*/
drop fund_type
la var delta_port_weight0 "Streamlined: Active choice"
la var delta_port_weight1 "Streamlined: Passive choice"
la var delta_port_weight2 "Non-streamlined"

gen stars = ""

forvalues i = 0/2 {

	replace stars = "*" if p_val`i' < 0.1  
	replace stars = "**" if p_val`i' < 0.05 
	replace stars = "***" if p_val`i' < 0.01  
	replace stars = "" if delta_port_weight`i' == "0.000"
	
	replace delta_port_weight`i' = delta_port_weight`i' + stars

}

drop stars p_val*

export excel "$output/92 - Difference in Mean Allocation Post-Pre Reform.xlsx", firstrow(varlabels) replace

restore

** Figure 43: Reallocation Pre-Reform Share of Assets ** 

preserve

use "$temp/r10_temp", replace

keep if inlist(date,672)

merge m:1 Fund using "$temp/fundtypes1"
assert _m != 1
keep if _m == 3
drop _m

sort Scr date fund_type

replace fund_type = 5 if Fund == "2080-FID CONTRAFUND K"
replace fund_type = 5 if Fund == "2082-FID DIVERSIFD INTL K"

bro if fund_type == 4 & steady_pre == 1

collapse (sum) port_weight (mean) steady_pre, by(ScrubbedID fund_type)

// fill in missing fund types for each person so that we calculate a correct average
tsset ScrubbedID fund_type
tsfill, full
replace port_weight = 0 if missing(port_weight)
gen temp = steady_pre
replace temp = 0 if missing(temp)
drop steady_pre
bys ScrubbedID: egen steady_pre = max(temp)
bys ScrubbedID: gen count = (_n == 1)
drop temp

collapse (count) count (mean) port_weight, by(fund_type steady_pre)
replace port_weight = round(port_weight, .0001)
reshape wide count port_weight, i(fund_type) j(steady_pre)

decode fund_type, gen(fund_type_string)
drop fund_type
order fund_type_string
la var fund_type_string "Fund Type"
set obs `=_N+1'
gen row = _n
summ row
local maxrow = r(max)
replace fund_type = "N" if row == `maxrow'
replace port_weight0 = count0[_n-1] if row == `maxrow'
replace port_weight1 = count1[_n-1] if row == `maxrow'
drop count* row

la var port_weight0 "Streamlined"
la var port_weight1 "Non-streamlined"

export excel "$output/93 - Reallocation Pre-Reform Share of Assets.xlsx", firstrow(varlabels) replace

restore 

** Figure xx: What percentage of Guardrail errors were eliminated after streamlinig? ** 

** Append 2017-18 Data ** 

use "$temp/collapse2_combined.dta", replace
keep if inlist(date,672,684,991)
sort ScrubbedID date
merge m:1 ScrubbedID using "$temp/plan_defaulted17"
replace plan_defaulted17 = 2 if steady_pre == 1

// make sure dates are in the correct order
assert date[1] == 672
assert date[2] == 684
// assert date[3] == 991

keep if date == 672

append using "$temp/2017_guardrails"

sort Scr date

keep Scr date n_funds total_exp_over total_intl_share_under one_sector_overweight guardrail_div guardrail_not_intl any_guardrail total_eq_violation total_eq_under total_eq_over

sort Scr date

gen post = cond(date == 684, 1, 0)
gen pre = cond(date == 672, 1, 0)

bys Scr: gen m = _n
egen both = max(m), by(Scr)
drop if both == 1

label var n_funds "Number of Funds"
label var total_exp_over "Expense Error: Average Expense Ratio Over 75 Basis Points"
label var total_eq_violation "Exposure Error: Equities Less Than Half or More Than Double TDF"
label var total_intl_share_under "Diversification Error: Intl. Equities Underweight"
label var one_sector_overweight "Diversification Error: Single Sector Fund Overweighted"
label var guardrail_div "Any Diversification Error"
label var guardrail_not_intl "Any Non-International Error"
label var any_guardrail "Any Error"

local summary_vars = "n_funds total_exp_over total_eq_violation total_intl_share_under one_sector_overweight guardrail_div guardrail_not_intl any_guardrail"

eststo nomax: quietly estpost summarize ///
    `summary_vars' if pre == 1
eststo max: quietly estpost summarize ///
    `summary_vars' if pre == 0
eststo diff: quietly estpost ttest ///
    `summary_vars', by(pre) unequal

esttab nomax max diff using "$output\94 - Proportion of Guardrail Violators Before and After Streamlining.rtf", replace ///
	cells("mean(pattern(1 1 0) fmt(2) label(Mean)) b(star pattern(0 0 1) fmt(2) label(Difference))") ///
label                               ///
	title("Proportion of Guardrail Violators Before and After Streamlining")       ///
	nonumbers mtitles("Before Streamlining" "After Streamlining" "T-Test")  ///
	addnote("Note: *p<0.10, **p<0.05, ***p<0.01") /// 
	nogap onecell ///
star(* 0.10 ** 0.05 *** 0.01)

save "$temp/tab94", replace

// compute a delta violation (of those who violate, how many became non-violators)	

use "$temp/tab94", replace

gen pre_flag = cond(guardrail_not_intl == 1 & date == 672, 1, 0)
egen violator_pre = max(pre_flag), by(Scr)

gen post_flag = cond(guardrail_not_intl == 1 & date == 684, 1, 0)
egen violator_post = max(post_flag), by(Scr)

drop if violator_pre == 0

rename total_eq_violation exposure
rename total_exp_over expense 
rename one_sector_overweight diversification
rename guardrail_not_intl any 

local outcomes "expense diversification exposure any total_intl_share_under total_eq_over total_eq_under"

foreach var of varlist `outcomes'{
    
	// No of violators 
	egen n`var' = count(`var') if date == 672 & `var' == 1
	egen helper`var' = count(n`var')
    replace n`var' = helper`var'  
	drop helper`var'
		
	gen pre`var' = cond(`var' == 1 & date == 672, 1, 0)
	egen `var'pre = max(pre`var'), by(Scr)
	
	gen post`var' = cond(`var' == 1 & date == 684, 1, 0)
	egen `var'post = max(post`var'), by(Scr)
	
	// No of ppl who get "fixed" (1 -> 0)	
	gen fixed_`var' = cond(`var'pre == 1 & `var'post == 0, 1, 0)
	egen sum_f`var' = sum(fixed_`var') 
	replace sum_f`var' = sum_f`var' / 2 
	
	// No of ppl who get hurt (0 -> 1)	
	gen problem_`var' = cond(`var'pre == 0 & `var'post == 1, 1, 0)
	egen prob_f`var' = sum(problem_`var') 
	replace prob_f`var' = prob_f`var' / 2
	
	// Prop. that get fixed 
	gen prop`var' = sum_f`var' / n`var'
	
}

// Putexcel set-up

putexcel set "$output/96 - Effect of Streamlining on Violations.xlsx", sheet("Sheet1") replace 
//putexcel D1 = "Proportion of Guardrail Violators Before and After Streamlining"
putexcel A1 = "Guardrail Violation"
putexcel B1 = "Number of Violators"
putexcel C1 = "Proportion of Violators that stopped making error after Streamlining"
putexcel D1 = "Difference in Proportion of Violators after Streamlining"
putexcel E1 = "Number of New Violators"

putexcel A2 = "Expense Error"
putexcel A3 = "Diversification Error"
putexcel A4 = "Exposure Error"
putexcel A5 = "Any Non-International Error"

// Add Number of Violators to Excel

local outcomes "expense diversification exposure any"

forvalues i = 1/4 {
    
	local var : word `i' of `outcomes'	

	local i = `i' + 1
	
	// n 
	putexcel B`i' = n`var' 
	
	// prop
	sum prop`var'
	local prop`var' = round(r(mean), .01)
	putexcel C`i' = `prop`var''
	
	// diff
	ttest `var', by(post)
	local diff_`var' = r(mu_2) - r(mu_1)
	local d`var' = round(`diff_`var'', .001)
	local pval_`var' = r(p)
	
	if (`pval_`var'' < 0.1) {
		local stars = "*"
	}
	if (`pval_`var'' < 0.05) {
		local stars = "**"
	}
	if (`pval_`var'' < 0.01) {
		local stars = "***"
	}
	
	putexcel D`i' = "`d`var''`stars'"
	
	// problem
	putexcel E`i' = prob_f`var'

}

putexcel close 

/*

local summary_vars = "n_funds total_exp_over total_eq_violation total_intl_share_under one_sector_overweight guardrail_div guardrail_not_intl any_guardrail"

eststo nomax: quietly estpost summarize ///
    `summary_vars' if pre == 1
eststo max: quietly estpost summarize ///
    `summary_vars' if pre == 0
eststo diff: quietly estpost ttest ///
    `summary_vars', by(pre) unequal

esttab nomax max diff using "$output\94.1 - Delta of Guardrail Violators Before and After Streamlining.rtf", replace ///
	cells("mean(pattern(1 1 0) fmt(2) label(Mean)) b(star pattern(0 0 1) fmt(2) label(Difference))") ///
label                               ///
	title("Change in Guardrail Violations Before and After Streamlining")       ///
	nonumbers mtitles("Before Streamlining" "After Streamlining" "T-Test")  ///
	addnote("Note: *p<0.10, **p<0.05, ***p<0.01") /// 
	nogap onecell ///
star(* 0.10 ** 0.05 *** 0.01)

*/


**** Reallocation Regressions *****

use "$temp/collapse2_combined.dta", replace
keep if inlist(date,672,684,991)
sort ScrubbedID date
merge m:1 ScrubbedID using "$temp/plan_defaulted17"
replace plan_defaulted17 = 2 if steady_pre == 1
drop _m

// make sure dates are in the correct order
assert date[1] == 672
assert date[2] == 684
assert date[3] == 991


preserve 

use "$temp/2017_guardrails", replace
foreach var of varlist guardrail_not_intl total_eq_under total_eq_over total_eq_violation {
    
	rename `var' `var'_17
	
}

keep Scr date guardrail_not_intl_17 total_eq_under_17 total_eq_over_17 total_eq_violation_17
save "$temp/2017_guardrails2", replace 

restore 

merge 1:m Scr date using "$temp/2017_guardrails2"

drop if _m == 2

foreach var of varlist guardrail_not_intl_17 total_eq_under_17 total_eq_over_17 total_eq_violation_17 {
    
	egen helper = max(`var'), by(Scr)
	replace `var' = helper 
	drop helper 
	
}

replace guardrail_not_intl = guardrail_not_intl_17 if date == 684
replace total_eq_violation = total_eq_violation_17 if date == 684
replace total_eq_violation = 0 if date == 684

//replace guardrail_not_intl = 0 if date != 684 | date != 672

drop _m	
rename guardrail_not_intl error 
label var error "Guardrailed"

rename total_eq_violation exposure_error 
label var exposure_error "Exposure Error"

sort Scr date

assert date[1] == 672
assert date[2] == 684
assert date[3] == 991

local vars = "equities dominated_simple exp_ratio n_funds _rmse exposure_error error"

foreach var in `vars' {
	di "`var'"
	gen `var'_prepost = `var'[_n+1] - `var' if date == 672 & ScrubbedID == ScrubbedID[_n+1] 
	gen `var'_preguardrails = `var'[_n+2] - `var' if date == 672 & ScrubbedID == ScrubbedID[_n+2]
	//drop `var'
}
keep if date == 672

drop exposure_error_preguardrails error_preguardrails

// generate and label variables for regression	
la var equities_prepost "Delta % Equities (Streamlining)"
la var equities_preguardrails "Delta % Equities (Guardrailing)"
la var dominated_simple_prepost "Delta % Dominated Funds (Streamlining)"
la var dominated_simple_preguardrails "Delta % Dominated Funds (Guardrailing)"
la var exp_ratio_prepost "Delta Expense Ratio (Streamlining)"
la var exp_ratio_preguardrails "Delta Expense Ratio (Guardrailing)"
la var n_funds_prepost "Delta No. Funds (Streamlining)"
la var n_funds_preguardrails "Delta No. Funds (Guardrailing)"
la var _rmse_prepost "Delta Idiosyncratic Risk (Streamlining)"
la var _rmse_preguardrails "Delta Idiosyncratic Risk (Guardrailing)"
la var error_prepost "Delta Non-Intl. Error (Streamlining)"
la var exposure_error_prepost "Delta Exposure Error (Streamlining)"

gen sal50 = (RoundedSalary > 0 & RoundedSalary <= 50000)
gen sal100 = (RoundedSalary > 50000 & RoundedSalary <= 100000)
gen sal150 = (RoundedSalary > 100000 & RoundedSalary <= 200000)
gen saltop = (RoundedSalary > 150000 & RoundedSalary < .)
gen salmissing = (RoundedSalary == 0 | missing(RoundedSalary))

la var sal50 "Salary 50,000 or under"
la var sal100 "Salary 50,000-100,000"
la var sal150 "Salary 100,000-150,000"
la var saltop "Salary over 150,000"
la var salmissing "Salary data missing"

gen female = (Gender == "F")
gen male = (Gender == "M")
gen unknown_gender = (male == 0 & female == 0)

gen age2016 = age2018 - 2
la var age2016 "Age as of 2016"
gen age20s = (age2016 < 30)
gen age30s = (age2016 >= 30 & age2016 < 40)
gen age40s = (age2016 >= 40 & age2016 < 50)
gen age50s = (age2016 >= 50 & age2016 < 60)
gen age60s = (age2016 >= 60 & age2016 < 70)
gen age70s = (age2016 >= 70 & age2016 < .)

la var age20s "Age under 30" 
la var age30s "Age 30-39" 
la var age40s "Age 40-49" 
la var age50s "Age 50-59" 
la var age60s "Age 60-69" 
la var age70s "Age 70+" 

la var female "Female"
la var male "Male"
la var unknown_gender "Gender unknown"
	
gen age_2 = age2016^2
la var age_2 "Age-squared"

gen total_assets_100 = total_assets/100000
la var total_assets_100 "Total assets (100,000 USD)"

la define plan_defaulted17 0 "Streamlined: Active Choice" ///
1 "Streamlined: Passive Choice"	///
2 "Non-streamlined"
la val plan_defaulted17 plan_defaulted17

gen streamlined_pd = (plan_defaulted17 == 1)
la var streamlined_pd "Streamlined: Active Choice"	
gen streamlined_npd = (plan_defaulted17 == 0)
la var streamlined_npd "Streamlined: Passive Choice"	

rename dominated_simple_preguardrails dom_simple_preguard

** Age Effect 
 
reg _rmse_prepost streamlined_pd streamlined_npd age2016 age_2 male unknown_gender total_assets_100 sal50 sal100 sal150 saltop salmissing, robust
gen age_coeff = _b[age2016]
gen age2_coeff = _b[age_2]
/*
reg _rmse_preguardrails error age2016 age_2 male unknown_gender total_assets_100 sal50 sal100 sal150 saltop salmissing, robust
gen age_coeff2 = _b[age2016]
gen age2_coeff2 = _b[age_2]
*/
duplicates drop age2016, force 

foreach age of numlist 21(1)96 {
	
	gen stream__`age' = age_coeff * `age' + age_coeff * `age' * `age'
	gen guard__`age' = age_coeff2 * `age' + age2_coeff2 * `age' * `age'
	
}

keep age2016 stream__* guard__*


gen stream = . 
gen guard = . 

foreach age of numlist 21(1)89 {
	
	replace stream = stream__`age' if age2016 == `age' 
	replace guard = guard__`age' if age2016 == `age' 
		
}

drop stream__* guard__*

sort age

order age stream guard

drop if age > 90

reshape 

restore 

reg _rmse_prepost streamlined_pd streamlined_npd age2016 age_2 male unknown_gender total_assets_100 sal50 sal100 sal150 saltop salmissing, robust
return list
gen age_coeff = _b[age2016]
gen age2_coeff = _b[age_2]

gen age_50 = age_coeff * 50 + age2_coeff * 50
gen age_25 = age_coeff * 25 + age2_coeff * 25
gen age_75 = age_coeff * 75 + age2_coeff * 75
gen diff1 = age_75 - age_25

drop age_coeff age2_coeff age_25 age_75 diff1 

reg _rmse_preguardrails error age2016 age_2 male unknown_gender total_assets_100 sal50 sal100 sal150 saltop salmissing, robust
return list
gen age_coeff2 = _b[age2016]
gen age2_coeff2 = _b[age_2]

gen age_502 = age_coeff2 * 50 + age2_coeff2 * 50
gen age_252 = age_coeff * 25 + age2_coeff * 25
gen age_752 = age_coeff * 75 + age2_coeff * 75
gen diff2 = age_75 - age_25
tab diff2 



// regression output
outreg2 using "$temp/95 - Reallocation Regressions.xls", replace skip
local vars = "_rmse_prepost _rmse_preguardrails n_funds_prepost exp_ratio_prepost exp_ratio_preguardrails dominated_simple_prepost dom_simple_preguard exposure_error_prepost error_prepost"
local n_vars : word count `vars'
local controls streamlined_pd streamlined_npd age2016 age_2 male unknown_gender total_assets_100 sal50 sal100 sal150 saltop salmissing
local controls2 error age2016 age_2 male unknown_gender total_assets_100 sal50 sal100 sal150 saltop salmissing

forvalues i = 1/`n_vars' {
    di `i'
	if (`i' == 1 | `i' == 3 | `i' == 4 | `i' == 6 | `i' == 8 | `i' == 9) {
		local var : word `i' of `vars'
		local lab: variable label `var'
		di "`var'"	
		regress `var' `controls', robust 

		outreg2 using "$temp/95 - Reallocation Regressions.xls", append ctitle(`lab') label stats(coef se) drop(_rmse_prepost _rmse_preguardrails n_funds_prepost exp_ratio_prepost exp_ratio_preguardrails dominated_simple_prepost dom_simple_preguard exposure_error_prepost error_prepost) sortvar(streamlined_pd streamlined_npd)

		test streamlined_pd == streamlined_npd 
		local `var'_p = round(r(p),.001)
		local `var'_mean = round(_b[streamlined_pd] - _b[streamlined_npd],.00001)
	
	}

	if (`i' == 2 | `i' == 5 | `i' == 7) {	
	local var : word `i' of `vars'
	local lab: variable label `var'
	regress `var' `controls2', robust 
	outreg2 using "$temp/95 - Reallocation Regressions.xls", append ctitle(`lab') label stats(coef se) drop(_rmse_prepost _rmse_preguardrails n_funds_prepost exp_ratio_prepost exp_ratio_preguardrails dominated_simple_prepost dom_simple_preguard exposure_error_prepost error_prepost) sortvar(error)
	}
	
}

//exposure_error_preguardrails error_prepost

/// must resave as .xlsx
preserve 
	import delimited "$temp\95 - Reallocation Regressions.txt", clear
	drop v1 
	//replace v2 = "" if _n == 2
	//drop if _n == 4 | _n == 5
	replace v2 = "N" if _n == 33
	replace v2 = "R-Squared" if _n == 34
	export excel "$output\95 - Reallocation Regressions.xlsx", replace
restore

// add in variable means
putexcel set "$output/95 - Reallocation Regressions.xlsx", modify sheet("Sheet1")
putexcel B2 = "Mean"
putexcel C1 = "(1)"
putexcel D1 = "(2)"
putexcel E1 = "(3)"
putexcel F1 = "(4)"
putexcel G1 = "(5)"
putexcel H1 = "(6)"
putexcel I1 = "(7)"
putexcel J1 = "(8)"
putexcel K1 = "(9)"

local controls "streamlined_pd streamlined_npd error age2016 age_2 male unknown_gender total_assets_100 sal50 sal100 sal150 saltop salmissing"
local n_controls : word count `controls'
di `n_controls'
forvalues i = 1/`n_controls' {
	di `i'
	local var : word `i' of `controls'	
	di "`var'"
	local row = `i' * 2 + 2
	di `row'
	summ `var'
	local mean = r(mean)
	putexcel B`row' = `mean'
}

putexcel A35 = "Diff(β(Streamlined, plan-defaulted) – β(Streamlined, non-plan-defaulted))"
putexcel A36 = "Mean of dep var"
local letters "C D E F G H I J K"
local vars "_rmse_prepost _rmse_preguardrails n_funds_prepost exp_ratio_prepost exp_ratio_preguardrails dominated_simple_prepost dom_simple_preguard exposure_error_prepost error_prepost"
forvalues i = 1/`n_vars' {
    
  	local var : word `i' of `vars'
	local letter : word `i' of `letters'
	local stars = ""
	di `i'
	
	if (`i' == 1 | `i' == 3 | `i' == 4 | `i' == 6 | `i' == 8 | `i' == 9) {

	di ``var'_p'
	
	if (``var'_p' < 0.1) {
		local stars = "*"
	}
	if (``var'_p' < 0.05) {
		local stars = "**"
	}
	if (``var'_p' < 0.01) {
		local stars = "***"
	}
	putexcel `letter'35 = "``var'_mean'`stars'"
	summ `var'
	local dep_mean = round(r(mean), .001)
	putexcel `letter'36 = "`dep_mean'"
	}

	if (`i' == 2 | `i' == 5 | `i' == 7) {	

	summ `var'
	local dep_mean = round(r(mean), .001)
	putexcel `letter'36 = "`dep_mean'"
}


}

putexcel close





/*

// regression output
outreg2 using "$temp/95 - Reallocation Regressions.xls", replace skip
local vars = "_rmse_prepost _rmse_preguardrails n_funds_prepost n_funds_preguardrails exp_ratio_prepost exp_ratio_preguardrails dominated_simple_prepost dom_simple_preguard error_prepost error_preguardrails"
local n_vars : word count `vars'
local controls streamlined_pd streamlined_npd age2016 age_2 female unknown_gender total_assets_100 sal50 sal100 sal150 saltop salmissing
local controls2 error age2016 age_2 female unknown_gender total_assets_100 sal50 sal100 sal150 saltop salmissing

forvalues i = 1/`n_vars' {
    di `i'
	local var : word `i' of `vars'
	local lab: variable label `var'
	di "`var'"	
	regress `var' `controls', robust 
	regress `var' `controls2', robust 
	outreg2 using "$temp/95 - Reallocation Regressions.xls", append ctitle(`lab') label stats(coef pval) drop(equities_prepost equities_preguardrails dominated_simple_prepost dominated_simple_preguardrails exp_ratio_prepost exp_ratio_preguardrails n_funds_prepost n_funds_preguardrails _rmse_prepost _rmse_preguardrails error_prepost error_preguardrails)

	test streamlined_pd == streamlined_npd 
	local `var'_p = round(r(p),.001)
	local `var'_mean = round(_b[streamlined_pd] - _b[streamlined_npd],.00001)

}

/// must resave as .xlsx
preserve 
	import delimited "$temp\95 - Reallocation Regressions.txt", clear
	drop v1 
	replace v2 = "" if _n == 2
	drop if _n == 4 | _n == 5
	replace v2 = "N" if _n == 31
	replace v2 = "R-Squared" if _n == 32
	export excel "$output\95 - Reallocation Regressions.xlsx", replace
restore

// add in variable means
putexcel set "$output/95 - Reallocation Regressions.xlsx", modify sheet("Sheet1")
putexcel B1 = "Mean"
putexcel C1 = "(1)"
putexcel D1 = "(2)"
putexcel E1 = "(3)"
putexcel F1 = "(4)"
putexcel G1 = "(5)"
putexcel H1 = "(6)"
putexcel I1 = "(7)"
putexcel J1 = "(8)"

local controls "streamlined_pd streamlined_npd age2016 age_2 female unknown_gender total_assets_100 sal50 sal100 sal150 saltop salmissing"
local n_controls : word count `controls'
di `n_controls'
forvalues i = 1/`n_controls' {
	di `i'
	local var : word `i' of `controls'	
	di "`var'"
	local row = `i' * 2 + 2
	di `row'
	summ `var'
	local mean = r(mean)
	putexcel B`row' = `mean'
}

putexcel A35 = "Diff(β(Streamlined, plan-defaulted) – β(Streamlined, non-plan-defaulted))"
putexcel A36 = "Mean of dep var"
local letters "C D E F G H I J K L"
local vars = "_rmse_prepost _rmse_preguardrails n_funds_prepost n_funds_preguardrails exp_ratio_prepost exp_ratio_preguardrails dominated_simple_prepost dom_simple_preguard error_prepost error_preguardrails"
local n_vars : word count `vars'
forvalues i = 1/`n_vars' {
	local var : word `i' of `vars'
	local letter : word `i' of `letters'
	local stars = ""
	di ``var'_p'
	if (``var'_p' < .1) {
		local stars = "*"
	}
	if (``var'_p' < .05) {
		local stars = "**"
	}
	if (``var'_p' < .01) {
		local stars = "***"
	}
	putexcel `letter'35 = "``var'_mean'`stars'"
	summ `var'
	local dep_mean = round(r(mean), .001)
	putexcel `letter'36 = "`dep_mean'"
}

putexcel close

// 

preserve 

use "$temp/guard_intrm_onlytdf_joint_nonintl", replace
keep if date == 672

gen any_guardrail = (total_eq_violation == 1 | total_exp_over == 1 | total_intl_share_under == 1 | one_sector_overweight == 1)
gen guardrail_not_intl = (total_eq_violation == 1 | total_exp_over == 1 | one_sector_overweight == 1)
gen guardrail_div = (total_intl_share_under == 1 | one_sector_overweight == 1)
local basis = round($exp_ratio_cap * 10000)

gen helper = 1 
egen n_funds = sum(helper), by(Scr)
drop helper 

collapse (firstnm) n_funds date total_exp_over total_intl_share_under one_sector_overweight guardrail_div guardrail_not_intl any_guardrail total_eq_violation total_eq_under total_eq_over, by(Scr)

replace date = 684 // just to keep the code working

save "$temp/non_intl_2016", replace

restore 

append using "$temp/non_intl_2016.dta"

// try 

// bring in 2017 violators 

preserve 

use "$temp/guard_intrm_onlytdf_joint_nonintl", replace
keep if date == 672

gen any_guardrail = (total_eq_violation == 1 | total_exp_over == 1 | total_intl_share_under == 1 | one_sector_overweight == 1)
gen guardrail_not_intl = (total_eq_violation == 1 | total_exp_over == 1 | one_sector_overweight == 1)
gen guardrail_div = (total_intl_share_under == 1 | one_sector_overweight == 1)
local basis = round($exp_ratio_cap * 10000)

gen helper = 1 
egen n_funds = sum(helper), by(Scr)
drop helper  

foreach var of varlist guardrail_not_intl total_eq_under total_eq_over total_eq_violation {
    
	rename `var' `var'_17
	
}

collapse (firstnm) n_funds date total_exp_over total_intl_share_under one_sector_overweight guardrail_div guardrail_not_intl any_guardrail total_eq_violation total_eq_under total_eq_over, by(Scr)

save "$temp/2017_guardrails2", replace 

restore 
