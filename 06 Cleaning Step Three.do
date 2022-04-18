/*
Guardrails Baseline Cleaning Step Three 
ZRS 

Goal:
-- 

Notes:
--

Updates:
-- 10/7/19: filter to individuals present before and after reform
-- 11/6/19: update pre-post fund list to ignore share class changes
-- 11/7/19: calculate returns for sharpe ratio using arithmetic mean (as was done before), but calculate annualizaed returns as geometric
-- 11/23/19: add ex ante returns data

*/

foreach var in full_data guard_intrm_onlytdf_joint_nonintl guard_intrm_onlytdf_joint_all guard_intrm_onlytdf_intl guard_intrm_onlytdf_equitiesover guard_intrm_onlytdf_equitiesunder guard_intrm_onlytdf_sector guard_intrm_onlytdf_expenseratio {

// local var = "guard_intrm_onlytdf_equitiesover"
// local var = "full_data"

// load main dataset
if "`var'" == "full_data" {
	use "$temp/full_data.dta", clear
}
else {
	use "$temp/`var'_fulldata.dta", clear
}
cap drop _m


{ // create fund lists from pre and post reform
// load mapping
preserve
	import excel "$input/fund_transfer_crosswalk update 2019_10_23.xls", firstrow clear
	keep if present_in_both_allow_share_clas == 1
	keep Fund
	save "$temp/funds_2016_2017", replace
restore
preserve
	import excel "$input/fund_transfer_crosswalk update 2019_10_23.xls", firstrow clear
	keep if map_to_fund == Fund
	keep Fund
	save "$temp/funds_2016_2017_shareclass", replace
restore
}

{ // merge in fund list and calculate share held in these funds
merge m:1 Fund using "$temp/funds_2016_2017"
gen safe_weight = port_weight if _m == 3
replace safe_weight = 0 if missing(safe_weight)
bys ScrubbedID date: gen safe_share = sum(safe_weight)
gen steady_investor = 1 if date == 672 & round(safe_share,.0001) == 1
replace steady_investor = 0 if missing(steady_investor)
bys ScrubbedID: egen steady_pre = max(steady_investor)
replace steady_pre = round(steady_pre,.001)
drop steady_investor _m

merge m:1 Fund using "$temp/funds_2016_2017_shareclass"
gen safe_weight_sc = port_weight if _m == 3
replace safe_weight_sc = 0 if missing(safe_weight_sc)
bys ScrubbedID date: gen safe_share_sc = sum(safe_weight_sc)
gen steady_investor_sc = 1 if date == 672 & round(safe_share_sc,.0001) == 1
replace steady_investor_sc = 0 if missing(steady_investor_sc)
bys ScrubbedID: egen steady_pre_sc = max(steady_investor_sc)
replace steady_pre_sc = round(steady_pre_sc,.001)
drop steady_investor_sc _m



gen fid_tdf1 = (strpos(Fund, "FID FREEDOM ") > 0)
gen van_tdf1 = (strpos(Fund, "VANG INST TR") > 0 | strpos(Fund, "VANG TARGET RET") > 0)
bys ScrubbedID date: egen fid_tdf = max(fid_tdf1)
bys ScrubbedID date: egen van_tdf = max(van_tdf1)

gen fid_tdf_share1 = fid_tdf1*port_weight
gen van_tdf_share1 = van_tdf1*port_weight

bys ScrubbedID date: egen fid_tdf_share = total(fid_tdf_share1)
bys ScrubbedID date: egen van_tdf_share = total(van_tdf_share1)

gen all_van_intl = (Fund == "OS4X-VANG TOT INTL STK AD") & port_weight == 1
gen all_van_domestic = (Fund == "OFW2-VANG TOT STK MKT IS") & port_weight == 1

drop van_tdf1 fid_tdf1 van_tdf_share1 fid_tdf_share1

}

{ // filter to investors that are present both immediately pre- and immediately post-reform
gen temp = (date == 672)
bys ScrubbedID: egen present_pre = max(temp)
drop temp
gen temp = (date == 684)
bys ScrubbedID: egen present_post = max(temp)
keep if present_pre == 1 & present_post == 1
drop present_pre present_post temp



if "`var'" != "full_data" {
	drop if date == 684
}

}

{ // flag investors that were entirely in TDFs before reform
gen smart_investor = 1 if is_target_date == 1 & port_weight == 1 & date == 672
replace smart_investor = 0 if missing(smart_investor)
egen smart = max(smart_investor), by(ScrubbedID)
drop smart_investor

}

{ // calculate returns and collapse to annual data
//future ret and future var, are the ex post 24 month performance
gen future_ret = (1+future_monthly_return)^12-1
gen future_var = (sqrt(12)*future_monthly_sd)^2
gen rf_fut_ret_sharpe = (1+rf_fut_monthly_return_sharpe)^12-1
gen rf_fut_var_sharpe = (sqrt(12)*rf_fut_monthly_sd_sharpe)^2

//forward future ret and forward future var are the 12-36 month performance (so we can compare what would have happened with no reform)
gen forward_future_ret = (1+twelve_month_future_return)^12-1
gen forward_future_var = (sqrt(12)*twelve_month_future_sd)^2

gen rf_forward_fut_ret_sharpe = (1+rf_12_month_fut_return_sharpe)^12-1
gen rf_forward_fut_var_sharpe = (sqrt(12)*rf_12_month_fut_sd_sharpe)^2

bys ScrubbedID: egen age2018 = max(AgeasofNov2018)

merge m:1 ScrubbedID date using "$temp/asset_list"
assert _m != 1
keep if _m == 3
drop _m

collapse (mean) n_fund forward_future_ret forward_future_var future_ret future_var annized_five_yr_ret five_year_var five_years_flag steady_pre steady_pre_sc van_tdf fid_tdf ///
van_tdf_share fid_tdf_share all_van_intl all_van_domestic year rf_fut_ret_sharpe rf_fut_var_sharpe rf_forward_fut_ret rf_forward_fut_var ///
dominated_simple cash_bonds equities oth_investments age2018 sector gold money_market goldbug one_sector_overweight ///
total_mm_overweight exp_ratio total_assets intl_equity_share beta _b_* _rmse _R2 smart, by(ScrubbedID date)

} 

{ // calculate sharpe ratios
gen rf_fut_sd_sharpe = sqrt(rf_fut_var_sharpe)
gen rf_forward_fut_sd_sharpe = sqrt(rf_forward_fut_var_sharpe)
gen five_year_sd = sqrt(five_year_var)

gen sharpe = rf_fut_ret_sharpe/rf_fut_sd_sharpe if date == 684
replace sharpe = rf_forward_fut_ret_sharpe/rf_forward_fut_sd_sharpe if date == 672
gen sharpe_fiveyear = annized_five_yr_ret/five_year_sd if date == 672 | date == 684
}

{ // create flag for pre-reform
gen pre = 1 if date < 684  //Date 684 is when reforms when into effect (Jan 2017).  
assert date != .
replace pre = 0 if pre == .
}

{ // save intermediate dataset
save "$temp/collapse_nosmart_1.dta", replace
}

{ // try to find the underlying funds for the upward linear in Jan 2017 returns and generate variables

// reload original data for merge
if "`var'" == "full_data" {
	use "$temp/full_data.dta", clear
}
else {
	use "$temp/`var'_fulldata.dta", clear
}

// merge in total assets & gender
merge m:1 ScrubbedID date using "$temp/asset_list"
assert _m != 1
keep if _m == 3
drop _m
gen FundsHeld = round(total_assets * port_weight, .01)

// find common funds held with Vanguard total stock index
bys ScrubbedID date: gen temp = (Fund == "OVF7-VANG TOT STK MKT IP")
bys ScrubbedID date: egen ovf7_dummy = max(temp)
drop temp

//future ret and future var, are the ex post 12 month performance
gen future_ret = (1+future_monthly_return)^12-1
gen future_var = (sqrt(12)*future_monthly_sd)^2


// generate variable for share in TDFs pre and post reform
gen tdf16 = port_weight if is_target_date == 1 & date == 672
replace tdf16 = 0 if missing(tdf16)
bys ScrubbedID: egen share_tdf16 = total(tdf16)
drop tdf16

gen tdf17 = port_weight if is_target_date == 1 & date == 684
replace tdf17 = 0 if missing(tdf17)
bys ScrubbedID: egen share_tdf17 = total(tdf17)
drop tdf17

gen delta_tdfshare = share_tdf17 - share_tdf16

} 

{ // generate total share held in different funds
gen share_2080fidck_temp = FundsHeld/total_assets if Fund == "2080-FID CONTRAFUND K"
replace share_2080fidck_temp = 0 if share_2080fidck_temp == .
bys ScrubbedID date: egen share_2080fidck = max(share_2080fidck_temp)
drop share_2080fidck_temp

gen share_ovf7_temp = FundsHeld/total_assets if Fund == "OVF7-VANG TOT STK MKT IP"
replace share_ovf7_temp = 0 if share_ovf7_temp == .
bys ScrubbedID date: egen share_ovf7 = max(share_ovf7_temp)
drop share_ovf7_temp

gen share_vanbond_temp = FundsHeld/total_assets if Fund == "OQFC-VANG TOT BD MKT INST"
replace share_vanbond_temp = 0 if share_vanbond_temp == .
bys ScrubbedID date: egen share_vanbond = max(share_vanbond_temp)
drop share_vanbond_temp

gen share_vandev_temp = FundsHeld/total_assets if Fund == "OVBQ-VANG DEV MKT IDX IS"
replace share_vandev_temp = 0 if share_vandev_temp == .
bys ScrubbedID date: egen share_vandev = max(share_vandev_temp)
drop share_vandev_temp

gen share_vanmmkt_temp = FundsHeld/total_assets if Fund == "OQQL-VANG VMMR-FED MMKT"
replace share_vanmmkt_temp = 0 if share_vanmmkt_temp == .
bys ScrubbedID date: egen share_vanmmkt = max(share_vanmmkt_temp)
drop share_vanmmkt_temp

gen share_vansm_temp = FundsHeld/total_assets if Fund == "OMZE-VANG SM CAP IDX INST"
replace share_vansm_temp = 0 if share_vansm_temp == .
bys ScrubbedID date: egen share_vansm = max(share_vansm_temp)
drop share_vansm_temp

gen share_vanprime_temp = FundsHeld/total_assets if Fund == "OQNI-VANG PRIMECAP ADM"
replace share_vanprime_temp = 0 if share_vanprime_temp == .
bys ScrubbedID date: egen share_vanprime = max(share_vanprime_temp)
drop share_vanprime_temp

gen share_vanmid_temp = FundsHeld/total_assets if Fund == "OMRJ-VANG MIDCAP IDX INST"
replace share_vanmid_temp = 0 if share_vanmid_temp == .
bys ScrubbedID date: egen share_vanmid = max(share_vanmid_temp)
drop share_vanmid_temp
}

{ // merge share of holdings in these funds to the collapsed file
bys ScrubbedID date: keep if _n == 1
keep ScrubbedID date share_* delta_tdfshare total_assets Gender RoundedSalary MaritialStatus

tempfile temp2
save "`temp2'"

use "$temp/collapse_nosmart_1.dta"
merge m:1 ScrubbedID date using "`temp2'"
drop if _m == 2
assert _m == 3
drop _m
}

{ // generate variables for graph linearities
gen share_comb1 = share_ovf7 + share_2080fidck
gen share_comb2 = share_ovf7 + share_vansm 
gen share_comb3 = share_ovf7 + share_vanprime 
gen share_comb4 = share_ovf7 + share_vanmid 
gen total_tdf_share = fid_tdf_share + van_tdf_share


gen temp = (date == 672 & goldbug == 1)
bys ScrubbedID: egen goldbug16 = max(temp)
drop temp

gen temp = (date == 672 & one_sector_overweight == 1)
bys ScrubbedID: egen onesector16 = max(temp)
drop temp


gen temp = (date == 672 & total_mm_overweight == 1)
bys ScrubbedID: egen overmm16 = max(temp)
drop temp


la define date 672 "Pre-Reform" ///
684 "Post-Reform"
la val date date

replace total_assets = round(total_assets)
replace exp_ratio = 100*exp_ratio

gen domestic_equity_share = equities - intl_equity_share

cap drop return_used
cap drop var_used
gen return_used = future_ret if date == 684
replace return_used = forward_future_ret if date == 672
gen var_used = future_var if date == 684
replace var_used = forward_future_var if date == 672
}

{ // merge in data on 2016 guardrails flags
foreach var2 in goldbug total_eq_under total_eq_over total_eq_violation total_exp_over total_exp_over_50 total_exp_over_100 total_intl_share_under total_mm_overweight total_sector_overweight one_sector_overweight AgeasofNov2018 {
	cap drop `var2'
}
merge m:1 ScrubbedID using "$temp/guardrails flags"
drop if _m == 2
assert _m == 3 
drop _m
gen any_guardrail = (total_eq_violation == 1 | total_exp_over == 1 | total_intl_share_under == 1 | one_sector_overweight == 1)
gen guardrail_not_intl = (total_eq_violation == 1 | total_exp_over == 1 | one_sector_overweight == 1)
gen guardrail_div = (total_intl_share_under == 1 | one_sector_overweight == 1)
summ total_eq_violation total_exp_over total_intl_share_under one_sector_overweight any_guardrail
la define yes_no 0 "No" 1 "Yes"
la val guardrail_div total_eq_violation guardrail_not_intl total_exp_over total_intl_share_under one_sector_overweight any_guardrail yes_no
la var total_eq_violation "Equities Share Less Than Half or More Than Double Benchmark TDF"
local basis = round($exp_ratio_cap * 10000)
la var total_exp_over "Average Expense Ratio Over `basis' Basis Points"
la var total_exp_over_50 "Average Expense Ratio Over 50 Basis Points"
la var total_exp_over_100 "Average Expense Ratio Over 100 Basis Points"
la var total_intl_share_under "International Equities Less Than 20% Equities"
la var one_sector_overweight "Single Sector Fund Overweighted"
la var any_guardrail "Any Guardrail"
la var guardrail_not_intl "Any Non-International Error"
la var guardrail_div "Any Diversification Error"

}		

{ // merge in ex ante returns (Created in Quinn's setup.do. NOTE: A great many do not merge.)

preserve 
	if "`var'" == "full_data" {
		use "$temp/investor_mean_var_cleaning_step_one.dta", clear
	}
	else {
		use "$temp/investor_mean_var_`var'.dta", clear
	}
	rename ret ante_ret
	rename var ante_var
	gen ante_sd = sqrt(ante_var)
	duplicates drop
	save "$temp/ex_ante_returns", replace
restore

merge 1:1 ScrubbedID date using "$temp/ex_ante_returns"
assert _m != 1 if inlist(date, 672,684)
keep if _m != 2
assert _m == 3
drop _m


// annualize returns and variance?
replace ante_ret = (1+ante_ret)^12-1
replace ante_var = (sqrt(12)*ante_sd)^2



}

{ // filter out flagged individuals with all prior holdings in a TDF or in funds held over betweeen years

if "`var'" == "full_data" {
	save "$temp/collapse2.dta", replace
} 
else {
	save "$temp/collapse2_`var'.dta", replace
}

if "`var'" == "full_data" {
	bys ScrubbedID: gen temp = _n
	count if ((smart == 1 | steady_pre == 1) & temp == 1) 
	local totaldrop = r(N)
	count if ((smart == 0 & steady_pre == 0) & temp == 1) 
	local totalremain = r(N)
	count if smart == 1 & temp == 1
	local smartdrop = r(N)
	count if steady_pre == 1 & temp == 1
	local steadydrop = r(N)
	putexcel set "$output/37 - Dropped For Prior Smart Investments.xlsx", sheet("Dropped for Smart Investments") replace
	putexcel B1 = ("Count")
	putexcel A2 = ("Dropped for holding only TDFs")
	putexcel B2 = (`smartdrop')
	putexcel A3 = ("Dropped for holding only funds kept in plan post-reform")
	putexcel B3 = (`steadydrop')
	putexcel A4 = ("Dropped for either condition")
	putexcel B4 = (`totaldrop')
	putexcel A5 = ("Total Remaining")
	putexcel B5 = (`totalremain')
	putexcel close
	drop temp
}


drop if smart == 1
drop if steady_pre == 1
drop smart
}

{ // save data
if "`var'" == "full_data" {
	save "$temp/collapse_nosmart.dta", replace
}
else {
	save "$temp/`var'_collapse_nosmart.dta", replace
}

}
}

{ // create combined datasets
use "$temp/guard_intrm_onlytdf_joint_all_collapse_nosmart.dta", clear
keep if date == 672
replace date = 990
keep ScrubbedID date return_used var_used goldbug16 onesector16 overmm16 ///
exp_ratio total_assets intl_equity beta dominated_simple cash_bonds equities oth_investments ///
_b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse _R2 sharpe sharpe_fiveyear annized_five_yr_ret five_year_var annized_five_yr_ret five_year_var n_funds ante* total_tdf_share five_years_flag
tempfile guardrail1
save "`guardrail1'"

use "$temp/guard_intrm_onlytdf_joint_nonintl_collapse_nosmart.dta", clear
keep if date == 672
replace date = 991
keep ScrubbedID date return_used var_used goldbug16 onesector16 overmm16 ///
exp_ratio total_assets intl_equity beta dominated_simple cash_bonds equities oth_investments ///
_b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse _R2 sharpe sharpe_fiveyear annized_five_yr_ret five_year_var n_funds ante_* total_tdf_share five_years_flag 
tempfile guardrail2
save "`guardrail2'"

use "$temp/guard_intrm_onlytdf_intl_collapse_nosmart.dta", clear
keep if date == 672
replace date = 992
keep ScrubbedID date return_used var_used goldbug16 onesector16 overmm16 ///
exp_ratio total_assets intl_equity beta dominated_simple cash_bonds equities oth_investments ///
_b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse _R2 sharpe sharpe_fiveyear annized_five_yr_ret five_year_var n_funds ante_* total_tdf_share five_years_flag 
tempfile guardrail3
save "`guardrail3'"

use "$temp/guard_intrm_onlytdf_equitiesover_collapse_nosmart.dta", clear
keep if date == 672
replace date = 993
keep ScrubbedID date return_used var_used goldbug16 onesector16 overmm16 ///
exp_ratio total_assets intl_equity beta dominated_simple cash_bonds equities oth_investments ///
_b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse _R2 sharpe sharpe_fiveyear annized_five_yr_ret five_year_var n_funds ante_* total_tdf_share five_years_flag 
tempfile guardrail4
save "`guardrail4'"

use "$temp/guard_intrm_onlytdf_equitiesunder_collapse_nosmart.dta", clear
keep if date == 672
replace date = 994
keep ScrubbedID date return_used var_used goldbug16 onesector16 overmm16 ///
exp_ratio total_assets intl_equity beta dominated_simple cash_bonds equities oth_investments ///
_b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse _R2 sharpe sharpe_fiveyear annized_five_yr_ret five_year_var n_funds ante_* total_tdf_share five_years_flag 
tempfile guardrail5
save "`guardrail5'"

use "$temp/guard_intrm_onlytdf_sector_collapse_nosmart.dta", clear
keep if date == 672
replace date = 995
keep ScrubbedID date return_used var_used goldbug16 onesector16 overmm16 ///
exp_ratio total_assets intl_equity beta dominated_simple cash_bonds equities oth_investments ///
_b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse _R2 sharpe sharpe_fiveyear annized_five_yr_ret five_year_var n_funds ante_* total_tdf_share five_years_flag
tempfile guardrail6
save "`guardrail6'"

use "$temp/guard_intrm_onlytdf_expenseratio_collapse_nosmart.dta", clear
keep if date == 672
replace date = 996
keep ScrubbedID date return_used var_used goldbug16 onesector16 overmm16 ///
exp_ratio total_assets intl_equity beta dominated_simple cash_bonds equities oth_investments ///
_b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse _R2 sharpe sharpe_fiveyear annized_five_yr_ret five_year_var n_funds ante_* total_tdf_share five_years_flag


append using "`guardrail1'"
append using "`guardrail2'"
append using "`guardrail3'"
append using "`guardrail4'"
append using "`guardrail5'"
append using "`guardrail6'"
append using "$temp/collapse_nosmart.dta"

foreach var in any_guardrail guardrail_not_intl one_sector_overweight total_exp_over total_eq_under total_eq_over total_intl_share_under steady_pre {
	bys ScrubbedID: egen `var'2 = max(`var')
	replace `var' = `var'2
	drop `var'2

}


la drop date 
la define date 672 "Pre-Reform" ///
684 "Post-Reform" ///
990 "Joint Guardrails to TDF, All" ///
991 "Joint Guardrails to TDF, No Intl" ///
992 "International Share of Equities Guardrail to TDF" ///
993 "Maximum Equities Guardrail to TDF" ///
994 "Minimum Equities Guardrail to TDF" ///
995 "Sector Fund Guardrail to TDF" ///
996 "Expense Ratio Guardrail to TDF" 
la val date date
tab date

gen temp = (date == 696)
bys ScrubbedID: egen present_2018 = max(temp)
drop temp

save "$temp/collapse_nosmart_combined", replace





// create combined file not filtering out smart & steady_pre
use "$temp/collapse2_guard_intrm_onlytdf_joint_all.dta", clear
keep if date == 672
replace date = 990
keep ScrubbedID date return_used var_used goldbug16 onesector16 overmm16 ///
exp_ratio total_assets intl_equity beta dominated_simple cash_bonds equities oth_investments ///
_b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse _R2 sharpe sharpe_fiveyear annized_five_yr_ret five_year_var n_funds ante* total_tdf_share five_years_flag
tempfile guardrail1
save "`guardrail1'"

use "$temp/collapse2_guard_intrm_onlytdf_joint_nonintl.dta", clear
keep if date == 672
replace date = 991
keep ScrubbedID date return_used var_used goldbug16 onesector16 overmm16 ///
exp_ratio total_assets intl_equity beta dominated_simple cash_bonds equities oth_investments ///
_b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse _R2 sharpe sharpe_fiveyear annized_five_yr_ret five_year_var n_funds ante_* total_tdf_share five_years_flag
tempfile guardrail2
save "`guardrail2'"

use "$temp/collapse2_guard_intrm_onlytdf_intl.dta", clear
keep if date == 672
replace date = 992
keep ScrubbedID date return_used var_used goldbug16 onesector16 overmm16 ///
exp_ratio total_assets intl_equity beta dominated_simple cash_bonds equities oth_investments ///
_b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse _R2 sharpe sharpe_fiveyear annized_five_yr_ret five_year_var n_funds ante_* total_tdf_share five_years_flag
tempfile guardrail3
save "`guardrail3'"

use "$temp/collapse2_guard_intrm_onlytdf_equitiesover.dta", clear
keep if date == 672
replace date = 993
keep ScrubbedID date return_used var_used goldbug16 onesector16 overmm16 ///
exp_ratio total_assets intl_equity beta dominated_simple cash_bonds equities oth_investments ///
_b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse _R2 sharpe sharpe_fiveyear annized_five_yr_ret five_year_var n_funds ante_* total_tdf_share five_years_flag
tempfile guardrail4
save "`guardrail4'"

use "$temp/collapse2_guard_intrm_onlytdf_equitiesunder.dta", clear
keep if date == 672
replace date = 994
keep ScrubbedID date return_used var_used goldbug16 onesector16 overmm16 ///
exp_ratio total_assets intl_equity beta dominated_simple cash_bonds equities oth_investments ///
_b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse _R2 sharpe sharpe_fiveyear annized_five_yr_ret five_year_var n_funds ante_* total_tdf_share five_years_flag
tempfile guardrail5
save "`guardrail5'"

use "$temp/collapse2_guard_intrm_onlytdf_sector.dta", clear
keep if date == 672
replace date = 995
keep ScrubbedID date return_used var_used goldbug16 onesector16 overmm16 ///
exp_ratio total_assets intl_equity beta dominated_simple cash_bonds equities oth_investments ///
_b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse _R2 sharpe sharpe_fiveyear annized_five_yr_ret five_year_var n_funds ante_* total_tdf_share five_years_flag
tempfile guardrail6
save "`guardrail6'"

use "$temp/collapse2_guard_intrm_onlytdf_expenseratio.dta", clear
keep if date == 672
replace date = 996
keep ScrubbedID date return_used var_used goldbug16 onesector16 overmm16 ///
exp_ratio total_assets intl_equity beta dominated_simple cash_bonds equities oth_investments ///
_b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse _R2 sharpe sharpe_fiveyear annized_five_yr_ret five_year_var n_funds ante_* total_tdf_share five_years_flag


append using "`guardrail1'"
append using "`guardrail2'"
append using "`guardrail3'"
append using "`guardrail4'"
append using "`guardrail5'"
append using "`guardrail6'"
append using "$temp/collapse2.dta"

foreach var in any_guardrail guardrail_not_intl one_sector_overweight total_exp_over total_eq_under total_eq_over total_intl_share_under steady_pre {
	bys ScrubbedID: egen `var'2 = max(`var')
	replace `var' = `var'2
	drop `var'2

}

la drop date 
la define date 672 "Pre-Reform" ///
684 "Post-Reform" ///
990 "Joint Guardrails to TDF, All" ///
991 "Joint Guardrails to TDF, No Intl" ///
992 "International Share of Equities Guardrail to TDF" ///
993 "Maximum Equities Guardrail to TDF" ///
994 "Minimum Equities Guardrail to TDF" ///
995 "Sector Fund Guardrail to TDF" ///
996 "Expense Ratio Guardrail to TDF" 
la val date date
tab date

gen temp = (date == 696)
bys ScrubbedID: egen present_2018 = max(temp)
drop temp

bys ScrubbedID: egen temp = max(smart)
replace smart = temp
drop temp

save "$temp/collapse2_combined", replace

}

{ // calculate share affected by guardrails -- excluding smart/steady investors

use "$temp/collapse_nosmart_combined", clear

twoway (hist domestic_equity_share if date == 672, start(0) w(.05) color("$color_p2%50")) /// 
(hist domestic_equity_share if date == 684, start(0) w(.05) color("$color_p3%50")) ///
, legend(label(1 "Pre-Reform") label(2 "Post-Reform"))
bys date: summ domestic_equity_share, d

keep if inlist(date, 672)
drop total_eq_violation total_exp_over total_intl_share_under ///
one_sector_overweight guardrail_div guardrail_not_intl any_guardrail 

merge m:1 ScrubbedID date using "$temp/guardrail each date flags"
drop if _m == 2
assert _m == 3 
drop _m
gen any_guardrail = (total_eq_violation == 1 | total_exp_over == 1 | total_intl_share_under == 1 | one_sector_overweight == 1)
gen guardrail_not_intl = (total_eq_violation == 1 | one_sector_overweight == 1 | total_exp_over == 1)
gen guardrail_div = (total_intl_share_under == 1 | one_sector_overweight == 1)
summ total_eq_violation total_exp_over total_intl_share_under one_sector_overweight any_guardrail
cap la drop yes_no
la define yes_no 0 "No" 1 "Yes"
la val total_exp_over_100 total_exp_over_50 guardrail_div total_eq_violation guardrail_not_intl total_exp_over total_intl_share_under one_sector_overweight any_guardrail yes_no
la var total_eq_violation "Equities Share Less Than Half or More Than Double Benchmark TDF"
local basis = round($exp_ratio_cap * 10000)
la var total_exp_over "Average Expense Ratio Over `basis' Basis Points"
la var total_exp_over_50 "Average Expense Ratio Over 50 Basis Points"
la var total_exp_over_100 "Average Expense Ratio Over 100 Basis Points"
la var total_intl_share_under "International Equities Less Than 20% Equities"
la var one_sector_overweight "Single Sector Fund Overweighted"
la var any_guardrail "Any Guardrail"
la var guardrail_not_intl "Any Non-International Error"
la var guardrail_div "Any Diversification Error"
	
tabout total_eq_violation total_exp_over_50 total_exp_over total_exp_over_100 total_intl_share_under one_sector_overweight ///
guardrail_div guardrail_not_intl any_guardrail date ///
using "$temp/38 - Affected By Guardrails.txt", replace c(freq col) format(0 1) ptotal(single)
import delimited "$temp/38 - Affected By Guardrails.txt", clear varnames(nonames)
drop if _n == 1
preserve
	gen row = _n
	forvalues i = 1/5 {
		rename v`i' v`i'_nosmart
	}
	save "$temp/nosmart_affected_table", replace
restore
forvalues i = 2/5 {
	replace v`i' = v`i'[_n+2] if _n > 2 & _n != _N
}
drop if inlist(v1,"No","Yes")
drop v4 v5

export excel "$output/38 - Affected By Guardrails.xlsx", sheet("Without TDF or Non-Streamlined") replace
putexcel set "$output/38 - Affected By Guardrails.xlsx", sheet("Without TDF or Non-Streamlined") modify
putexcel B1:C1, merge hcenter
putexcel A20 = "In our analysis, we implement the 75 basis point expense ratio guardrail. The rows for Any Guardrail and Any Non-International Guardrail do not include the 50 basis point guardrail."
putexcel close


}

{ // calculate share affected by guardrails -- including smart/steady investors

use "$temp/collapse2_combined", clear

twoway (hist domestic_equity_share if date == 672, start(0) w(.05) color("$color_p2%50")) /// 
(hist domestic_equity_share if date == 684, start(0) w(.05) color("$color_p3%50")) ///
, legend(label(1 "Pre-Reform") label(2 "Post-Reform"))
bys date: summ domestic_equity_share, d

keep if inlist(date, 672)
drop total_eq_violation total_exp_over total_intl_share_under ///
one_sector_overweight guardrail_div guardrail_not_intl any_guardrail 

merge m:1 ScrubbedID date using "$temp/guardrail each date flags"
drop if _m == 2
assert _m == 3 
drop _m
gen any_guardrail = (total_eq_violation == 1 | total_exp_over == 1 | total_intl_share_under == 1 | one_sector_overweight == 1)
gen guardrail_not_intl = (total_eq_violation == 1 | one_sector_overweight == 1 | total_exp_over == 1)
gen guardrail_div = (total_intl_share_under == 1 | one_sector_overweight == 1)
summ total_eq_violation total_exp_over total_intl_share_under one_sector_overweight any_guardrail
cap la drop yes_no
la define yes_no 0 "No" 1 "Yes"
la val total_exp_over_100 total_exp_over_50 guardrail_div total_eq_violation guardrail_not_intl total_exp_over total_intl_share_under one_sector_overweight any_guardrail yes_no
la var total_eq_violation "Equities Share Less Than Half or More Than Double Benchmark TDF"
local basis = round($exp_ratio_cap * 10000)
la var total_exp_over "Average Expense Ratio Over `basis' Basis Points"
la var total_exp_over_50 "Average Expense Ratio Over 50 Basis Points"
la var total_exp_over_100 "Average Expense Ratio Over 100 Basis Points"
la var total_intl_share_under "International Equities Less Than 20% Equities"
la var one_sector_overweight "Single Sector Fund Overweighted"
la var any_guardrail "Any Guardrail"
la var guardrail_not_intl "Any Non-International Error"
la var guardrail_div "Any Diversification Error"
	
tabout total_eq_violation total_exp_over_50 total_exp_over total_exp_over_100 total_intl_share_under one_sector_overweight ///
guardrail_div guardrail_not_intl any_guardrail date ///
using "$temp/38 - Affected By Guardrails.txt", replace c(freq col) format(0 1) ptotal(single)
import delimited "$temp/38 - Affected By Guardrails.txt", clear varnames(nonames)
drop if _n == 1
gen row = _n
merge 1:1 row using "$temp/nosmart_affected_table"
assert _m == 3
drop _m 
assert v1_nosmart == v1

forvalues i = 2/5 {
	replace v`i' = v`i'[_n+2] if _n > 2 & _n != _N
	replace v`i'_nosmart = v`i'_nosmart[_n+2] if _n > 2 & _n != _N
}
drop if inlist(v1,"No","Yes")
drop v4* v5* v1_nosmart row

export excel "$output/38 - Affected By Guardrails.xlsx", sheet("With TDF and Non-Streamlined") 
putexcel set "$output/38 - Affected By Guardrails.xlsx", sheet("With TDF and Non-Streamlined") modify
putexcel B1:C1, merge hcenter
putexcel D1:E1, merge hcenter
putexcel B1 = ("All Investors")
putexcel D1 = ("Excluding Investors With All Assets in One TDF")
putexcel B2 = ("N")
putexcel D2 = ("N")
putexcel A17 = "In our analysis, we implement the 75 basis point expense ratio guardrail. The rows for Any Guardrail and Any Non-International Guardrail do not include the 50 basis point guardrail."
putexcel close


}





