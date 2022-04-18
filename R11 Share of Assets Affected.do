****** Share of Assets Affected ********

// Fraction of Streamlined Assets 

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
keep if inlist(date, 672) //, 684, 696)

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

keep ScrubbedID date Fund FundsHeld total_assets port_weight steady_pre steady_pre_sc steady_fund AgeasofNov2018 RoundedSalary Gender
gen counter = 1
bys ScrubbedID date: gen n_funds = _N
bys Fund steady_pre date: gen fund_counter = (_n == 1)
gen dropped_dollars = (-1 * (steady_fund-1)) * FundsHeld
gen steady_dollars = steady_fund*FundsHeld

keep if inlist(date,672)

egen streamlined_assets = sum(dropped_dollars)
egen steady_assets = sum(steady_dollars)
gen test = steady_assets + streamlined_assets

egen plan_assets = sum(FundsHeld)
gen fraction = streamlined_assets / plan_assets
sum test plan_assets

format streamlined_assets %19.0g

egen stream_assets = sum(FundsHeld) if steady_pre == 0
format stream_assets %12.0g // $255,119,696
egen helper1 = max(stream_assets)

egen nsa = sum(FundsHeld) if steady_pre == 1
egen helper2 = max(nsa)

gen test2 = helper1 + helper2  

sum test test2 plan_assets

keep Scr helper1 
format helper1 %12.0g
save "$temp/stream_assets", replace

******* GUARDRAIL FRACTIONS ************

use "$temp/onlytdf_joint_adjust", clear
merge 1:1 ScrubbedID using "$temp/onlytdf_exp_ratio_adjust"
assert _m == 3 
drop _m
merge 1:1 ScrubbedID using "$temp/onlytdf_eq_under_adjust"
assert _m == 3 
drop _m
merge 1:1 ScrubbedID using "$temp/onlytdf_eq_over_adjust"
assert _m == 3 
drop _m
merge 1:1 ScrubbedID using "$temp/onlytdf_intl_adjust"
assert _m == 3 
drop _m
merge 1:1 ScrubbedID using "$temp/onlytdf_sector_adjust"
assert _m == 3 
drop _m

save "$temp/guardrail fraction", replace

reshape long adjust, i(ScrubbedID) j(guardrail, string)
bys ScrubbedID: assert _N == 7


save "$temp/guardrail assets affected", replace

//

use "$temp/collapse2.dta", clear

keep if date == 672

merge 1:m Scr using "$temp/guardrail fraction"
drop if _m != 3
sort Scr

gen affected_guardrail = adjust_non_intl * total_assets
egen guard_tot = sum(affected_guardrail)
egen plan_assets = sum(total_assets)
gen frac = guard_tot / plan_assets 

// 7.6% affected by non-intl guardrail

gen prop2 = adjust_exp_ratio + adjust_eq_under + adjust_eq_over + adjust_sector
replace prop2 = adjust_eq_over + ((1 - adjust_eq_over) * (adjust_eq_under + ((1 - adjust_eq_under) * (adjust_exp_ratio + ((1 - adjust_exp_ratio) * adjust_sector)))))

gen affected_guardrail2 = prop2 * total_assets
egen guard_tot2 = sum(affected_guardrail2)
gen frac2 = guard_tot2 / plan_assets 

bro if guard_tot != prop2

su frac*

******* STREAMLINING EXPENSE RATIO ************

use "$temp/collapse2.dta", clear

keep ScrubbedID steady_pre steady_pre_sc smart
bys ScrubbedID: keep if _n == 1
tempfile steady_pre_list 
save "`steady_pre_list'"

use "$temp/cleaning_step_one.dta", clear
keep if inlist(date, 672, 684)
merge m:1 ScrubbedID using "`steady_pre_list'"
// assert _m != 2
// filter to observations in final data (including the smart/steady investors)
keep if _m == 3
drop _m

merge m:1 Fund using "$temp/funds_2016_2017"
gen steady_fund = (_m == 3)
drop _m

// clean variables
la define steady_pre 0 "Streamlined group" ///
1 "Non-streamlined group"
la val steady_pre steady_pre

sort Scr date 

gen exp_pre_stream = total_exp_temp if steady_pre == 0 & date == 672
egen helper1 = mean(exp_pre_stream)

gen exp_post_stream = total_exp_temp if steady_pre == 0 & date == 684
egen helper2 = mean(exp_post_stream)

gen diff_exp = helper1 - helper2
replace diff_exp = diff_exp * 100
tab diff_exp

// 22 basis point reduction 

gen dollar_saved = diff_exp * 255119696 / 100
format dollar_saved %19.0g
tab dollar_saved // $566,989 

preserve 
collapse (firstnm) steady_pre, by(Scr)
egen streamliners = count(steady_pre) if steady_pre == 0
tab streamliners // 2324 total streamliners 
restore 

// average dollar amount per person 

gen avg_dollar = dollar_saved / 2324 
tab avg_dollar // $243.97

sum Age, det
// median person is 50 years of age 

// compounded principal in 15 years: $32,323 
