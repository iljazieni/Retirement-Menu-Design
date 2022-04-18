***** Streamlining Diff-in-diff type analysis ******

use "$temp\individual_ports.dta", replace

keep if inlist(date, 684)

** Drop affirmative choice portfolios

merge m:1 ScrubbedID using "$temp/id_affirm_crosswalk"
//drop if affirmative17 == 1
drop _m

** Merge in fund level shares 

merge m:1 crsp_fundno date using "$temp/cashbond"

keep if _m == 3
drop _m

//egen total_assets = sum(MarketValue)
//gen port_weight = MarketValue/ total_assets 

** Bring in Fund Shares  

joinby Fund date using "$temp/fund_returns_series_crosswalk_post.dta"

sort Scr Fund 

egen port = sum(port_weight), by(Scr)
assert port == 1 | port < 1.01

** 

merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m 
drop if missing(date)

/*
// save list of missing expense ratios
preserve
	keep if missing(exp_ratio)
	keep if inlist(date, 672, 684, 696)
	bys Fund crsp_fundno: keep if _n == 1
	keep Fund crsp_fundno
	export excel "$temp/missing expense ratios.xlsx", replace firstrow(variables)
	// manually found expense ratios (as of Dec. 2019) for these funds
restore
*/
// import and merge in additional expense ratio data

cap drop _m
merge m:1 crsp_fundno using "$temp/missing expense ratio data"
drop if _m == 2
replace exp_ratio = exp_ratio2 if missing(exp_ratio)
//assert !missing(exp_ratio) if inlist(date, 672, 684, 696)
drop _m exp_ratio2

cap drop _m
merge m:1 crsp_fundno using "$temp/missing equities data"
drop if _m == 2
replace equities = equities2 if missing(equities)
assert !missing(equities) if inlist(date, 672, 684, 696)
drop _m equities2

// merge in data on sector funds

merge m:1 Fund using "$temp/sectorfunds"
drop if _m == 2
assert _m == 3 if inlist(date, 672, 684)
drop _m
replace intl_share_of_equities = .3 if date < 672 & (inlist(Fund, "OV6M-VANG INST TR INCOME", "OV6N-VANG INST TR 2010", "OV6O-VANG INST TR 2015","OV6P-VANG INST TR 2020","OV6Q-VANG INST TR 2025") ///
| inlist(Fund, "OV6R-VANG INST TR 2030","OV6S-VANG INST TR 2035", "OV6T-VANG INST TR 2040", "OV6U-VANG INST TR 2045","OV6V-VANG INST TR 2050","OV6W-VANG INST TR 2055","OV6X-VANG INST TR 2060") ///
| inlist(Fund, "OSHO-VANG TARGET RET INC", "OKKK-VANG TARGET RET 2010",  "OSHQ-VANG TARGET RET 2015", "OKKL-VANG TARGET RET 2020", "OSHR-VANG TARGET RET 2025") ///
| inlist(Fund, "OKKM-VANG TARGET RET 2030", "OSHS-VANG TARGET RET 2035", "OKKN-VANG TARGET RET 2040", "OSHT-VANG TARGET RET 2045", "OKKO-VANG TARGET RET 2050", "OEKG-VANG TARGET RET 2055"))

replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0

gen intl_equity_share = intl_share_of_equities*equities
// define international equities as equity funds that are > 50% international
gen intl_equity_fund = (equity == 1 & intl_share_of_equities > .5)

// determine correct TDF and benchmark level of domestic equities & international equities
gen retirement_target = round(2018 - AgeasofNov2018 + 65, 5)
replace retirement_target = 2055 if retirement_target > 2055 & retirement_target != . & date > 684
replace retirement_target = 2060 if retirement_target > 2060 & retirement_target != . & date <= 684

gen age_TDF = ""
gen crsp_fundno_age_TDF = .
// TDFs for later years
replace crsp_fundno_age_TDF  = 31290 if retirement_target <= 2010 & date <= 684
replace age_TDF = "OSHO-VANG TARGET RET INC" if retirement_target <= 2010 & date <= 684
replace crsp_fundno_age_TDF  = 31292 if retirement_target == 2015 & date <= 684
replace age_TDF = "OSHQ-VANG TARGET RET 2015" if retirement_target == 2015 & date <= 684
replace crsp_fundno_age_TDF  = 31297 if retirement_target == 2020 & date <= 684
replace age_TDF = "OKKL-VANG TARGET RET 2020" if retirement_target == 2020 & date == 684
replace crsp_fundno_age_TDF  = 31293 if retirement_target == 2025 & date <= 684
replace age_TDF = "OSHR-VANG TARGET RET 2025" if retirement_target == 2025 & date <= 684
replace crsp_fundno_age_TDF  = 31300 if retirement_target == 2030 & date <= 684
replace age_TDF = "OKKM-VANG TARGET RET 2030" if retirement_target == 2030 & date <= 684
replace crsp_fundno_age_TDF  = 31294 if retirement_target == 2035 & date <= 684
replace age_TDF = "OSHS-VANG TARGET RET 2035" if retirement_target == 2035 & date <= 684
replace crsp_fundno_age_TDF  = 31299 if retirement_target == 2040 & date <= 684
replace age_TDF = "OKKN-VANG TARGET RET 2040" if retirement_target == 2040 & date <= 684
replace crsp_fundno_age_TDF  = 31295 if retirement_target == 2045 & date <= 684
replace age_TDF = "OSHT-VANG TARGET RET 2045" if retirement_target == 2045 & date <= 684
replace crsp_fundno_age_TDF  = 31298 if retirement_target == 2050 & date <= 684
replace age_TDF = "OKKO-VANG TARGET RET 2050" if retirement_target == 2050 & date <= 684
replace crsp_fundno_age_TDF  = 50154 if retirement_target >= 2055 & retirement_target < . & date <= 684
replace age_TDF = "OEKG-VANG TARGET RET 2055" if retirement_target >= 2055 & retirement_target < . & date <= 684

// TDFs for earlier years
replace crsp_fundno_age_TDF  = 31290 if retirement_target <= 2010 & date > 684
replace age_TDF = "OV6M-VANG INST TR INCOME" if retirement_target <= 2010 & date > 684
replace crsp_fundno_age_TDF  = 31292 if retirement_target == 2015 & date > 684
replace age_TDF = "OV6O-VANG INST TR 2015" if retirement_target == 2015 & date > 684
replace crsp_fundno_age_TDF  = 31297 if retirement_target == 2020 & date > 684
replace age_TDF = "OV6P-VANG INST TR 2020" if retirement_target == 2020 & date > 684
replace crsp_fundno_age_TDF  = 31293 if retirement_target == 2025 & date > 684
replace age_TDF = "OV6Q-VANG INST TR 2025" if retirement_target == 2025 & date > 684
replace crsp_fundno_age_TDF  = 31300 if retirement_target == 2030 & date > 684
replace age_TDF = "OV6R-VANG INST TR 2030" if retirement_target == 2030 & date > 684
replace crsp_fundno_age_TDF  = 31294 if retirement_target == 2035 & date > 684
replace age_TDF = "OV6S-VANG INST TR 2035" if retirement_target == 2035 & date > 684
replace crsp_fundno_age_TDF  = 31299 if retirement_target == 2040 & date > 684
replace age_TDF = "OV6T-VANG INST TR 2040" if retirement_target == 2040 & date > 684
replace crsp_fundno_age_TDF  = 31295 if retirement_target == 2045 & date > 684
replace age_TDF = "OV6U-VANG INST TR 2045" if retirement_target == 2045 & date > 684
replace crsp_fundno_age_TDF  = 31298 if retirement_target == 2050 & date > 684
replace age_TDF = "OV6V-VANG INST TR 2050" if retirement_target == 2050 & date > 684
replace crsp_fundno_age_TDF  = 50154 if retirement_target == 2055 & date > 684
replace age_TDF = "OV6W-VANG INST TR 2055" if retirement_target == 2055 & date > 684
replace crsp_fundno_age_TDF  = 54310 if retirement_target >= 2060 & retirement_target < . & date > 684
replace age_TDF = "OV6X-VANG INST TR 2060" if retirement_target >= 2060 & retirement_target < . & date > 684

// merge in crsp data for TDFs (add in the missing data for future merges)

merge m:1 date crsp_fundno_age_TDF using "$temp/cashbond_tdf"
drop if _m == 2
assert _m != 1 if date == 684
drop _m

// merge in international share of equities
merge m:1 age_TDF using "$temp/tdf_sectorfunds"
drop if _m == 2
assert _m == 3 if inlist(date, 672,684,696)
drop _m
replace tdf_intl_share = .3 if date < 672 & (inlist(age_TDF, "OV6M-VANG INST TR INCOME", "OV6N-VANG INST TR 2010", "OV6O-VANG INST TR 2015","OV6P-VANG INST TR 2020","OV6Q-VANG INST TR 2025") ///
| inlist(age_TDF, "OV6R-VANG INST TR 2030","OV6S-VANG INST TR 2035", "OV6T-VANG INST TR 2040", "OV6U-VANG INST TR 2045","OV6V-VANG INST TR 2050","OV6W-VANG INST TR 2055","OV6X-VANG INST TR 2060") ///
| inlist(age_TDF, "OSHO-VANG TARGET RET INC", "OKKK-VANG TARGET RET 2010",  "OSHQ-VANG TARGET RET 2015", "OKKL-VANG TARGET RET 2020", "OSHR-VANG TARGET RET 2025") ///
| inlist(age_TDF, "OKKM-VANG TARGET RET 2030", "OSHS-VANG TARGET RET 2035", "OKKN-VANG TARGET RET 2040", "OSHT-VANG TARGET RET 2045", "OKKO-VANG TARGET RET 2050", "OEKG-VANG TARGET RET 2055"))
gen tdf_intl_eq_share = tdf_intl_share * tdf_equities
gen tdf_dom_eq_share = tdf_equities - tdf_intl_eq_share
assert date != 672 if (tdf_intl_eq_share == . | tdf_dom_eq_share == .)

** Guardrails on hypothetical fund 

// individual sector funds
gen temp = (gold > $ind_gold_lev & gold < .)
egen goldbug = max(temp)
drop temp
gen temp = (sector > $ind_sec_lev & sector < .)
egen one_sector_overweight = max(temp)
drop temp

// total sector funds cap
egen total_sector_temp = total(sector)
gen total_sector_overweight = (total_sector_temp > $tot_sec_lev & sector < .)

// total money market funds cap
egen total_mm_temp = total(money_market)
gen total_mm_overweight = (total_mm_temp > $tot_mm_lev & total_mm_temp < .)

// total international share of equities minimum
gen intl_weight = equities * port_weight
egen total_intl_share_temp = wtmean(intl_share_of_equities), weight(intl_weight)
gen total_intl_share_under = (total_intl_share_temp < $intl_eq_perc)
drop intl_share_of_equities

// total expense ratio cap
egen total_exp_temp = wtmean(exp_ratio), weight(port_weight)
gen total_exp_over = (total_exp_temp > $exp_ratio_cap & total_exp_temp < .)
gen total_exp_over_50 = (total_exp_temp > .0050 & total_exp_temp < .)
gen total_exp_over_100 = (total_exp_temp > .0100 & total_exp_temp < .)

// minimum half of glide path for equities, max double
egen tot_eq = wtmean(equities), weight(port_weight)
gen total_eq_under = (tot_eq < (tdf_equities / 2))
gen total_eq_over = (tot_eq > (tdf_equities * 2) & tot_eq < .)
gen total_eq_violation = (total_eq_under == 1 | total_eq_over == 1)

** No violations found ** 

la var age "Age"
la var age_TDF "Fund"
la var tdf_cash_share "% Cash"
la var tdf_bond_share "% Bonds"
la var tdf_cash_bonds "% Cash & Bonds"
la var tdf_intl_eq_share "% International Equities"
la var tdf_dom_eq_share "% Domestic Equities"
la var tdf_equities "% Equities"

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

gen helper = 1 
egen n_funds = sum(helper), by(Scr date)

collapse (firstnm) n_fund total_exp_over total_intl_share_under one_sector_overweight guardrail_div guardrail_not_intl any_guardrail total_eq_under total_eq_over total_eq_violation affirmative17 defaulted17 non17 total_assets ///
	RoundedSalary Gender AgeasofNov2018, by(Scr date)

save "$temp/2017_guardrails", replace

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

keep Scr date n_fund any_guardrail guardrail_not_intl guardrail_div total_exp_over total_exp_over_50 total_exp_over_100

sort Scr date

gen post = cond(date == 684, 1, 0)

bys Scr: gen m = _n
egen both = max(m), by(Scr)
drop if both == 1

local vars = "n_funds total_exp_over any_guardrail guardrail_not_intl guardrail_div"

foreach var in `vars' {
	di "`var'"
	gen `var'_prepost = `var'[_n+1] - `var' if date == 672 & ScrubbedID == ScrubbedID[_n+1] 
	gen `var'_preguardrails = `var'[_n+2] - `var' if date == 672 & ScrubbedID == ScrubbedID[_n+2]
	//drop `var'
}
sort Scr date

local vars = "equities dominated_simple exp_ratio n_funds"

foreach var in `vars' {
	di "`var'"
	gen `var'_prepost = `var'[_n+1] - `var' if date == 672 & ScrubbedID == ScrubbedID[_n+1] 
	gen `var'_preguardrails = `var'[_n+2] - `var' if date == 672 & ScrubbedID == ScrubbedID[_n+2]
	//drop `var'
}
keep if date == 672