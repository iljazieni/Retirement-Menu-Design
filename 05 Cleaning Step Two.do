/*
Guardrails Baseline Cleaning Step Two
ZRS

Goal:
--

Notes:
--

Updates:
-- 11/7/19: add in dominated fund list
-- 11/7/19: calculate returns for sharpe ratio using arithmetic mean (as was done before), but calculate annualizaed returns as geometric
*/



{ // determine dominated funds
use "$temp/menu_betas.dta", replace
joinby crsp_fundno date date using "$temp/fund_summary.dta"


// determine dominated funds
replace exp_ratio = . if exp_ratio == -99 | exp_ratio > 1
egen min_style_fee = min(exp_ratio), by(date lipper_class)
egen mean_style_fee = mean(exp_ratio), by(date lipper_class)
gen excess_fee_over_min = exp_ratio - min_style_fee
gen excess_fee_over_mean = exp_ratio - mean_style_fee
count if excess_fee_over_min > 0.005 & excess_fee_over_mean > 0.0025 & !missing(excess_fee_over_min) & !missing(excess_fee_over_mean)
// default is non-dominated fund if we don't have expense ratio data
gen dominated_simple = 0
replace dominated_simple = 1 if  excess_fee_over_min > 0.005  & excess_fee_over_mean > 0.0025 & !missing(excess_fee_over_min) & !missing(excess_fee_over_mean)
keep Fund date crsp_fundno dominated_simple
save "$temp/dominated.dta", replace


}

{ // prepare returns data
use "$temp/fund_returns.dta", clear

// check for dups
bys crsp_fundno caldt: gen dup = cond(_N==1,0,_n)
tab dup
drop if dup > 1

// filter data
gen calyear = yofd(caldt)
drop if calyear <= 2010 | calyear >= 2019
keep crsp_fundno caldt month mret

save "$temp/fund_returns_subset.dta", replace

}

{ // prepare portfolio factors
do "$home/portfolio_factor.do"
}

foreach var in cleaning_step_one guard_intrm_onlytdf_joint_nonintl guard_intrm_onlytdf_joint_all guard_intrm_onlytdf_intl guard_intrm_onlytdf_equitiesover guard_intrm_onlytdf_equitiesunder guard_intrm_onlytdf_sector guard_intrm_onlytdf_expenseratio {

di "`var'"
// local var = "guard_intrm_onlytdf_intl"
// local var = "cleaning_step_one"

{ // merge returns data

use "$temp/`var'.dta", clear

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

// drop portfolios for which we don't have 2 years of returns data for all funds
bys ScrubbedID date caldt: gen month_funds = _N
bys ScrubbedID date: egen max_funds = max(month_funds)
gen temp_year1 = year(caldt)
gen temp_year2 = date/12 + 1960
// make sure each fund has 12 months of data for each fund-year
bys ScrubbedID date temp_year1: egen year_funds = count(Fund)
gen dropflag1 = (year_funds != max_funds * 12)
replace dropflag1 = 0 if temp_year1 < temp_year2 - 2 | temp_year1 > temp_year2 + 2
bys ScrubbedID date: egen dropflag2 = max(dropflag1)

drop if dropflag2 == 1

// check number of years with full data prior to 2016 for each fund-year
forvalues i = 5/6 {
	gen flag`i'_1 = (year_funds != max_funds * 12)
	replace flag`i'_1 = 0 if temp_year1 < temp_year2 - `i' | temp_year1 >= temp_year2
	bys ScrubbedID date: egen flag_`i'_2 = max(flag`i'_1)
	gen flag_`i'_3 = flag_`i'_2 if date == 672
	gen flag_`i'_4 = flag_`i'_2 if date == 684
	bys ScrubbedID: egen flag_2016_returns_`i' = max(flag_`i'_3)
	bys ScrubbedID: egen flag_2017_returns_`i' = max(flag_`i'_4)
}

// variable five_years_flag == 1 if there are 5 full years of returns data prior to 2016
gen five_years_flag_temp = (flag_2016_returns_5 == 0)
replace five_years_flag_temp = (flag_2017_returns_6 == 0) if date == 684
bys ScrubbedID: egen five_years_flag = min(five_years_flag_temp)

drop month_funds max_funds year_funds dropflag* flag* temp_year1 temp_year2

}


if "`var'" == "cleaning_step_one" {
	save "$temp/joined_fund_data", replace
}


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
bys ScrubbedID date caldt: egen total_weight = total(port_weight)
keep if round(total_weight,.01) == 1
}

gen n_funds = 1

{ // collapse funds to portfolio
collapse (sum) n_funds ret dominated_simple cash_bonds equities oth_investments sector gold money_market exp_ratio cash_share bond_share intl_equity_share ///
(first) five_years_flag goldbug one_sector_overweight total_sector_overweight total_mm_overweight, by(ScrubbedID date caldt)

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

{ // create two-year returns
sort ScrubbedID date caldt
// limit to months starting with month of interest
keep if calmonth >= date
// limit to months within three years of month of interest (so can do two-year horizon from today and two-year horizon from next year)
keep if calmonth <= (date + 35)

// expand those between one and two years in future because need this extra year to create two-year horizon looking forward from both this year and  next yeaer
expand 2 if (calmonth >= date + 12 & calmonth < date + 24)
cap drop id_order
bys ScrubbedID date caldt: gen id_order = _n
replace id_order = 2 if calmonth >= date + 24

// filter to observations for which we have 24 months of returns data for averages (48 total months since 2 sets of 24 months--exempt 2018 since we do not use returns. only 36 required for post-period because of previous drops and the fact that we only need future_ret not forward_future_ret)
bys ScrubbedID date: gen total_months = _N
tab total_months
keep if total_months == 48 | (total_months == 36 & date == 684) | date == 696
drop total_months

sort ScrubbedID date id_order caldt

// calculate average monthly returns and sd
// NOTE: using arithmetic returns for risk-free because we do not want to distort the sharpe ratio

bys ScrubbedID date id_order: gen double future_monthly_return = 1 + ret[1]
by ScrubbedID date id_order: replace future_monthly_return = future_monthly_return[_n-1] * (1 + ret) if _n > 1
by ScrubbedID date id_order: replace future_monthly_return = future_monthly_return[_N]
replace future_monthly_return = (future_monthly_return)^(1/24) - 1
bys ScrubbedID date id_order: egen future_monthly_sd = sd(ret)

bys ScrubbedID date id_order: egen rf_fut_monthly_return_sharpe = mean(rf_ret)
bys ScrubbedID date id_order: egen rf_fut_monthly_sd_sharpe = sd(rf_ret)

by ScrubbedID date: gen twelve_month_future_return = future_monthly_return[_n+24]
by ScrubbedID date: gen twelve_month_future_sd = future_monthly_sd[_n+24]

by ScrubbedID date: gen rf_12_month_fut_return_sharpe = rf_fut_monthly_return_sharpe[_n+24]
by ScrubbedID date: gen rf_12_month_fut_sd_sharpe = rf_fut_monthly_sd_sharpe[_n+24]
count if future_monthly_return != twelve_month_future_return & ScrubbedID == ScrubbedID[_n+24] & date == date[_n+24]
count if future_monthly_sd != twelve_month_future_sd & ScrubbedID == ScrubbedID[_n+24] & date == date[_n+24]

// drop duplicate rows that were used to allow future calculation
drop if id_order == 2
sort ScrubbedID date year caldt

keep if calmonth == date

{ // merge in portfolio betas
merge 1:1 date ScrubbedID using "$temp/portfolio_betas_`var'"
assert _m != 1
drop if _m == 2
drop _m


// note that not all dates have 60 months of data for the betas regressions, but we do not currently filter these out
summ date if date_count < 60
count if inlist(date,672,684) & date_count < 60
drop date_count

}

save "$temp/five_year_rets.dta", replace
}

{ // merge and save dataset
use "$temp/five_year_rets.dta", clear
joinby ScrubbedID date using "$temp/`var'.dta"
// Vanguard 2010 TDF is pushed into Income TDF in 2016, so replace it with Income Fund from 2014 onward (so we will have at least 2 future years of returns data)
replace crsp_fundno = 31290 if (Fund == "OKKK-VANG TARGET RET 2010" & date <= 672 & date >= 648) | (Fund == "OV6N-VANG INST TR 2010" & date == 684)
replace crsp_fundno = 64321 if (Fund == "OKKK-VANG TARGET RET 2010" & date <= 672 & date >= 648)
replace crsp_fundno = 31290 if (Fund == "OV6N-VANG INST TR 2010" & date == 684)
replace Fund = "OSHO-VANG TARGET RET INC" if Fund == "OKKK-VANG TARGET RET 2010" & date <= 672 & date >= 648
replace Fund = "OV6M-VANG INST TR INCOME" if Fund == "OV6N-VANG INST TR 2010" & date == 684
joinby Fund using "$input/fund_style.dta"

}

if "`var'" == "cleaning_step_one" {
	save "$temp/full_data.dta", replace
}
else {
	save "$temp/`var'_fulldata.dta", replace
}

}
