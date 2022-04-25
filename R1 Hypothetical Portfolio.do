*** Chapter 10: RMSE for aggregate portfolios *****

{ // setup
clear all

cap log close

global home "C:\Users\EI87\Dropbox (YLS)\Retirement Menu Design"

global input "$home/code/STATA -- ZS/Input"
global temp "$home/code/STATA -- ZS/Temp_ORP"
global code "$home/code/STATA -- ZS/Code PD"
global output "$home/code/STATA -- ZS/replication"
//global log "$home/code/STATA -- ZS/Log"

sysdir set PERSONAL "$code/ado"
//set scheme zrs, perm
set more off, perm

global color_p2 = "86 180 233"
global color_p3 = "230 159 0"
global color_p4 = "0 205 150"


graph set window fontface "Times New Roman"

//log using "$log/Analysis", replace

set maxvar 20000

}

{ // save individual port data

use "$temp\orp_plan_merged.dta", replace

gen date = mofd(CalendarDay)
format date %tm
joinby Fund date using "$temp/fund_returns_series_crosswalk_post.dta"
joinby date crsp_fundno using "$temp\menu_betas"

duplicates drop

egen total_assets = sum(MarketValue), by(ScrubbedID date)
gen port_weight = MarketValue/ total_assets

save "$temp\individual_ports.dta", replace

}

** Filter to 2016m1

keep if inlist(date, 672)

** Collapse to fund level

collapse (sum) MarketValue, by(Fund date crsp_fundno crsp_fundno_orig)

gen AgeasofNov2018 = 53

** Merge in fund level shares

merge m:1 crsp_fundno date using "$temp/cashbond"

keep if _m == 3
drop _m

egen total_assets = sum(MarketValue)
gen port_weight = MarketValue/ total_assets

** Bring in Fund Shares

merge 1:m Fund using "$temp/fund_returns_series_crosswalk_post.dta"

drop if _m == 2
drop _m

duplicates drop Fund, force

egen port = sum(port_weight)
assert port == 1

**

merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
drop if missing(date)

// save list of missing expense ratios
preserve
	keep if missing(exp_ratio)
	keep if inlist(date, 672, 684, 696)
	bys Fund crsp_fundno: keep if _n == 1
	keep Fund crsp_fundno
	export excel "$temp/missing expense ratios.xlsx", replace firstrow(variables)
	// manually found expense ratios (as of Dec. 2019) for these funds
restore

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
replace retirement_target = 2055 if retirement_target > 2055 & retirement_target != . & date > 672
replace retirement_target = 2060 if retirement_target > 2060 & retirement_target != . & date <= 672

gen age_TDF = ""
gen crsp_fundno_age_TDF = .
// TDFs for later years
replace crsp_fundno_age_TDF  = 31290 if retirement_target <= 2010 & date <= 672
replace age_TDF = "OSHO-VANG TARGET RET INC" if retirement_target <= 2010 & date <= 672
replace crsp_fundno_age_TDF  = 31292 if retirement_target == 2015 & date <= 672
replace age_TDF = "OSHQ-VANG TARGET RET 2015" if retirement_target == 2015 & date <= 672
replace crsp_fundno_age_TDF  = 31297 if retirement_target == 2020 & date <= 672
replace age_TDF = "OKKL-VANG TARGET RET 2020" if retirement_target == 2020 & date == 672
replace crsp_fundno_age_TDF  = 31293 if retirement_target == 2025 & date <= 672
replace age_TDF = "OSHR-VANG TARGET RET 2025" if retirement_target == 2025 & date <= 672
replace crsp_fundno_age_TDF  = 31300 if retirement_target == 2030 & date <= 672
replace age_TDF = "OKKM-VANG TARGET RET 2030" if retirement_target == 2030 & date <= 672
replace crsp_fundno_age_TDF  = 31294 if retirement_target == 2035 & date <= 672
replace age_TDF = "OSHS-VANG TARGET RET 2035" if retirement_target == 2035 & date <= 672
replace crsp_fundno_age_TDF  = 31299 if retirement_target == 2040 & date <= 672
replace age_TDF = "OKKN-VANG TARGET RET 2040" if retirement_target == 2040 & date <= 672
replace crsp_fundno_age_TDF  = 31295 if retirement_target == 2045 & date <= 672
replace age_TDF = "OSHT-VANG TARGET RET 2045" if retirement_target == 2045 & date <= 672
replace crsp_fundno_age_TDF  = 31298 if retirement_target == 2050 & date <= 672
replace age_TDF = "OKKO-VANG TARGET RET 2050" if retirement_target == 2050 & date <= 672
replace crsp_fundno_age_TDF  = 50154 if retirement_target >= 2055 & retirement_target < . & date <= 672
replace age_TDF = "OEKG-VANG TARGET RET 2055" if retirement_target >= 2055 & retirement_target < . & date <= 672

// TDFs for earlier years
replace crsp_fundno_age_TDF  = 31290 if retirement_target <= 2010 & date > 672
replace age_TDF = "OV6M-VANG INST TR INCOME" if retirement_target <= 2010 & date > 672
replace crsp_fundno_age_TDF  = 31292 if retirement_target == 2015 & date > 672
replace age_TDF = "OV6O-VANG INST TR 2015" if retirement_target == 2015 & date > 672
replace crsp_fundno_age_TDF  = 31297 if retirement_target == 2020 & date > 672
replace age_TDF = "OV6P-VANG INST TR 2020" if retirement_target == 2020 & date > 672
replace crsp_fundno_age_TDF  = 31293 if retirement_target == 2025 & date > 672
replace age_TDF = "OV6Q-VANG INST TR 2025" if retirement_target == 2025 & date > 672
replace crsp_fundno_age_TDF  = 31300 if retirement_target == 2030 & date > 672
replace age_TDF = "OV6R-VANG INST TR 2030" if retirement_target == 2030 & date > 672
replace crsp_fundno_age_TDF  = 31294 if retirement_target == 2035 & date > 672
replace age_TDF = "OV6S-VANG INST TR 2035" if retirement_target == 2035 & date > 672
replace crsp_fundno_age_TDF  = 31299 if retirement_target == 2040 & date > 672
replace age_TDF = "OV6T-VANG INST TR 2040" if retirement_target == 2040 & date > 672
replace crsp_fundno_age_TDF  = 31295 if retirement_target == 2045 & date > 672
replace age_TDF = "OV6U-VANG INST TR 2045" if retirement_target == 2045 & date > 672
replace crsp_fundno_age_TDF  = 31298 if retirement_target == 2050 & date > 672
replace age_TDF = "OV6V-VANG INST TR 2050" if retirement_target == 2050 & date > 672
replace crsp_fundno_age_TDF  = 50154 if retirement_target == 2055 & date > 672
replace age_TDF = "OV6W-VANG INST TR 2055" if retirement_target == 2055 & date > 672
replace crsp_fundno_age_TDF  = 54310 if retirement_target >= 2060 & retirement_target < . & date > 672
replace age_TDF = "OV6X-VANG INST TR 2060" if retirement_target >= 2060 & retirement_target < . & date > 672

// merge in crsp data for TDFs (add in the missing data for future merges)

merge m:1 date crsp_fundno_age_TDF using "$temp/cashbond_tdf"
drop if _m == 2
assert _m != 1 if date == 672
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

gen ScrubbedID = 1

save "$temp/ch10_test", replace

use "$temp/ch10_test", replace

*** Compute Returns ***

foreach file in ch10_test {

use "$temp\factor_returns.dta", replace

mean EFA IWD IWF IWN IWO VBISX VBLTX VGSLX
matrix factor_means = e(b)'
matrix list factor_means

corr EFA IWD IWF IWN IWO VBISX VBLTX VGSLX, cov
matrix cov = r(C)
matrix list cov

clear
set obs 0
foreach var in ScrubbedID date ret var {
	gen `var' = .
}

save "$temp\investor_mean_var.dta", replace

use "$temp/ch10_test.dta", clear
keep ScrubbedID date Fund crsp_fundno port_weight
drop if port_weight == 1
joinby Fund date using "$temp/fund_returns_series_crosswalk_post.dta"
joinby date crsp_fundno using "$temp\menu_betas"
save "$temp\complex_ports.dta", replace


distinct date
local dates = r(ndistinct)
distinct ScrubbedID
local ScrubbedIDS = r(ndistinct)

local total_obs = `dates'*`ScrubbedIDS'

local counter = 0

levelsof date, local(dates)
quietly: levelsof ScrubbedID, local(ids)

matrix results = [.,.,.,.]
matrix coln results = month ScrubbedID return variance

set matsize 11000

foreach dt of local dates {

	matrix results = [.,.,.,.]

	foreach id of local ids {

		local counter = `counter' + 1
		display "Processing observation `counter' out of `total_obs'"

	qui {
	//	preserve

		keep if date == `dt'
		keep if ScrubbedID == `id'

		count
		if(r(N)>0){

			mkmat _b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX, matrix(menu_betas)
			mkmat sigma_hat_ido, matrix(sigma_hat_ido)

			matrix mu_hat = menu_betas*factor_means
			matrix sigma_hat  = menu_betas*cov*menu_betas' + diag(sigma_hat_ido)

			mkmat port_weight, matrix(w)
			matrix t = mu_hat'*w
			scalar t1 = t[1,1]
			gen investor_ret = t1

			matrix investor_var = w'*sigma_hat*w
			scalar t2 = investor_var[1,1]
			gen investor_var = t2

			matrix result = [`dt', `id', t1, t2]

			matrix results = results \ result

			//append using "$temp\investor_mean_var.dta"
			//save "$temp\investor_mean_var.dta", replace

			}
			//restore
		}
	}
	preserve
		clear
		svmat results, name(cols)
		save "$temp\investor_mean_var`dt'", replace
	restore
}


clear
append using 	"$temp\investor_mean_var696.dta" ///
				"$temp\investor_mean_var684.dta" ///
				"$temp\investor_mean_var672.dta" ///
				"$temp\investor_mean_var660.dta" ///
				"$temp\investor_mean_var648.dta" ///
				"$temp\investor_mean_var636.dta" ///
				"$temp\investor_mean_var624.dta"
				// /// "$temp\investor_mean_var_opt_696.dta"

rename cols1 date
rename cols2 ScrubbedID
rename cols3 ret
rename cols4 var

if "`file'" != "cleaning_step_one" {
	keep if date == 672
}

duplicates drop ScrubbedID date, force  //TODO: why do we have dups?

save "$temp\investor_mean_var_complex.dta", replace

use "$temp/`file'.dta", replace
keep if port_weight == 1
keep ScrubbedID date crsp_fundno
joinby crsp_fundno date using "$temp\fund_mean_var.dta"
drop crsp_fundno

append using "$temp\investor_mean_var_complex.dta"

twoway (scatter ret var if date == 672, msize(vtiny) msymbol(smx)), legend(label(1 "Pre-Redesign"))

save "$temp\investor_mean_var_`file'.dta", replace

}


// local var = "guard_intrm_onlytdf_intl"
// local var = "cleaning_step_one"

// merge returns data

use "$temp/ch10_test.dta", clear

// calculate international equities share
cap drop intl_equity_share
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
replace intl_equity_share = 0 if missing(intl_equity_share) & !missing(equities)

drop intl_share_of_equities


merge m:1 Fund date crsp_fundno using "$temp/dominated.dta"
drop if _m == 2

joinby crsp_fundno using "$temp/fund_returns_subset.dta"

if "`var'" == "cleaning_step_one" {
	save "$temp/joined_fund_data", replace
}

duplicates drop Fund, force

{ // weight variables by portfolio share
// replace missing variables with zeros (only have flags for any funds that were present in 2016 and 2017 currently)

gen ret = port_weight*mret
replace intl_equity_share = intl_equity_share*port_weight
replace cash_bonds = port_weight*cash_bonds
replace equities = port_weight*equities
replace oth_investments = port_weight*oth_investments
replace exp_ratio = exp_ratio * port_weight
replace cash_share = cash_share*port_weight
replace bond_share = bond_share*port_weight
replace dominated_simple = dominated_simple*port_weight
}

{ // filter out individuals whose portfolio weights no longer sum to one (since some of their holdings did not merge with the returns data
bys ScrubbedID date: egen total_weight = total(port_weight)
keep if round(total_weight,.01) == 1
}

gen n_funds = 1

{ // collapse funds to portfolio
collapse (sum) n_funds ret dominated_simple cash_bonds equities oth_investments sector gold money_market exp_ratio cash_share bond_share intl_equity_share ///
(first) goldbug one_sector_overweight total_sector_overweight total_mm_overweight, by(ScrubbedID date caldt)

assert cash_bonds != .
assert oth_investments != .
assert equities != .
assert dominated_simple != .
}

{ // add in returns data for t-bill to create risk-free rate
// merge in risk-free rate
gen calmonth = mofd(caldt)
gen month = calmonth

merge m:1 month using "$temp/rf_rate.dta"

drop if _m == 2
assert _m == 3
drop _m month
rename RF tbill

// generate risk-free rate for Sharpe ratios
gen rf_ret = ret - tbill
}

{ // create annual return variables
gen year = yofd(caldt)

sort ScrubbedID date year caldt

by ScrubbedID date year: gen annualized_return = 1 + rf_ret if _n == 1
by ScrubbedID date year: replace annualized_return = (1 + rf_ret) * annualized_return[_n-1] if _n != 1
by ScrubbedID date year: replace annualized_return = annualized_return[_N]
gen temp_flag = (year <= 2015 & year >= 2011)

by ScrubbedID date: gen five_year_return = annualized_return[_n-12] * annualized_return[_n-24] * annualized_return[_n-36] * annualized_return[_n-48] * annualized_return[_n-60] if date == 672 & year == 2016
by ScrubbedID date: replace five_year_return = annualized_return[_n-24] * annualized_return[_n-36] * annualized_return[_n-48] * annualized_return[_n-60] * annualized_return[_n-72] if date == 684 & year == 2017
replace five_year_return = five_year_return - 1
gen annized_five_yr_ret = (1 + five_year_return)^(1/5) - 1

// calculate variance
by ScrubbedID date: egen five_year_var = sd(rf_ret) if temp_flag == 1
replace five_year_var = five_year_var^2
// annualize variance
replace five_year_var = 12 * five_year_var

bys ScrubbedID date: egen annized_5_temp = max(annized_five_yr_ret)
bys ScrubbedID date: egen five_year_var_temp = max(five_year_var)
replace five_year_var = five_year_var_temp
replace annized_five_yr_ret = annized_5_temp

drop five_year_return five_year_var_temp annized_5_temp
}


// load portfolio data
use "$temp/ch10_test.dta", clear

egen total_tdf = sum(MarketValue), by(tdf)
gen percent_tdf = total_tdf/total_assets


gen num = exp_ratio * port_weight
egen num_total = sum(num)
egen den = total(port_weight)
gen exp_ratio_weighted = num_total/den // 0.0030893

keep ScrubbedID date crsp_fundno port_weight

// merge in return data
joinby crsp_fundno using "$temp/fund_returns_subset.dta"

// remove duplicate observations
bys ScrubbedID date crsp_fundno caldt port_weight: gen dup = cond(_N==1,0,_n)
tab dup
drop if dup > 1
drop dup

gen ret = port_weight*mret
collapse (sum) mret = ret, by(ScrubbedID date caldt)

gen cal_month = mofd(caldt)
gen lag = date - cal_month
/*
keep if lag < 61
keep if lag > 0
*/
joinby caldt using "$temp/factor_returns.dta"
joinby month using "$temp/rf_rate.dta"

//excess returns
foreach x of varlist mret EFA IWD IWF IWN IWO VBISX VBLTX VGSLX {
	replace `x'= `x' - RF
}

sort Scr caldt
gen n = _n
keep if n > 60 & n < 85

// flag observations that do not have 60 months of data for a given date
bysort date ScrubbedID: gen date_count = _N
summ date_count

// calculate portfolio betas
bysort date ScrubbedID: asreg mret MktRF, noc rmse
rename _b_MktRF beta
drop _rmse _Nobs _R2 _adjR2

// EFA is international (excludes US and Canada)
// calculate betas with other funds
bysort date ScrubbedID: asreg  mret EFA IWD IWF IWN IWO VBISX VBLTX VGSLX, noc rmse

reg mret EFA IWD IWF IWN IWO VBISX VBLTX VGSLX
predict y_hat
corr y_hat mret

save "$temp/portfolio_betas_ch_10", replace

bys ScrubbedID date: keep if _n == 1
keep ScrubbedID date beta _rmse _R2 _b_* date_count

save "$temp/ch10_test", replace

// Final summary statistics

use "$temp/five_year_rets.dta", replace // .0038388 mean/median unweighted
sort ScrubbedID date
keep ScrubbedID exp_ratio ret _rmse date
keep if date == 672 | date == 684
//duplicates drop ScrubbedID, force
merge 1:m ScrubbedID date using "$temp\individual_ports.dta"
keep if date == 672 | date == 684
drop if _m != 3
duplicates drop ScrubbedID date, force

gen num = exp_ratio * total_assets
egen num_total = sum(num)
egen den = total(total_assets)
gen exp_ratio_weighted = num_total/den // .0031079

drop num*

gen num = _rmse * total_assets
egen num_total = sum(num)
gen _rmse_av = num_total/den // .0033618

save "$temp/ID_exp_rmse", replace
