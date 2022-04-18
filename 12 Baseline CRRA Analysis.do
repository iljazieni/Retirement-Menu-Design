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
use "$temp/collapse2.dta", clear

// filter to individuals affected by streamlining
keep if steady_pre != 1
keep if inlist(date,684,672)

// generate variance bins based off of 2016 portfolios
xtile var_bin1 = var_used if date == 672, nq(20)
bys ScrubbedID: egen var_bin16 = max(var_bin1)
drop var_bin1

// generate return bins based off of 2016 portfolios
xtile ret_bin1 = return_used if date == 672, nq(20)
bys ScrubbedID: egen ret_bin16 = max(ret_bin1)
drop ret_bin1

// hist return_used if date == 672, color(red%30) xline(0) ylab(,nogrid)

// identify individual portfolios by date, return, and variance
egen port_num = group(date return_used var_used var_bin)
gen sd_used = sqrt(var_used)
keep port_num return_used sd_used date var_bin ret_bin16
bys port_num: gen port_count = _N
bys port_num: keep if _n == 1


// set seed (original seed from a random number generator, setting seed for consistency in replications)
set seed 66590

// use 500 draws based on sd and mean of each portfolio to simulate the disutility of variance for each portfolio (doing this expanding for portfolio weight since random draws of protfolios would apply to all participants)
expand 500
sort port_num 
// returns are in percent terms
gen mc_return = rnormal(return_used,sd_used)
// cap return at -99% (using this to prevent data from including missings after calculation)
replace mc_return = -.99 if mc_return <= -.99
// hist mc_return, color(red%30) xline(0) ylab(,nogrid)
count if date == 672 & mc_return == -.99
local ninetynine_pre = r(N) 
count if date == 672 & mc_return == -.99
local ninetynine_post = r(N) 

count if date == 672 
local count_672 = r(N) 
count if date == 684
local count_684 = r(N) 

putexcel set "$output/65 - CRRA returns capped", modify
putexcel B1 = ("Count Capped At -.99")
putexcel C1 = ("Total Monte Carlo Draws")
putexcel A2 = ("Pre-Reform")
putexcel A3 = ("Post-Reform")
putexcel B2 = (`ninetynine_pre')
putexcel B3 = (`ninetynine_post')
putexcel C2 = (`count_672')
putexcel C3 = (`count_684')
putexcel close

// modify returns to be relative to a $100 initial investment
replace mc_return = 100*(1+mc_return)
drop return_used port_num sd_used
expand port_count 

save "$temp/pre_utility", replace

foreach year_val in 672 684 {

	use "$temp/pre_utility.dta", clear
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
	keep utility crra_coefficient port_count
	collapse (mean) utility, by(crra_coefficient)
	di "DONE COLLAPSING FOR DATE = `year_val'"	
	
	gen ce_temp1 = (1-crra_coefficient)*utility if crra_coefficient != 1
	gen ce_temp2 = ln(ce_temp1) if crra_coefficient != 1
	gen ce_temp3 = ce_temp2/(1 - crra_coefficient) if crra_coefficient != 1
	gen ce = exp(ce_temp3) if crra_coefficient != 1
	replace ce = exp(utility) if crra_coefficient == 1
	replace ce = -1 if missing(ce)
	
	keep crra_coefficient ce
	gen merge_coef = round(crra_coefficient * 100)

	if `year_val' == 672 {
		rename ce ce_pre
		save "$temp/pre_ce", replace
	} 
	else if `year_val' == 684 {
		rename ce ce_post
		save "$temp/post_ce", replace

	} 

}

// merge crra results
use "$temp/post_ce", clear
merge 1:1 merge_coef using "$temp/pre_ce"
assert _m == 3
drop _m

forvalues i = 990/996 {
	merge 1:1 merge_coef using "$temp/ce_`i'"
	assert _m == 3
	drop _m
	merge 1:1 merge_coef using "$temp/ce_`i'_initial"
	assert _m == 3
	drop _m
}

// convert ce to a return (rather than relative to a $100 initial investment)
foreach name in pre post 990 991 992 993 994 995 996 {
	replace ce_`name' = (ce_`name' - 100) / 100
	cap replace ce_`name'_initial = (ce_`name'_initial - 100) / 100
	
}

/* date for reference
la define date 672 "Pre-Reform" ///
684 "Post-Reform" ///
990 "Joint Guardrails to TDF, All" ///
991 "Joint Guardrails to TDF, No Intl" ///
992 "International Share of Equities Guardrail to TDF" ///
993 "Maximum Equities Guardrail to TDF" ///
994 "Minimum Equities Guardrail to TDF" ///
995 "Sector Fund Guardrail to TDF" ///
996 "Expense Ratio Guardrail to TDF" 
*/

rename ce_pre ce_stream_initial
rename ce_post ce_stream
rename ce_990 ce_any_guardrail 
rename ce_991 ce_guardrail_not_intl 
rename ce_992 ce_one_intl_share_under
rename ce_993 ce_total_eq_over 
rename ce_994 ce_total_eq_under 
rename ce_995 ce_one_sector_over
rename ce_996 ce_exp_ratio_over 
rename ce_990_initial ce_any_guardrail_initial
rename ce_991_initial ce_guardrail_not_intl_initial
rename ce_992_initial ce_one_intl_share_under_initial
rename ce_993_initial ce_total_eq_over_initial
rename ce_994_initial ce_total_eq_under_initial
rename ce_995_initial ce_one_sector_over_initial
rename ce_996_initial ce_exp_ratio_over_initial

// create variables for change in certainy equivalent from pre-reform
foreach var in stream any_guardrail guardrail_not_intl one_intl_share_under total_eq_over total_eq_under one_sector_over exp_ratio_over {
	gen diff_`var' = ce_`var' - ce_`var'_initial
}

sort crra_coefficient
assert crra_coefficient[1] == 2
assert crra_coefficient[2] == 4
assert crra_coefficient[3] == 6


// add columns to delta sharpe ratio table for change in certainty equivalent



putexcel set "$output/70 - CRRA Table.xlsx", modify sheet("No Bins")

putexcel A3 = "Streamlined"
putexcel A5 = "Any Guardrail"
putexcel A6 = "Any Non-International Guardrail"
putexcel A7 = "Sector Fund Guardrail"
putexcel A8 = "Expense Ratio Guardrail"
putexcel A9 = "Minimum Equity Exposure Guardrail"
putexcel A10 = "Maximum Equity Exposure Guardrail"
putexcel A11 = "International Equities As Share of Equities Guardrail"

putexcel A15 = "Values are not weighted by assets."

putexcel B1:Z20, hcenter
putexcel B1:D1, border(bottom)

local vars "stream any_guardrail guardrail_not_intl one_sector_over exp_ratio_over total_eq_under total_eq_over one_intl_share_under "
local rows "3 5 6 7 8 9 10 11"
local words : word count `vars'

putexcel B1:C1, merge hcenter
putexcel D1:E1, merge hcenter
putexcel F1:G1, merge hcenter
putexcel B1 = ("CRRA Coefficient: 2")
putexcel D1 = ("CRRA Coefficient: 4")
putexcel F1 = ("CRRA Coefficient: 6")
putexcel C2 = ("Delta Certainty Equivalent")
putexcel E2 = ("Delta Certainty Equivalent")
putexcel G2 = ("Delta Certainty Equivalent")
putexcel B2 = ("Pre-Reform Certainty Equivalent")
putexcel D2 = ("Pre-Reform Certainty Equivalent")
putexcel F2 = ("Pre-Reform Certainty Equivalent")

forvalues i = 1 / `words' {

	local word : word `i' of `vars'
	di "`word'"
	local row : word `i' of `rows'
	di `row'
	putexcel C`row' = (diff_`word'[1]), nformat("0.000")
	putexcel E`row' = (diff_`word'[2]), nformat("0.000")
	putexcel G`row' = (diff_`word'[3]), nformat("0.000")
	putexcel B`row' = (ce_`word'_initial[1]), nformat("0.000")
	putexcel D`row' = (ce_`word'_initial[2]), nformat("0.000")
	putexcel F`row' = (ce_`word'_initial[3]), nformat("0.000")
	

}

putexcel close


}

{ // crra utility analysis with variance bins

foreach year_val in 672 684 {

	use "$temp/pre_utility.dta", clear
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
	keep utility crra_coefficient port_count var_bin16
	collapse (mean) utility, by(crra_coefficient var_bin16)
	di "DONE COLLAPSING FOR DATE = `year_val'"	
	
	gen ce_temp1 = (1-crra_coefficient)*utility if crra_coefficient != 1
	gen ce_temp2 = ln(ce_temp1) if crra_coefficient != 1
	gen ce_temp3 = ce_temp2/(1 - crra_coefficient) if crra_coefficient != 1
	gen ce = exp(ce_temp3) if crra_coefficient != 1
	replace ce = exp(utility) if crra_coefficient == 1
	replace ce = -1 if missing(ce)
	
	keep crra_coefficient ce var_bin16
	gen merge_coef = round(crra_coefficient * 100)

	if `year_val' == 672 {
		rename ce ce_pre
		save "$temp/pre_ce_varbin", replace
	} 
	else if `year_val' == 684 {
		rename ce ce_post
		save "$temp/post_ce_varbin", replace

	} 

}

// merge crra results
use "$temp/post_ce_varbin", clear
merge 1:1 var_bin16 crra_coefficient using "$temp/pre_ce_varbin"
assert _m == 3
drop _m

gen prefer_post = ce_post > ce_pre

collapse (mean) prefer_post, by(crra_coefficient)

merge 1:1 crra_coefficient using "$temp/crra_prefer_guard_share_var"
assert _m == 3
drop _m

la var crra_coefficient "CRRA Coefficient"
la var prefer_post "Share of Variance Bins That Prefer Post-Reform Portfolios Over Non-Streamlined"
la var prefer_guard "Share of Variance Bins That Prefer Guardrails Portfolios Over Non-Streamlined"

export excel "$output/67 - CRRA Robustness.xlsx", sheet("Variance Bins") sheetreplace keepcellfmt firstrow(varlabels)

}

{ // crra utility analysis with return bins

foreach year_val in 672 684 {

	use "$temp/pre_utility.dta", clear
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
	keep utility crra_coefficient port_count ret_bin16
	collapse (mean) utility, by(crra_coefficient ret_bin16)
	di "DONE COLLAPSING FOR DATE = `year_val'"	
	
	gen ce_temp1 = (1-crra_coefficient)*utility if crra_coefficient != 1
	gen ce_temp2 = ln(ce_temp1) if crra_coefficient != 1
	gen ce_temp3 = ce_temp2/(1 - crra_coefficient) if crra_coefficient != 1
	gen ce = exp(ce_temp3) if crra_coefficient != 1
	replace ce = exp(utility) if crra_coefficient == 1
	replace ce = -1 if missing(ce)
	
	keep crra_coefficient ce ret_bin16
	gen merge_coef = round(crra_coefficient * 100)

	if `year_val' == 672 {
		rename ce ce_pre
		save "$temp/pre_ce_varbin", replace
	} 
	else if `year_val' == 684 {
		rename ce ce_post
		save "$temp/post_ce_varbin", replace

	} 

}

// merge crra results
use "$temp/post_ce_varbin", clear
merge 1:1 ret_bin16 crra_coefficient using "$temp/pre_ce_varbin"
assert _m == 3
drop _m

gen prefer_post = ce_post > ce_pre

collapse (mean) prefer_post, by(crra_coefficient)

merge 1:1 crra_coefficient using "$temp/crra_prefer_guard_share_ret"
assert _m == 3
drop _m

la var crra_coefficient "CRRA Coefficient"
la var prefer_post "Share of Return Bins That Prefer Post-Reform Portfolios Over Non-Streamlined"
la var prefer_guard "Share of Return Bins That Prefer Guardrails Portfolios Over Non-Streamlined"

export excel "$output/67 - CRRA Robustness.xlsx", sheet("Return Bins") sheetreplace keepcellfmt firstrow(varlabels)

}

{ // crra utility analysis with n-closest funds

{ // determine n-closest portfolios
use "$temp/collapse2_combined.dta", clear

// filter to pre-reform individuals affected by streamlining
keep if steady_pre != 1
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
bys group_id ScrubbedID: replace date = 684 if _n == 2
assert !missing(date)

// merge in returns data
merge m:1 ScrubbedID date using "$temp/collapse2_combined.dta"
assert steady_pre == 1 | !inlist(date, 672, 684) if _m != 3
keep if _m == 3
gen sd_used = sqrt(var_used)

keep return_used sd_used date group_id ScrubbedID
save "$temp/n_closest_funds.dta", replace

}

// set seed (original seed from a random number generator, setting seed for consistency in replications)
set seed 66590

// will have too many observations since the number of groups (N of affected portfolios) is much larger than the other versions
// so we will have to run for each group individually
levelsof group_id, local(id_list)
local first : word 1 of `id_list'

foreach group of local id_list {
	
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

	
	foreach year_val in 672 684 {

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
			rename ce ce_pre
			save "$temp/pre_ce_n_closest", replace
		} 
		else if `year_val' == 672 & `group' != `first' {
			rename ce ce_pre
			append using "$temp/pre_ce_n_closest"
			save "$temp/pre_ce_n_closest", replace

		} 
		else if `year_val' == 684 & `group' == `first' {
			rename ce ce_post
			save "$temp/post_ce_n_closest", replace

		}
		else if `year_val' == 684 & `group' != `first' {
			rename ce ce_post
			append using "$temp/post_ce_n_closest"
			save "$temp/post_ce_n_closest", replace
		} 
	}	
}

// merge crra results
use "$temp/post_ce_n_closest", clear
merge 1:1 group_id crra_coefficient using "$temp/pre_ce_n_closest"
assert _m == 3
drop _m

gen prefer_post = ce_post > ce_pre

collapse (mean) prefer_post, by(crra_coefficient)

save "$temp/crra_prefer_stream_share_closest", replace

use "$temp/crra_prefer_stream_share_closest", replace
merge 1:1 crra_coefficient using "$temp/crra_prefer_guard_share_n_closest"
assert _m == 3
drop _m

la var crra_coefficient "CRRA Coefficient"
la var prefer_post "Share of Investor Bins That Prefer Post-Reform Portfolios Over Non-Streamlined"
la var prefer_guard "Share of Investor Bins That Prefer Guardrails Portfolios Over Non-Streamlined"

export excel "$output/67 - CRRA Robustness.xlsx", sheet("N Closest") sheetreplace keepcellfmt firstrow(varlabels)

}

{ // crra utility analysis with no bins & ex ante returns
use "$temp/collapse2.dta", clear

// filter to individuals affected by streamlining
keep if steady_pre != 1
keep if inlist(date,684,672)

// generate variance bins based off of 2016 portfolios
xtile var_bin1 = ante_var if date == 672, nq(20)
bys ScrubbedID: egen var_bin16 = max(var_bin1)
drop var_bin1

// generate return bins based off of 2016 portfolios
xtile ret_bin1 = ante_ret if date == 672, nq(20)
bys ScrubbedID: egen ret_bin16 = max(ret_bin1)
drop ret_bin1

// hist ante_ret if date == 672, color(red%30) xline(0) ylab(,nogrid)

// identify individual portfolios by date, return, and variance
egen port_num = group(date ante_ret ante_var var_bin)
keep port_num ante_ret ante_sd date var_bin ret_bin16
bys port_num: gen port_count = _N
bys port_num: keep if _n == 1


// set seed (original seed from a random number generator, setting seed for consistency in replications)
set seed 66590

// use 500 draws based on sd and mean of each portfolio to simulate the disutility of variance for each portfolio (doing this expanding for portfolio weight since random draws of protfolios would apply to all participants)
expand 500
sort port_num 
// returns are in percent terms
gen mc_return = rnormal(ante_ret,ante_sd)
// cap return at -99% (using this to prevent data from including missings after calculation)
replace mc_return = -.99 if mc_return <= -.99
// hist mc_return, color(red%30) xline(0) ylab(,nogrid)
count if date == 672 & mc_return == -.99
local ninetynine_pre = r(N) 
count if date == 672 & mc_return == -.99
local ninetynine_post = r(N) 

count if date == 672 
local count_672 = r(N) 
count if date == 684
local count_684 = r(N) 

// modify returns to be relative to a $100 initial investment
replace mc_return = 100*(1+mc_return)
drop ante_ret port_num ante_sd
expand port_count 

save "$temp/pre_utility", replace

foreach year_val in 672 684 {

	use "$temp/pre_utility.dta", clear
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
	keep utility crra_coefficient port_count
	collapse (mean) utility, by(crra_coefficient)
	di "DONE COLLAPSING FOR DATE = `year_val'"	
	
	gen ce_temp1 = (1-crra_coefficient)*utility if crra_coefficient != 1
	gen ce_temp2 = ln(ce_temp1) if crra_coefficient != 1
	gen ce_temp3 = ce_temp2/(1 - crra_coefficient) if crra_coefficient != 1
	gen ce = exp(ce_temp3) if crra_coefficient != 1
	replace ce = exp(utility) if crra_coefficient == 1
	replace ce = -1 if missing(ce)
	
	keep crra_coefficient ce
	gen merge_coef = round(crra_coefficient * 100)

	if `year_val' == 672 {
		rename ce ce_pre
		save "$temp/pre_ce_ante", replace
	} 
	else if `year_val' == 684 {
		rename ce ce_post
		save "$temp/post_ce_ante", replace

	} 

}

// merge crra results
use "$temp/post_ce_ante", clear
merge 1:1 merge_coef using "$temp/pre_ce_ante"
assert _m == 3
drop _m

forvalues i = 990/996 {
	merge 1:1 merge_coef using "$temp/ce_`i'_ante"
	assert _m == 3
	drop _m
	merge 1:1 merge_coef using "$temp/ce_`i'_initial_ante"
	assert _m == 3
	drop _m
}

// convert ce to a return (rather than relative to a $100 initial investment)
foreach name in pre post 990 991 992 993 994 995 996 {
	replace ce_`name' = (ce_`name' - 100) / 100
	cap replace ce_`name'_initial = (ce_`name'_initial - 100) / 100
	
}

/* date for reference
la define date 672 "Pre-Reform" ///
684 "Post-Reform" ///
990 "Joint Guardrails to TDF, All" ///
991 "Joint Guardrails to TDF, No Intl" ///
992 "International Share of Equities Guardrail to TDF" ///
993 "Maximum Equities Guardrail to TDF" ///
994 "Minimum Equities Guardrail to TDF" ///
995 "Sector Fund Guardrail to TDF" ///
996 "Expense Ratio Guardrail to TDF" 
*/

rename ce_pre ce_stream_initial
rename ce_post ce_stream
rename ce_990 ce_any_guardrail 
rename ce_991 ce_guardrail_not_intl 
rename ce_992 ce_one_intl_share_under
rename ce_993 ce_total_eq_over 
rename ce_994 ce_total_eq_under 
rename ce_995 ce_one_sector_over
rename ce_996 ce_exp_ratio_over 
rename ce_990_initial ce_any_guardrail_initial
rename ce_991_initial ce_guardrail_not_intl_initial
rename ce_992_initial ce_one_intl_share_under_initial
rename ce_993_initial ce_total_eq_over_initial
rename ce_994_initial ce_total_eq_under_initial
rename ce_995_initial ce_one_sector_over_initial
rename ce_996_initial ce_exp_ratio_over_initial

// create variables for change in certainy equivalent from pre-reform
foreach var in stream any_guardrail guardrail_not_intl one_intl_share_under total_eq_over total_eq_under one_sector_over exp_ratio_over {
	gen diff_`var' = ce_`var' - ce_`var'_initial
}

sort crra_coefficient
assert crra_coefficient[1] == 2
assert crra_coefficient[2] == 4
assert crra_coefficient[3] == 6


// add columns to delta sharpe ratio table for change in certainty equivalent

local vars "stream any_guardrail guardrail_not_intl one_sector_over exp_ratio_over total_eq_under total_eq_over one_intl_share_under "
local rows "2 4 5 6 7 8 9 10"
local words : word count `vars'

putexcel set "$output/67 - CRRA Robustness.xlsx", modify sheet("Ex Ante Robustness")


putexcel A2 = "Streamlined"
putexcel A4 = "Any Guardrail"
putexcel A5 = "Any Non-International Guardrail"
putexcel A6 = "Sector Fund Guardrail"
putexcel A7 = "Expense Ratio Guardrail"
putexcel A8 = "Minimum Equity Exposure Guardrail"
putexcel A9 = "Maximum Equity Exposure Guardrail"
putexcel A10 = "International Equities As Share of Equities Guardrail"

putexcel B1 = ("Delta Certainty Equivalent (CRRA Coefficient: 2)")
putexcel C1 = ("Delta Certainty Equivalent (CRRA Coefficient: 4)")
putexcel D1 = ("Delta Certainty Equivalent (CRRA Coefficient: 6)")

forvalues i = 1 / `words' {

	local word : word `i' of `vars'
	di "`word'"
	local row : word `i' of `rows'
	di `row'
	putexcel B`row' = (diff_`word'[1]), nformat("0.000")
	putexcel C`row' = (diff_`word'[2]), nformat("0.000")
	putexcel D`row' = (diff_`word'[3]), nformat("0.000")
	

}

putexcel close


}









