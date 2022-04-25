****** External Comparator ********

use "$temp/cleaning_step_one.dta", clear

keep if inlist(date, 672)
keep if port_weight == 1

gen fid_year = substr(Fund, -4, 4)
destring fid_year, force replace

gen van_tdf1 = (strpos(Fund, "VANG INST TR") > 0 | strpos(Fund, "VANG TARGET RET") > 0)

gen fid_right_tdf = cond(retirement_target == fid_year, 1, 0)

gen van_right = cond(retirement_target == fid_year & van_tdf1 > 0, 1, 0)

// tag the 5 TDFs we care about

bro if van_tdf & fid_year == 2030

bro if van_tdf & fid_year == 2040

bro if van_tdf & fid_year == 2050

bro if van_right & fid_year == 2055 // best we can do

gen van_five = 1 if Scr == 1520 | Scr == 418 |  Scr == 500 | Scr == 4101

// tag the corresponding fidelity ones

bro if fid_right_tdf & fid_year == 2030

bro if fid_right_tdf & fid_year == 2040

bro if fid_right_tdf & fid_year == 2050

bro if fid_right_tdf & fid_year == 2055

gen fid_five = 1 if Scr == 96 | Scr == 112 |  Scr == 4 | Scr == 218

// save file with ID and fid/van fives

keep Scr van_five fid_five
replace van_five = 0 if van_five == .
replace fid_five = 0 if fid_five == .

save "$temp/fid_van_tdfs", replace

****** Check Sharpes ********

use "$temp/collapse2_combined", clear
keep if inlist(date, 672)

merge 1:m Scr using "$temp/fid_van_tdfs"
keep if _m == 3
keep if fid_five == 1 | van_five == 1

sharpe sharpe_fiveyear
sort fid_five

****** Compute 1yr, 2yr, 5yr, Sharpe ******

// Create Hypothetical Portfolios and re-run old code

import excel "$input/monthly_returns.xlsx", firstrow clear
drop MonthlyNetAssetValuePerShar TotalNetAssetsasofMonthEnd
rename TotalReturnperShareasofMon ret
rename Date date
gen port_weight = 1
gen ScrubbedID = FundIdentifier
drop if date < 672

gen caldt = date
format caldt %d
gen year = year(date)
drop if year > 2018

gen month2=mofd(date)
format month2 %tm
drop date
rename month2 date

replace ret = 0 if ret == .

/*
bys ScrubbedID year: gen total_months = _N
gen helper = cond(total_months != 12, 1, 0)
egen helper2 = max(helper), by(Scr)
drop if helper2 == 1
drop helper*
*/
** Merge rf rate

gen calmonth = mofd(caldt)
gen month = calmonth

gen helper = dofm(date)
format helper %d
gen month_year = month(helper)
drop helper

merge m:1 month using "$temp/rf_rate.dta"

drop if _m == 2
assert _m == 3
drop _m month
rename RF tbill

// generate risk-free rate for Sharpe ratios
gen rf_ret = ret - tbill

sort ScrubbedID date year caldt

drop if year < 2011
drop if year > 2016
// create annual return variables

sort Scr year month_year

bys ScrubbedID year: asrol ret, s(product) add(1)
bys ScrubbedID year: asrol rf_ret, s(product) add(1)

// 1 year

bys ScrubbedID year: gen annualized_return = 1 + ret if _n == 1
bys ScrubbedID year: replace annualized_return = (1 + ret) * annualized_return[_n-1] if _n != 1
bys ScrubbedID year: replace annualized_return = annualized_return[_N]

gen r_a1 = annualized_return - 1 // verified

sum rf_ret_product ret_product r_a1 annualized_return if FundIdentifier == 31299 & year == 2016 // .0576845 (ret_used) // 1.085073 (annized return)

/*
preserve

gen tbill_id = 1234
collapse (mean) tbill, by(tbill_id year month_year)
sort tbill_id year
bys tbill_id year: asrol tbill, s(product) add(1)
keep year tbill_product
duplicates drop year, force

save "$temp/tbil_yearly", replace

restore
*/
merge m:1 year using "$temp/tbil_yearly"
drop _m

rename tbill_product r_t1

sum r_a1 r_t1

//keep if date == 672

gen rf_1 = r_a1 - r_t1

sum rf_1 rf_ret_product ret_product r_a1 annualized_return if FundIdentifier == 31299 & year == 2016 // .0576845 (ret_used) // 1.085073 (annized return for Scr== 11792)

save "$temp/2016_returns_MFs", replace

use "$temp/2016_returns_MFs", replace

// 5-year Ret

sort Scr year caldt

bys ScrubbedID: gen five_year_return = annualized_return[_n-12] * annualized_return[_n-24] * annualized_return[_n-36] * annualized_return[_n-48] * annualized_return[_n-60] if year == 2016
replace five_year_return = five_year_return - 1
egen helper = max(five_year_return), by(Scr)
replace five_year_return = helper
drop helper

gen annized_five_yr_ret = (1 + five_year_return)^(1/5) - 1

sum annized_five_yr_ret if FundIdentifier == 31295 // 0.0812; MATCHES

// 5-year Var

gen temp_flag = (year <= 2015 & year >= 2011)

sort Scr caldt

bys ScrubbedID: egen five_year_var = sd(rf_ret) if temp_flag == 1
replace five_year_var = five_year_var^2
replace five_year_var = 12 * five_year_var

bys ScrubbedID date: egen annized_5_temp = max(annized_five_yr_ret)
bys ScrubbedID date: egen five_year_var_temp = max(five_year_var)
replace five_year_var = five_year_var_temp
replace annized_five_yr_ret = annized_5_temp

sum five_year_var if FundIdentifier == 31295 // 0.0126; MATCHES

gen five_year_sd = sqrt(five_year_var)

gen sharpe_fiveyear = annized_five_yr_ret/five_year_sd

sum sharpe_fiveyear if FundIdentifier == 31295 // 0.7238; MATCHES

save "$temp/2016_returns_MFs_2", replace

save "$temp/external_sharpe", replace

/*
foreach year of numlist 2011(1)2016 {

	gen r`year' = annualized_return if year == `year'
	bysort Scr (r`year') : replace  r`year' =  r`year'[_n-1] if missing(r`year')
}

gen five_year_return = r2011 * r2012 * r2013 * r2014 * r2015 * r2016
replace five_year_return = five_year_return - 1
egen helper = max(five_year_return), by(Scr)
replace five_year_return = helper
drop helper


replace five_year_return = five_year_return - 1
egen helper = max(five_year_return), by(Scr)
replace five_year_return = helper
drop helper

gen annized_five_yr_ret = (1 + five_year_return)^(1/5) - 1
*/

// 2 year

gen yr2 = cond(year == 2016 | year == 2015, 1, 0)

bys Scr yr2: gen ret_2yr = 1 + rf_ret if _n == 1 & yr2 == 1
bys Scr yr2: replace ret_2yr = (1 + rf_ret) * ret_2yr[_n-1] if _n != 1 & yr2 == 1
bys Scr yr2: replace ret_2yr = ret_2yr[_N]

egen helper = max(ret_2yr), by(Scr)
drop ret_2yr
rename helper two_year_ret

// rename

rename annized_five_yr_ret ret5

gen ret1 = annualized_return - 1

gen ret2 = two_year_ret - 1

// calculate variance
bys ScrubbedID: egen five_year_var = sd(rf_ret) if temp_flag == 1
replace five_year_var = five_year_var^2
replace five_year_var = 12 * five_year_var
egen helper = max(five_year_var), by(Scr)
drop five_year_var
rename helper var_5

egen annual_var = sd(rf_ret), by(Scr year)
replace annual_var = annual_var ^ 2
replace annual_var = 12 * annual_var
egen helper = max(annual_var), by(Scr)
drop annual_var
rename helper var_1

egen two_year_var = sd(rf_ret) if yr2 == 1, by(Scr)
replace two_year_var = two_year_var ^ 2
replace two_year_var = 12 * two_year_var
egen helper = max(two_year_var), by(Scr)
drop two_year_var
rename helper var_2

// Sharpe Ratios

gen five_year_sd = sqrt(var_5)
gen sharpe_fiveyear = ret5/five_year_sd

gen ret_1 = annualized_return - 1
gen sd_1 = sqrt(var_1)
gen sharpe = ret_1/sd_1

gen sd_2 = sqrt(var_2)
gen sharpe2 = ret2/sd_2

foreach var of varlist sharpe sharpe2 {

	egen helper_`var' = max(`var'), by(Scr)
	replace `var' = helper_`var'
	drop helper_`var'
}


*** Sharpe Table

use "C:\Users\EI87\Dropbox (YLS)\Retirement Menu Design\code\STATA -- ZS\Temp_ORP_EI\crsp_fund_summary.dta", clear
duplicates drop fund_name, force
duplicates drop crsp_fundno, force
rename crsp_fundno FundIdentifier
merge 1:m FundIdentifier using "$temp/external_sharpe"
drop if _m != 3

duplicates drop FundIdentifier, force
sort fund_name

drop if sharpe == . | sharpe_fiveyear == .

gen sch = 1 if fund_name == "Schwab Capital Trust: Schwab Target 2010 Fund"
replace sch = 1 if fund_name == "Schwab Capital Trust: Schwab Target 2020 Fund"
replace sch = 1 if fund_name == "Schwab Capital Trust: Schwab Target 2030 Fund"
replace sch = 1 if fund_name == "Schwab Capital Trust: Schwab Target 2040 Fund"

gen tiaa = 1 if fund_name == "TIAA-CREF Funds: Lifecycle Funds 2010 Fund; Institutional Class Shares"
replace tiaa = 1 if fund_name == "TIAA-CREF Funds: Lifecycle Funds 2020 Fund; Institutional Class Shares"
replace tiaa = 1 if fund_name == "TIAA-CREF Funds: Lifecycle Funds 2030 Fund; Institutional Class Shares"
replace tiaa = 1 if fund_name == "TIAA-CREF Funds: Lifecycle Funds 2040 Fund; Institutional Class Shares"

gen van = 1 if fund_name == "Vanguard Chester Funds: Vanguard Target Retirement 2010 Fund; Investor Shares"
replace van = 1 if fund_name == "Vanguard Chester Funds: Vanguard Target Retirement 2020 Fund; Investor Shares"
replace van = 1 if fund_name == "Vanguard Chester Funds: Vanguard Target Retirement 2030 Fund; Investor Shares"
replace van = 1 if fund_name == "Vanguard Chester Funds: Vanguard Target Retirement 2040 Fund; Investor Shares"

sum sharpe if sch == 1
sum sharpe if tiaa == 1
sum sharpe if van == 1

sum sharpe_fiveyear if sch == 1
sum sharpe_fiveyear if tiaa == 1
sum sharpe_fiveyear if van == 1

sum sharpe2 if sch == 1
sum sharpe2 if tiaa == 1
sum sharpe2 if van == 1

keep if sch == 1 | van == 1 | tiaa == 1
keep fund_name sharpe* exp_ratio

use "$temp/collapse2_combined", clear
keep if date == 672
keep if fid_tdf_share == 1
keep if inlist(Scr, 6990, 5964, 4090, 12288) // 2010-2040 Vanguard/TIAA/Schwab TDFs
keep Scr sharpe_fiveyear


*** Return Check

use "C:\Users\EI87\Dropbox (YLS)\Retirement Menu Design\code\STATA -- ZS\Temp_ORP\crsp_fund_summary.dta", clear

duplicates drop fund_name, force
duplicates drop crsp_fundno, force
rename crsp_fundno FundIdentifier
merge 1:m FundIdentifier using "$temp/2016_returns_MFs"
drop if _m != 3

sort fund_name

keep fund_name rf_1 FundIdentifier
rename rf_1 ret_pranjal

save "$temp/van_returns", replace

use "$temp/cleaning_step_one.dta", clear
keep if date == 672
keep if port_weight == 1
gen fid_year = substr(Fund, -4, 4)
destring fid_year, force replace
gen van_tdf1 = (strpos(Fund, "VANG INST TR") > 0 | strpos(Fund, "VANG TARGET RET") > 0)
gen fid_right_tdf = cond(retirement_target == fid_year, 1, 0)
gen van_right = cond(retirement_target == fid_year & van_tdf1 > 0, 1, 0)
sort Fund

keep if inlist(Scr, 6990, 5964, 4090, 12288) // 2010-2040 Fidelity TDFs

// CHCEK INDIVIDUAL PORTFOLIOS

rename crsp_fundno FundIdentifier
merge m:1 FundIdentifier using "$temp/van_returns"

keep if _m == 3

drop _m

merge 1:m ScrubbedID using "$temp/collapse2_combined"
keep if date == 672
drop if _m != 3


sort Fund


sum ret_pranjal return_used ante_ret forward_future_ret future_ret

sum ret_pranjal return_used if FundIdentifier == 31299 & total_tdf_share == 1

sum annized_five_yr_ret five_year_var sharpe_fiveyear if Scr == 12212 & total_tdf_share == 1 // 0.081; 0.0126; 0.721752
