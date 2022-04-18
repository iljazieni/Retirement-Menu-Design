/*
Guardrails CRRA Analysis
ZRS 
10/01/2019

Goal:
-- 

Notes:
--

Updates:
-- 
	
*/





{ // crra utility analysis with no bins
use "$temp/collapse2_combined.dta", clear

// filter to guardrail date investors affected by the guardrails
keep if date == 672 ///
| date == 990 & any_guardrail == 1 ///
| date == 991 & guardrail_not_intl == 1 ///
| date == 992 & total_intl_share_under == 1 ///
| date == 993 & total_eq_over == 1 ///
| date == 994 & total_eq_under == 1 ///
| date == 995 & one_sector_overweight == 1 ///
| date == 996 & total_exp_over == 1 

// generate variance bins based off of 2016 portfolios
xtile var_bin1 = var_used if date == 672 & guardrail_not_intl == 1, nq(20)
bys ScrubbedID: egen var_bin16_joint_nonintl = max(var_bin1)
drop var_bin1

// generate return bins based off of 2016 portfolios
xtile ret_bin1 = return_used if date == 672 & guardrail_not_intl == 1, nq(20)
bys ScrubbedID: egen ret_bin16_joint_nonintl = max(ret_bin1)
drop ret_bin1

// identify individual portfolios by date, return, and variance
egen port_num = group(date return_used var_used var_bin16_joint_nonintl)
gen sd_used = sqrt(var_used)
keep port_num return_used sd_used date any_guardrail guardrail_not_intl one_sector_overweight total_exp_over total_eq_under total_eq_over total_intl_share_under var_bin16_joint_nonintl ret_bin16_joint_nonintl
bys port_num: gen port_count = _N
bys port_num: keep if _n == 1


// set seed (original seed from a random number generator, setting seed for consistency in replications)
set seed 66590

// use 500 draws based on sd and mean of each portfolio to simulate the disutility of variance for each portfolio (doing this expanding for portfolio weight since random draws of protfolios would apply to all participants)
expand 500
sort port_num 
gen mc_return = rnormal(return_used,sd_used)
// cap return at -99% (using this to prevent data from including missings after calculation)
replace mc_return = -.99 if mc_return <= -.99

count if date == 990 & mc_return == -.99
local ninetynine_990 = r(N) 
count if date == 991 & mc_return == -.99
local ninetynine_991 = r(N) 
count if date == 992 & mc_return == -.99
local ninetynine_992 = r(N) 
count if date == 993 & mc_return == -.99
local ninetynine_993 = r(N) 
count if date == 994 & mc_return == -.99
local ninetynine_994 = r(N) 
count if date == 995 & mc_return == -.99
local ninetynine_995 = r(N) 
count if date == 996 & mc_return == -.99
local ninetynine_996 = r(N) 

count if date == 990 
local count_990 = r(N) 
count if date == 991 
local count_991 = r(N) 
count if date == 992 
local count_992 = r(N) 
count if date == 993 
local count_993 = r(N) 
count if date == 994 
local count_994 = r(N) 
count if date == 995 
local count_995 = r(N) 
count if date == 996 
local count_996 = r(N) 

putexcel set "$output/65 - CRRA returns capped", modify
putexcel A4 = ("Joint Guardrails to TDF, All")
putexcel A5 = ("Joint Guardrails to TDF, No Intl")
putexcel A6 = ("International Share of Equities Guardrail to TDF")
putexcel A7 = ("Maximum Equities Guardrail to TDF")
putexcel A8 = ("Minimum Equities Guardrail to TDF")
putexcel A9 = ("Sector Fund Guardrail to TDF")
putexcel A10 = ("Expense Ratio Guardrail to TDF")
putexcel B4 = (`ninetynine_990')
putexcel B5 = (`ninetynine_991')
putexcel B6 = (`ninetynine_992')
putexcel B7 = (`ninetynine_993')
putexcel B8 = (`ninetynine_994')
putexcel B9 = (`ninetynine_995')
putexcel B10 = (`ninetynine_996')
putexcel C4 = (`count_990')
putexcel C5 = (`count_991')
putexcel C6 = (`count_992')
putexcel C7 = (`count_993')
putexcel C8 = (`count_994')
putexcel C9 = (`count_995')
putexcel C10 = (`count_996')
putexcel close


// modify returns to be relative to a $100 initial investment
replace mc_return = 100*(1+mc_return)
drop return_used port_num sd_used
expand port_count

save "$temp/pre_utility", replace

forvalue i = 990/996 {

	{ // calculations for guardrails post
	use "$temp/pre_utility.dta", clear
	
	keep if date == `i'
		
	// expand for different values of CRRA (2, 4, 6)
	gen temp_id = _n
	expand 3
	bys temp_id: gen crra_coefficient = (_n * 2)
	
	// calculate utility for different values of crra
	set type double
	gen utility = 0	
	set type double
	replace utility = ln(mc_return) if crra_coefficient == 1
	replace utility = ((mc_return)^(1-crra_coefficient))/(1-crra_coefficient) if crra_coefficient != 1 & crra_coefficient >= 0

	
	// determine expected mean
	keep utility crra_coefficient port_count
	collapse (mean) utility, by(crra_coefficient)
	di "DONE COLLAPSING FOR `i'"	
	
	gen ce_temp1 = (1-crra_coefficient)*utility if crra_coefficient != 1
	gen ce_temp2 = ln(ce_temp1) if crra_coefficient != 1
	gen ce_temp3 = ce_temp2/(1 - crra_coefficient) if crra_coefficient != 1
	gen ce = exp(ce_temp3) if crra_coefficient != 1
	replace ce = exp(utility) if crra_coefficient == 1
	replace ce = 0 if missing(ce)
	
	keep crra_coefficient ce
	gen merge_coef = round(crra_coefficient * 100)

	rename ce ce_`i'
	save "$temp/ce_`i'", replace
	}
	
	{ // calculations for guardrails pre
	use "$temp/pre_utility.dta", clear
	
	keep if date == 672
	if `i' == 990 {
		keep if any_guardrail == 1
	} 
	else if `i' == 991 {
		keep if guardrail_not_intl == 1
	} 
	else if `i' == 992 {
		keep if total_intl_share_under == 1
	} 
	else if `i' == 993 {
		keep if total_eq_over == 1
	}
	else if `i' == 994 {
		keep if total_eq_under == 1
	} 
	else if `i' == 995 {
		keep if one_sector_overweight == 1
	} 
	else if `i' == 996 {
		keep if total_exp_over == 1
	} 

	
	
	// expand for different values of CRRA (2, 4, 6)
	gen temp_id = _n
	expand 3
	bys temp_id: gen crra_coefficient = (_n * 2)
	
	// calculate utility for different values of crra
	set type double
	gen utility = 0	
	set type double
	replace utility = ln(mc_return) if crra_coefficient == 1
	replace utility = ((mc_return)^(1-crra_coefficient))/(1-crra_coefficient) if crra_coefficient != 1 & crra_coefficient >= 0

	
	// determine expected mean
	keep utility crra_coefficient port_count
	collapse (mean) utility, by(crra_coefficient)
	di "DONE COLLAPSING FOR `i' - Initial"	
	
	gen ce_temp1 = (1-crra_coefficient)*utility if crra_coefficient != 1
	gen ce_temp2 = ln(ce_temp1) if crra_coefficient != 1
	gen ce_temp3 = ce_temp2/(1 - crra_coefficient) if crra_coefficient != 1
	gen ce = exp(ce_temp3) if crra_coefficient != 1
	replace ce = exp(utility) if crra_coefficient == 1
	replace ce = -1 if missing(ce)
	
	keep crra_coefficient ce
	gen merge_coef = round(crra_coefficient * 100)

	rename ce ce_`i'_initial
	save "$temp/ce_`i'_initial", replace
	}
}





}

{ // crra utility analysis with variance bins -- only for non-international joint guardrail (991)

forvalue i = 991/991 {

	{ // calculations for guardrails post
	use "$temp/pre_utility.dta", clear
	
	keep if date == `i'
		
	// expand for different values of CRRA (2, 4, 6)
	gen temp_id = _n
	expand 3
	bys temp_id: gen crra_coefficient = (_n * 2)
	
	// calculate utility for different values of crra
	set type double
	gen utility = 0	
	set type double
	replace utility = ln(mc_return) if crra_coefficient == 1
	replace utility = ((mc_return)^(1-crra_coefficient))/(1-crra_coefficient) if crra_coefficient != 1 & crra_coefficient >= 0

	
	// determine expected mean
	keep utility crra_coefficient port_count var_bin16_joint_nonintl
	collapse (mean) utility, by(crra_coefficient var_bin16_joint_nonintl)
	di "DONE COLLAPSING FOR `i'"	
	
	gen ce_temp1 = (1-crra_coefficient)*utility if crra_coefficient != 1
	gen ce_temp2 = ln(ce_temp1) if crra_coefficient != 1
	gen ce_temp3 = ce_temp2/(1 - crra_coefficient) if crra_coefficient != 1
	gen ce = exp(ce_temp3) if crra_coefficient != 1
	replace ce = exp(utility) if crra_coefficient == 1
	replace ce = 0 if missing(ce)
	
	keep crra_coefficient ce var_bin16_joint_nonintl
	gen merge_coef = round(crra_coefficient * 100)

	rename ce ce_`i'
	save "$temp/ce_`i'_varbin", replace
	}
	
	{ // calculations for guardrails pre
	use "$temp/pre_utility.dta", clear
	
	keep if date == 672
	if `i' == 990 {
		keep if any_guardrail == 1
	} 
	else if `i' == 991 {
		keep if guardrail_not_intl == 1
	} 
	else if `i' == 992 {
		keep if total_intl_share_under == 1
	} 
	else if `i' == 993 {
		keep if total_eq_over == 1
	}
	else if `i' == 994 {
		keep if total_eq_under == 1
	} 
	else if `i' == 995 {
		keep if one_sector_overweight == 1
	} 
	else if `i' == 996 {
		keep if total_exp_over == 1
	} 

	// expand for different values of CRRA (2, 4, 6)
	gen temp_id = _n
	expand 3
	bys temp_id: gen crra_coefficient = (_n * 2)
	
	// calculate utility for different values of crra
	set type double
	gen utility = 0	
	set type double
	replace utility = ln(mc_return) if crra_coefficient == 1
	replace utility = ((mc_return)^(1-crra_coefficient))/(1-crra_coefficient) if crra_coefficient != 1 & crra_coefficient >= 0

	
	// determine expected mean
	keep utility crra_coefficient port_count var_bin16_joint_nonintl
	collapse (mean) utility, by(crra_coefficient var_bin16_joint_nonintl)
	di "DONE COLLAPSING FOR `i' - Initial"	
	
	gen ce_temp1 = (1-crra_coefficient)*utility if crra_coefficient != 1
	gen ce_temp2 = ln(ce_temp1) if crra_coefficient != 1
	gen ce_temp3 = ce_temp2/(1 - crra_coefficient) if crra_coefficient != 1
	gen ce = exp(ce_temp3) if crra_coefficient != 1
	replace ce = exp(utility) if crra_coefficient == 1
	replace ce = -1 if missing(ce)
	
	keep crra_coefficient ce var_bin16_joint_nonintl
	gen merge_coef = round(crra_coefficient * 100)

	rename ce ce_`i'_initial
	save "$temp/ce_`i'_initial_varbin", replace
	}
}

use "$temp/ce_991_varbin", clear
merge 1:1 merge_coef var_bin16_joint_nonintl using "$temp/ce_991_initial_varbin"
assert _m == 3
drop _m

gen prefer_guard = ce_991 > ce_991_initial

collapse (mean) prefer_guard, by(crra_coefficient)

save "$temp/crra_prefer_guard_share_var", replace

}

{ // crra utility analysis with return bins -- only for non-international joint guardrail (991)

forvalue i = 991/991 {

	{ // calculations for guardrails post
	use "$temp/pre_utility.dta", clear
	
	keep if date == `i'
		
	// expand for different values of CRRA (2, 4, 6)
	gen temp_id = _n
	expand 3
	bys temp_id: gen crra_coefficient = (_n * 2)
	
	// calculate utility for different values of crra
	set type double
	gen utility = 0	
	set type double
	replace utility = ln(mc_return) if crra_coefficient == 1
	replace utility = ((mc_return)^(1-crra_coefficient))/(1-crra_coefficient) if crra_coefficient != 1 & crra_coefficient >= 0

	
	// determine expected mean
	keep utility crra_coefficient port_count ret_bin16_joint_nonintl
	collapse (mean) utility, by(crra_coefficient ret_bin16_joint_nonintl)
	di "DONE COLLAPSING FOR `i'"	
	
	gen ce_temp1 = (1-crra_coefficient)*utility if crra_coefficient != 1
	gen ce_temp2 = ln(ce_temp1) if crra_coefficient != 1
	gen ce_temp3 = ce_temp2/(1 - crra_coefficient) if crra_coefficient != 1
	gen ce = exp(ce_temp3) if crra_coefficient != 1
	replace ce = exp(utility) if crra_coefficient == 1
	replace ce = 0 if missing(ce)
	
	keep crra_coefficient ce ret_bin16_joint_nonintl
	gen merge_coef = round(crra_coefficient * 100)

	rename ce ce_`i'
	save "$temp/ce_`i'_retbin", replace
	}
	
	{ // calculations for guardrails pre
	use "$temp/pre_utility.dta", clear
	
	keep if date == 672
	if `i' == 990 {
		keep if any_guardrail == 1
	} 
	else if `i' == 991 {
		keep if guardrail_not_intl == 1
	} 
	else if `i' == 992 {
		keep if total_intl_share_under == 1
	} 
	else if `i' == 993 {
		keep if total_eq_over == 1
	}
	else if `i' == 994 {
		keep if total_eq_under == 1
	} 
	else if `i' == 995 {
		keep if one_sector_overweight == 1
	} 
	else if `i' == 996 {
		keep if total_exp_over == 1
	} 

	// expand for different values of CRRA (2, 4, 6)
	gen temp_id = _n
	expand 3
	bys temp_id: gen crra_coefficient = (_n * 2)
	
	// calculate utility for different values of crra
	set type double
	gen utility = 0	
	set type double
	replace utility = ln(mc_return) if crra_coefficient == 1
	replace utility = ((mc_return)^(1-crra_coefficient))/(1-crra_coefficient) if crra_coefficient != 1 & crra_coefficient >= 0

	
	// determine expected mean
	keep utility crra_coefficient port_count ret_bin16_joint_nonintl
	collapse (mean) utility, by(crra_coefficient ret_bin16_joint_nonintl)
	di "DONE COLLAPSING FOR `i' - Initial"	
	
	gen ce_temp1 = (1-crra_coefficient)*utility if crra_coefficient != 1
	gen ce_temp2 = ln(ce_temp1) if crra_coefficient != 1
	gen ce_temp3 = ce_temp2/(1 - crra_coefficient) if crra_coefficient != 1
	gen ce = exp(ce_temp3) if crra_coefficient != 1
	replace ce = exp(utility) if crra_coefficient == 1
	replace ce = -1 if missing(ce)
	
	keep crra_coefficient ce ret_bin16_joint_nonintl
	gen merge_coef = round(crra_coefficient * 100)

	rename ce ce_`i'_initial
	save "$temp/ce_`i'_initial_retbin", replace
	}
}

use "$temp/ce_991_retbin", clear
merge 1:1 merge_coef ret_bin16_joint_nonintl using "$temp/ce_991_initial_retbin"
assert _m == 3
drop _m

gen prefer_guard = ce_991 > ce_991_initial

collapse (mean) prefer_guard, by(crra_coefficient)

save "$temp/crra_prefer_guard_share_ret", replace

}

{ // crra utility analysis with n-closest funds

{ // determine n-closest portfolios
use "$temp/collapse2_combined.dta", clear

// filter to pre-reform individuals affected by streamlining
keep if guardrail_not_intl == 1 
keep if date == 672

// normalize variables
egen return_used_mean = mean(return_used)
egen return_used_sd = sd(return_used)
egen var_used_mean = mean(var_used)
egen var_used_sd = sd(var_used)
gen ret_norm = (return_used - return_used_mean) / return_used_sd
gen var_norm = (var_used - var_used_mean) / var_used_sd

keep ScrubbedID return_used var_used

// perform a many to many merge in order to calculate the distance between each 
sort ScrubbedID 
assert ScrubbedID != ScrubbedID[_n-1]
gen merger = _n
save "$temp/crra merge returns", replace

local count = _N

expand _N
local count2 = _N
assert `count2' == `count' * `count'
bys ScrubbedID: replace merger = _n
foreach var in ScrubbedID return_used var_used {
	rename `var' `var'2
}

merge m:1 merger using "$temp/crra merge returns"

// filter out observations that are from the same ScrubbedID merged with itself
drop if ScrubbedID == ScrubbedID2

// determine the distance between the points
gen distance = (return_used^2 + var_used^2)^.5
sort ScrubbedID distance 
bys ScrubbedID: gen distance_order = _n

// filter to the closest 5% of investors (of those that are not this particular investor)
keep if distance_order <= round((`count' - 1) * .05)

keep ScrubbedID ScrubbedID2

rename ScrubbedID group_id
rename ScrubbedID2 ScrubbedID

// add dates back in
expand 2
bys group_id ScrubbedID: gen date = 672 if _n == 1
bys group_id ScrubbedID: replace date = 991 if _n == 2
assert !missing(date)

// merge in returns data
merge m:1 ScrubbedID date using "$temp/collapse2_combined.dta"
assert guardrail_not_intl == 0 | !inlist(date, 672, 991) if _m != 3
keep if _m == 3
gen sd_used = sqrt(var_used)

keep return_used sd_used date group_id ScrubbedID
save "$temp/n_closest_funds.dta", replace

}

// set seed (original seed from a random number generator, setting seed for consistency in replications)
set seed 66590

// will have too many observations since the number of groups (N of affected portfolios) is much larger than the other versions
// so we will have to run for each group individually
levelsof group_id, local(id_list1)
local first : word 1 of `id_list1'

foreach group of local id_list1 {

	// load and filter data
	use "$temp/n_closest_funds.dta", replace
	keep if group_id == `group'
	// di "Group number: `group'"
	
	// 500 draws for monte carlo
	expand 500
	// returns are in percent terms
	gen mc_return = rnormal(return_used,sd_used)
	// cap return at -99% (using this to prevent data from including missings after calculation)
	replace mc_return = -.99 if mc_return <= -.99
	// modify returns to be relative to a $100 initial investment
	replace mc_return = 100*(1+mc_return)
	keep group_id date mc_return
	
	// save data for this group
	save "$temp/pre_utility_n_closest.dta", replace

	foreach year_val in 672 991 {

		use "$temp/pre_utility_n_closest.dta", clear
		keep if date == `year_val'

		// expand for different values of CRRA (2, 4, 6)
		gen temp_id = _n
		expand 3
		bys temp_id: gen crra_coefficient = (_n * 2)
		
		// calculate utility for different values of crra
		set type double
		gen utility = 0	
		set type double
		replace utility = ln(mc_return) if crra_coefficient == 1
		replace utility = ((mc_return)^(1-crra_coefficient))/(1-crra_coefficient) if crra_coefficient != 1 & crra_coefficient >= 0
		
		
		// determine expected mean within bin
		keep utility crra_coefficient group_id
		collapse (mean) utility, by(crra_coefficient group_id)
		
		gen ce_temp1 = (1-crra_coefficient)*utility if crra_coefficient != 1
		gen ce_temp2 = ln(ce_temp1) if crra_coefficient != 1
		gen ce_temp3 = ce_temp2/(1 - crra_coefficient) if crra_coefficient != 1
		gen ce = exp(ce_temp3) if crra_coefficient != 1
		replace ce = exp(utility) if crra_coefficient == 1
		replace ce = -1 if missing(ce)
		
		keep crra_coefficient ce group_id
		gen merge_coef = round(crra_coefficient * 100)

		if `year_val' == 672 & `group' == `first' {
			rename ce ce_991_initial
			save "$temp/ce_n_closest_991_initial", replace
		} 
		else if `year_val' == 672 & `group' != `first' {
			rename ce ce_991_initial
			append using "$temp/ce_n_closest_991_initial"
			save "$temp/ce_n_closest_991_initial", replace

		} 
		else if `year_val' == 991 & `group' == `first' {
			rename ce ce_991
			save "$temp/ce_n_closest_991", replace
		}
		else if `year_val' == 991 & `group' != `first' {
			rename ce ce_991
			append using "$temp/ce_n_closest_991"
			save "$temp/ce_n_closest_991", replace
		} 
	}	
}

// merge crra results
use "$temp/ce_n_closest_991", clear
merge 1:1 group_id crra_coefficient using "$temp/ce_n_closest_991_initial"
assert _m == 3
drop _m

gen prefer_guard = ce_991 > ce_991_initial

collapse (mean) prefer_guard, by(crra_coefficient)

save "$temp/crra_prefer_guard_share_n_closest", replace



}

{ // crra utility analysis with no bins & ex ante returns
use "$temp/collapse2_combined.dta", clear

// filter to guardrail date investors affected by the guardrails
keep if date == 672 ///
| date == 990 & any_guardrail == 1 ///
| date == 991 & guardrail_not_intl == 1 ///
| date == 992 & total_intl_share_under == 1 ///
| date == 993 & total_eq_over == 1 ///
| date == 994 & total_eq_under == 1 ///
| date == 995 & one_sector_overweight == 1 ///
| date == 996 & total_exp_over == 1 

// generate variance bins based off of 2016 portfolios
xtile var_bin1 = ante_var if date == 672 & guardrail_not_intl == 1, nq(20)
bys ScrubbedID: egen var_bin16_joint_nonintl = max(var_bin1)
drop var_bin1

// generate return bins based off of 2016 portfolios
xtile ret_bin1 = ante_ret if date == 672 & guardrail_not_intl == 1, nq(20)
bys ScrubbedID: egen ret_bin16_joint_nonintl = max(ret_bin1)
drop ret_bin1

// identify individual portfolios by date, return, and variance
egen port_num = group(date ante_ret ante_var var_bin16_joint_nonintl)
keep port_num ante_ret ante_sd date any_guardrail guardrail_not_intl one_sector_overweight total_exp_over total_eq_under total_eq_over total_intl_share_under var_bin16_joint_nonintl ret_bin16_joint_nonintl
bys port_num: gen port_count = _N
bys port_num: keep if _n == 1


// set seed (original seed from a random number generator, setting seed for consistency in replications)
set seed 66590

// use 500 draws based on sd and mean of each portfolio to simulate the disutility of variance for each portfolio (doing this expanding for portfolio weight since random draws of protfolios would apply to all participants)
expand 500
sort port_num 
gen mc_return = rnormal(ante_ret,ante_sd)
// cap return at -99% (using this to prevent data from including missings after calculation)
replace mc_return = -.99 if mc_return <= -.99

// modify returns to be relative to a $100 initial investment
replace mc_return = 100*(1+mc_return)
drop ante_ret port_num ante_sd
expand port_count

save "$temp/pre_utility", replace

forvalue i = 990/996 {

	{ // calculations for guardrails post
	use "$temp/pre_utility.dta", clear
	
	keep if date == `i'
		
	// expand for different values of CRRA (2, 4, 6)
	gen temp_id = _n
	expand 3
	bys temp_id: gen crra_coefficient = (_n * 2)
	
	// calculate utility for different values of crra
	set type double
	gen utility = 0	
	set type double
	replace utility = ln(mc_return) if crra_coefficient == 1
	replace utility = ((mc_return)^(1-crra_coefficient))/(1-crra_coefficient) if crra_coefficient != 1 & crra_coefficient >= 0

	
	// determine expected mean
	keep utility crra_coefficient port_count
	collapse (mean) utility, by(crra_coefficient)
	di "DONE COLLAPSING FOR `i'"	
	
	gen ce_temp1 = (1-crra_coefficient)*utility if crra_coefficient != 1
	gen ce_temp2 = ln(ce_temp1) if crra_coefficient != 1
	gen ce_temp3 = ce_temp2/(1 - crra_coefficient) if crra_coefficient != 1
	gen ce = exp(ce_temp3) if crra_coefficient != 1
	replace ce = exp(utility) if crra_coefficient == 1
	replace ce = 0 if missing(ce)
	
	keep crra_coefficient ce
	gen merge_coef = round(crra_coefficient * 100)

	rename ce ce_`i'
	save "$temp/ce_`i'_ante", replace
	}
	
	{ // calculations for guardrails pre
	use "$temp/pre_utility.dta", clear
	
	keep if date == 672
	if `i' == 990 {
		keep if any_guardrail == 1
	} 
	else if `i' == 991 {
		keep if guardrail_not_intl == 1
	} 
	else if `i' == 992 {
		keep if total_intl_share_under == 1
	} 
	else if `i' == 993 {
		keep if total_eq_over == 1
	}
	else if `i' == 994 {
		keep if total_eq_under == 1
	} 
	else if `i' == 995 {
		keep if one_sector_overweight == 1
	} 
	else if `i' == 996 {
		keep if total_exp_over == 1
	} 

	// expand for different values of CRRA (2, 4, 6)
	gen temp_id = _n
	expand 3
	bys temp_id: gen crra_coefficient = (_n * 2)
	
	// calculate utility for different values of crra
	set type double
	gen utility = 0	
	set type double
	replace utility = ln(mc_return) if crra_coefficient == 1
	replace utility = ((mc_return)^(1-crra_coefficient))/(1-crra_coefficient) if crra_coefficient != 1 & crra_coefficient >= 0

	
	// determine expected mean
	keep utility crra_coefficient port_count
	collapse (mean) utility, by(crra_coefficient)
	di "DONE COLLAPSING FOR `i' - Initial"	
	
	gen ce_temp1 = (1-crra_coefficient)*utility if crra_coefficient != 1
	gen ce_temp2 = ln(ce_temp1) if crra_coefficient != 1
	gen ce_temp3 = ce_temp2/(1 - crra_coefficient) if crra_coefficient != 1
	gen ce = exp(ce_temp3) if crra_coefficient != 1
	replace ce = exp(utility) if crra_coefficient == 1
	replace ce = -1 if missing(ce)
	
	keep crra_coefficient ce
	gen merge_coef = round(crra_coefficient * 100)

	rename ce ce_`i'_initial
	save "$temp/ce_`i'_initial_ante", replace
	}
}





}


