// calculating miscellaneous numbers for paper

// total investors and amount invested in 2018
use "$temp/individual_ports.dta", clear
keep if date == 696
bys ScrubbedID: keep if _n == 1
gen count = 1
collapse (sum) count total_assets
browse


// total investors in cleaned data
use "$temp/collapse2_combined", clear
keep if date == 672 | date == 684
tab date


// total number of funds offered (as opposed to held)
use "$temp/individual_ports.dta", clear
keep if date == 672
bys Fund: keep if _n == 1
count


// share overweighting all sector funds (>50% combined)
use "$temp/collapse2_combined", clear
keep if date == 672

drop total_eq_violation total_exp_over total_intl_share_under total_sector_overweight ///
one_sector_overweight guardrail_div guardrail_not_intl any_guardrail 

merge m:1 ScrubbedID date using "$temp/guardrail each date flags"
drop if _m == 2
assert _m == 3 
drop _m

summ total_sector_overweight
summ one_sector_overweight


// comparison of reasonable outside funds for sector funds to required assets for individuals violating sector guardrail
use "$temp/sector_outside_holdings", clear
gen compare_savings = non_plan_non_sector_assets  / FundsHeld
summ compare_savings if sector > .1, d
summ enough_outside if sector > .1

// comparison of reasonable outside funds for gold fund to required assets for individuals violating sector guardrail
use "$temp/gold_outside_holdings", clear
summ enough_outside
summ diff_savings if enough_outside == 0
local j = r(N)
count if !missing(RoundedSalary)
local k = r(N)
di `j'/`k'

// differences in RMSD 
use "$temp/collapse2_combined.dta", clear
keep if date == 672
gen RMSD = sqrt(_rmse)

summ RMSD if guardrail_not_intl == 1
local guard = r(mean)
summ RMSD if guardrail_not_intl == 0
local not_guard = r(mean)
di `guard' - `not_guard'


// average differences in expense ratios
use "$temp/collapse2_combined.dta", clear
keep if inlist(date, 672, 684)
summ exp_ratio if date == 672
local pre = r(mean)
summ exp_ratio if date == 684
local post = r(mean)
di `pre' - `post'


// average expense ratio for Fidelity TDFs
use "$temp/cleaning_step_one.dta", clear
keep if date == 672
bys Fund: keep if _n == 1
keep Fund exp_ratio
keep if strpos(Fund, "FID FREEDOM K") > 0 & strpos(Fund, "INCOME") == 0
summ exp_ratio

// average expense ratios
use "$temp/collapse2_combined.dta", clear
keep if date == 672
summ total_exp_over_50 total_exp_over total_exp_over_100


// percent violating equities guardrail by age
use "$temp/glidepath graph data", clear
merge 1:1 age using "$temp/glidepath violation by age"
assert _m == 3
browse total_eq_violation age graph_equities*


// percent violating glidepath guardrails
use "$temp/collapse2_combined.dta", clear
keep if date == 672
summ total_eq_under total_eq_over total_eq_violation


// returns for international vs. domestic equities funds for 2017-2018
use "$temp/full_data.dta", clear
keep if date == 672
bys Fund: keep if _n == 1
keep if inlist(Fund, "OFW2-VANG TOT STK MKT IS", "OS4X-VANG TOT INTL STK AD")
gen future_ret = (1+future_monthly_return)^12-1
gen forward_future_ret = (1+twelve_month_future_return)^12-1
keep Fund forward_future_ret
browse


// percent affected by streamlining
use "$temp/collapse2_combined.dta", clear
keep if date == 672
summ steady_pre
di 1- r(mean)

import excel "$output/63 - Share of Portfolio Streamlined.xlsx", clear
browse


// percent staying in plan defaulted funds
import excel "$output/64 - Streamlined Defaults 2017-2018.xlsx", clear
browse
import excel "$output/64 - Streamlined Defaults 2017-2018.xlsx", clear firstrow
di Shareofstreamlinedthatarein[2]/Shareofstreamlinedthatarein[1]


// percent of assets affected by guardrails
import excel "$output/66 - Share of Portfolio Affected By Guardrails.xlsx", clear
browse


// proportion in at least one tdf
use "$temp/collapse2_combined.dta", clear
keep if inlist(date, 672, 991)
gen in_tdf = (total_tdf_share > 0 & !missing(total_tdf_share))
bys date: summ in_tdf if steady_pre != 1


{ // 2018 new hire default stickiness
// load data 
use "$temp/individual_ports.dta", clear
joinby Fund date using "$temp/fund_returns_series_crosswalk_post.dta"

// filter to 2018
keep if date == 696

// filter to new hires
gen hire_month = mofd(HireDate)
gen hire_year = yofd(HireDate)
keep if hire_year == 2018 | (hire_year == 2017 & hire_month > 1)

// determine number of funds held
bys ScrubbedID date: gen n_funds = _N 

// determine if funds held are in a TDF/default TDF
gen vanguard_tdf = (strpos(Fund,"INST TR") > 0)
gen any_tdf = ((vanguard_tdf == 1) | strpos(Fund, "FID FREEDOM") > 0)
collapse (min) n_funds vanguard_tdf any_tdf, by(ScrubbedID)
gen default = n_funds == 1 & vanguard_tdf == 1
gen any_single_tdf = n_funds == 1 & any_tdf == 1

// ~80% have all funds in one Vanguard TDF, 8% have all funds in one Fidelity TDF, and 2% have all funds split across multiple TDFs
summ any_tdf any_single_tdf default
}


