************ Keim and Mitchellfor Guardrails ***********

** Individual Characteristics Table 

use "$temp/collapse2.dta", clear

keep ScrubbedID steady_pre steady_pre_sc smart guardrail_not_intl
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

// clean variables
la define steady_pre 0 "Streamlined group" ///
1 "Non-streamlined group"
la val steady_pre steady_pre

// merge in total assets
merge m:1 ScrubbedID date using "$temp/asset_list"
assert _m != 1
keep if _m == 3
drop _m
gen FundsHeld = round(total_assets * port_weight, .01)

save "$temp/quick", replace

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
    `summary_vars' if guardrail_not_intl == 0 
eststo nstream: quietly estpost summarize ///
    `summary_vars' if guardrail_not_intl == 1 
eststo diff: quietly estpost ttest ///
    `summary_vars', by(guardrail_not_intl) unequal

esttab stream nstream diff using "$output\91.5 - Differences in Guardrailed Individual Characteristics (KM Figure 4).rtf", replace ///
	cells("mean(pattern(1 1 0) fmt(2) label(Mean)) b(star pattern(0 0 1) fmt(2) label(Difference))") ///
	modelwidth(20) ///
label                               ///
	title("Differences in Guardrailed Individual Characteristics")       ///
	nonumbers mtitles("Guardrailed Group" "Non-Guardrailed Group" "T-Test")  ///
	addnote("Statistics are for January 2016 portfolios of individuals that appear in both 2016 and 2017." ///
"Ages are as of November 2016." ///
"Note: *p<0.10, **p<0.05, ***p<0.01") /// 
star(* 0.10 ** 0.05 *** 0.01)


** Pre-Reform Assets

preserve 

use "$temp/quick.dta", clear
keep if date == 672
sort Scr date

merge m:1 Fund using "$temp/fundtypes1"
assert _m != 1
keep if _m == 3
drop _m

sort Scr date fund_type

replace fund_type = 5 if Fund == "2080-FID CONTRAFUND K"
replace fund_type = 5 if Fund == "2082-FID DIVERSIFD INTL K"

collapse (sum) port_weight (mean) guardrail_not_intl, by(ScrubbedID fund_type)

// fill in missing fund types for each person so that we calculate a correct average
tsset ScrubbedID fund_type
tsfill, full
replace port_weight = 0 if missing(port_weight)
gen temp = guardrail_not_intl
replace temp = 0 if missing(temp)
drop guardrail_not_intl
bys ScrubbedID: egen guardrail_not_intl = max(temp)
bys ScrubbedID: gen count = (_n == 1)
drop temp

collapse (count) count (mean) port_weight, by(guardrail_not_intl fund_type)

replace port_weight = round(port_weight, .0001)
reshape wide count port_weight, i(fund_type) j(guardrail_not_intl)

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

la var port_weight0 "Non-Guardrailed"
la var port_weight1 "Guardrailed"

export excel "$output/93.5 - Reallocation Pre-Reform Share of Assets.xlsx", firstrow(varlabels) replace

restore 

** Delta Pre-Post Guardrailing 

use "$temp/collapse2.dta", clear

keep ScrubbedID steady_pre steady_pre_sc smart guardrail_not_intl
bys ScrubbedID: keep if _n == 1
tempfile steady_pre_list 
save "`steady_pre_list'"

use "$temp/guard_intrm_onlytdf_joint_nonintl.dta", clear

/*
egen max = max(one_sector_over), by(Scr)
egen max2 = max(date), by(Scr)
egen max1 = min(date), by(Scr)

drop if max2 == 672
drop if max1 == 684
drop if one_sector_over == 0
sort Scr date
*/

keep if date == 672 
replace date = 684
preserve 
use "$temp/full_data.dta", clear
keep if date == 672
save "$temp/r12test", replace
restore 
append using "$temp/r12test"
merge m:1 ScrubbedID using "`steady_pre_list'"
// assert _m != 2
// filter to observations in final data (including the smart/steady investors)
keep if _m == 3
drop _m

merge m:1 Fund using "$temp/funds_2016_2017"
gen steady_fund = (_m == 3)
drop _m

// filter to pre- and post-reform
keep if inlist(date, 672, 684)

// merge in total assets
merge m:1 ScrubbedID date using "$temp/asset_list"
assert _m != 1
keep if _m == 3
drop _m
gen FundsHeld = round(total_assets * port_weight, .01)

keep if inlist(date,672,684)

merge m:1 Fund using "$temp/fundtypes1"
assert _m != 1
keep if _m == 3
drop _m

replace fund_type = 5 if Fund == "2080-FID CONTRAFUND K"
replace fund_type = 5 if Fund == "2082-FID DIVERSIFD INTL K"

sort Scr date

/*
keep if date == 684
duplicates drop Scr, force
tab guardrail_not_intl
*/

collapse (sum) port_weight (mean) guardrail_not_intl, by(ScrubbedID fund_type date)

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

/*
egen test1 = max(guardrail_not_intl), by(Scr)
egen test = sum(test1) if date == 672 & fund_type == 1 /// 739 so we are good so far.
*/
egen test1 = max(guardrail_not_intl), by(Scr)
replace guardrail_not_intl = test1 
drop test1 

//egen test = sum(guardrail_not_intl) if date == 672 & fund_type == 1 /// 739 we are good 

sort ScrubbedID fund_type date
by ScrubbedID fund_type: replace port_weight = port_weight - port_weight[_n-1] if _n == 2
rename port_weight delta_port_weight
by ScrubbedID fund_type: keep if _n == 2
assert date == 684
drop date
bys ScrubbedID: gen count = (_n == 1)

//egen test = sum(guardrail_not_intl)

gen p_val = .
gen n = _n 

// drop if guardrail == 0 {look at 53, 78, 105}

forvalues i = 1/9 {
    
	forvalues j = 0/1 {
		
		di "t-test for fund type `i' and guardrail_not_intl `j'"
		ttest delta_port_weight == 0 if guardrail_not_intl == `j' & fund_type == `i'
		local p_`i'_`j' = r(p)
		di  "p_`i'_`j' is `p_`i'_`j''" 
		replace p_val = `p_`i'_`j'' if guardrail_not_intl == `j' & fund_type == `i'
		
	}
}


collapse (count) count (mean) delta_port_weight p_val, by(fund_type guardrail_not_intl)
replace delta_port_weight = round(delta_port_weight, .001)

sort guardrail_not_intl fund_type 

reshape wide count delta_port_weight p_val, i(fund_type) j(guardrail_not_intl)

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
tostring delta_port_weight*, replace force

forvalues i = 0/1 {
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

forvalues i = 1/9 {
	forvalues j = 0/1 {
		replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .1
		replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .05
		replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .01
	}
}

drop fund_type
la var delta_port_weight0 "Non-Guardrailed"
la var delta_port_weight1 "Guardailed Delta"

/*
gen stars = ""

forvalues i = 0/1 {

	replace stars = "*" if p_val`i' < 0.1  
	replace stars = "**" if p_val`i' < 0.05 
	replace stars = "***" if p_val`i' < 0.01  
	replace stars = "" if delta_port_weight`i' == "0.000"
	
	replace delta_port_weight`i' = delta_port_weight`i' + stars

}

*/

drop p_val*

drop delta_port_weight0

export excel "$output/92.5 - Difference in Mean Allocation Post-Pre Guardrailing.xlsx", firstrow(varlabels) replace