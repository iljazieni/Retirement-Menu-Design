/*

Primary Author: EI
Date Initialized: 4/24/2022

Main purpose: Replicate all Tables for Chapters 4 - 10 of Retirement Menu Design

*/

{ // setup
clear all

cap log close

global home "C:\Users\EI87\Documents\GitHub\Retirement-Menu-Design"
global output "C:/Users/EI87/Dropbox (YLS)/Retirement Menu Design/code/STATA -- ZS/replication_EI"
global input "C:/Users/EI87/Dropbox (YLS)/Retirement Menu Design/code/STATA -- ZS/Input"
global temp "C:/Users/EI87/Dropbox (YLS)/Retirement Menu Design/code/STATA -- ZS/Temp_ORP_EI"

set more off, perm

global color_p2 = "86 180 233"
global color_p3 = "230 159 0"
global color_p4 = "0 205 150"

graph set window fontface "Times New Roman"

set maxvar 20000

}

// local switches
local chapter4          1
local chapter5          0
local chapter8          1


{ // set levels that flag overweighting
global tot_mm_lev = .2
global ind_sec_lev = .1
global ind_gold_lev = .1
global tot_sec_lev = .5
global intl_eq_perc = .2
global exp_ratio_cap = .0075

}


if `chapter4'==1 {
{ // load and save crsp data
clear all
use "$input\crsp_fund_summary", clear
duplicates drop
save "$temp\crsp_fund_summary.dta", replace
}

{ // adjust incorrect crsp fund number
import excel "$input/plan_crsp_crosswalk.xls", firstrow clear

replace crsp_fundno = 31290 if Fund == "OV6M-VANG INST TR INCOME"
replace crsp_fundno = 31297 if Fund == "OKKL-VANG TARGET RET 2020"

save "$temp\crosswalk_clean", replace
}

{ // import and save plan data and crosswalk
use "$temp\orp_plan_merged.dta", replace

gen date = mofd(CalendarDay)
format date %tm
gen month = date
joinby Fund using "$temp\crosswalk_clean"

gen t= 1
collapse t, by(crsp_fundno Fund CalendarDay )
joinby crsp_fundno using "$input\fund_summary", unm(master)
gen date_diff = caldt - CalendarDay
keep if -50 < date_diff & date_diff  < 50
keep caldt crsp_fundno crsp_portno
save "$temp\fund_port_crosswalk.dta", replace
}

{ // shift fund summary dates
use "$input\fund_summary.dta", clear
gen date = mofd(caldt) + 1
tab date
format date %tm
save "$temp\fund_summary.dta", replace
}

{ // crosswalk
// get the fund number of the earliest fund to have the same portno
keep if caldt > mdy(1,1,2012)
egen early_portdate = min(first_offer_dt), by(crsp_portno)
gen t = crsp_fundno if early_portdate  == first_offer_dt
egen early_fundno = min(t), by(crsp_portno)
drop t
gen t = 1
collapse t, by(early_fundno crsp_portno)
drop t
drop if missing(crsp_portno)
save "$temp\portno_crosswalk.dta", replace

//merge to get the longest possible series
use "$input\plan_data.dta", replace
gen date = mofd(CalendarDay)
format date %tm
gen month = date

joinby Fund using "$temp\crosswalk_clean"
gen t = 1
collapse t, by(crsp_fundno date Fund )
drop if missing(crsp_fundno)

joinby crsp_fundno date using "$temp\fund_summary.dta", unm(master)

gen crsp_fundno_orig = crsp_fundno
gen series_length =  date -  mofd(first_offer_dt)
drop _merge
gen matchno = crsp_fundno if series_length >= 48 & !missing(series_length)  //268 fund-years without a 4 year series

keep Fund date crsp_fundno crsp_fundno_orig crsp_portno series_length  matchno fund_name

export excel using "$input\fund_returns_series_crosswalk_pre-edit.xls", firstrow(var) replace

// this file needs to be hand-edited to fill in some missing funds

import excel using "$input\fund_returns_series_crosswalk_post-edit.xls", firstrow clear

drop series_length matchno crsp_portno
replace date = mofd(date)
format date %tm

joinby crsp_fundno date using "$temp\fund_summary.dta", unm(master)

gen series_length =  date -  mofd(first_offer_dt)
gen longest_series_length = mofd(mdy(1,1,2018))-  mofd(first_offer_dt)

keep Fund date crsp_fundno crsp_fundno_orig series_length longest_series_length lipper_obj_cd // EI edit: delete hand_match

save "$temp/fund_returns_series_crosswalk_post.dta", replace
}

 //There are three methods used to get betas:
//   * if we have 48 months of trailing data, whe just estimate it.
//   * if there is not enough, then if we have 60 months of data, we drop current year
//     and estimate beta with forward data
//   * if the fund is too new altogether, then we use average of lipper objective home.


//We need to generate two list of crsp_fundnos for returns data
	//easy cases  (1) and (2)
keep if  series_length >= 48 | longest_series_length >= 60
keep  crsp_fundno
duplicates drop

//This is the list we use to find fund betas
export delimited using "$temp/conventional_beta_fundos.txt", replace

//format date for the raw fund returns
clear
use "$input\fund_returns.dta"
gen month = mofd(caldt)
format month %tm
drop if missing(month)
save "$temp\fund_returns.dta", replace

//format the factor returns
use "$input\factor_returns_ext.dta", replace
joinby crsp_fundno using "$input\fund_summary_current.dta"
tab ticker
tab caldt
keep if caldt > mdy(10,30,2003)
tab caldt
keep caldt crsp_fundno mret mtna mnav fund_name ticker
duplicates drop caldt crsp_fundno mret, force

levelsof ticker, local(tickers) clean

foreach tick of local tickers{

		gen `tick' = .
		replace `tick' =  mret if ticker == `"`tick'"'
}

collapse  `tickers', by(caldt)
gen month = mofd(caldt)
	format month %tm
save "$temp\factor_returns.dta", replace

//format the Rf rate from French's website
clear
import excel "$input\F-F_Research_Data_Factors.xlsx", sheet("F-F_Research_Data_Factors") firstrow
replace RF = RF/100
tostring Date, replace
replace Date  = Date + "01"
gen date = date(Date, "YMD")
format date %td
gen month = mofd(date)
format month %tm
keep month RF MktRF
save "$temp\rf_rate.dta", replace

use "$temp\fund_returns.dta", replace
joinby month using "$temp\factor_returns.dta"
joinby month using "$temp\rf_rate.dta"

//excess returns
foreach x of varlist mret `tickers'  {
	replace `x'= `x' - RF
}

asreg  mret `tickers' RF, noc min(36) rmse by(crsp_fundno) window(month 60)

//I am not sure this is the right thing
gen sigma_hat_ido = _rmse^2
keep crsp_fundno month  RF _* sigma_hat_ido
gen date = month
drop if _Nobs == 0

save "$temp\rolling_betas", replace


{ //  Match Fund Betas with List of Funds

use "$temp/fund_returns_series_crosswalk_post.dta", replace  //1460

joinby date crsp_fundno using "$temp\rolling_betas" //1447 matched, 65 missing data

//if we have some data, we fill it in
gsort crsp_fundno -date
gen missing_data = 1 if missing(_b_EFA)

foreach x of varlist  _rmse _Nobs _R2 _adjR2 _b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _b_RF sigma_hat_ido missing_data {
	by crsp_fundno: replace `x'= `x'[_n-1] if missing_data==1
}

//we have 6 without returns information
drop if missing(_b_EFA)

//leaves 1441 fund, year observations out of 1460 total
save  "$temp\menu_betas.dta", replace
}

{ //  Estimate Menu Moments: Use same factor moments for all dates

clear
set obs 0
foreach var in crsp_fundno date ret var {
gen `var' = .
}
save "$temp\fund_mean_var.dta", replace

use "$temp\factor_returns.dta", replace

mean EFA IWD IWF IWN IWO VBISX VBLTX VGSLX
matrix factor_means = e(b)'
matrix list factor_means

corr EFA IWD IWF IWN IWO VBISX VBLTX VGSLX, covariance
matrix cov = r(C)
matrix list cov

set matsize 3000

use "$temp\menu_betas.dta", clear

levelsof date, local(dates)

//local dt  684
foreach dt of local dates {

use "$temp\menu_betas.dta", clear

display "keep one date"
keep if date == `dt'

display "matrix of menu betas"
mkmat _b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX, matrix(menu_betas)
mkmat crsp_fundno date, matrix(fundnos)

matrix menu_ret = menu_betas*factor_means
//matrix list menu_ret

mkmat sigma_hat_ido, matrix(sigma_hat_ido)
matrix menu_var  = menu_betas*cov*menu_betas' + diag(sigma_hat_ido)
//matrix list menu_var

matrix  meanvar = fundnos, menu_ret, menu_var
matrix coln meanvar = month crsp_fundno return variance*

matrix fund_var = vecdiag(menu_var)'


matrix  fund_level = fundnos, menu_ret, fund_var
matrix coln fund_level = month crsp_fundno ret var

matrix coln meanvar = month crsp_fundno return variance*

clear

display "matrix to data"
svmat meanvar, name(cols)

//full return and covariance matrix
display "mean and return output matrix"
export delimited using "$temp\mean_var_matricies_`dt'", replace

clear

display "fund level matrix to data"
svmat fund_level, name(cols)

rename cols1 crsp_fundno
rename cols2 date
rename cols3 ret
rename cols4 var

//individual fund data
append using "$temp\fund_mean_var.dta"
save "$temp\fund_mean_var.dta", replace
}


use "$temp\fund_mean_var.dta", replace
joinby crsp_fundno date using "$temp\menu_betas.dta"
joinby Fund using "$input\fund_style.dta"

replace is_mmf = 1 if lipper_obj_cd  == "MM" | lipper_obj_cd  == "UST"

preserve

keep if date == 696

restore
preserve

keep if date == 648

restore

preserve
keep if is_target_date == 1
collapse ret var, by(target_date)
scatter ret var, mlabel(target_date)
restore

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

{ // clean data for cash-bond share and expense ratios (data is for 2010-2018)
use "$temp/crsp_fund_summary.dta", clear

// check for duplicates
bys crsp_fundno caldt: gen dup = cond(_N==1,0,_n)
tab dup
drop if dup > 1

// check if the variables generally sum to one
gen total_per = cond(missing(per_com),0,per_com) + cond(missing(per_pref),0,per_pref) + ///
cond(missing(per_conv),0,per_conv) + cond(missing(per_corp),0,per_corp) + cond(missing(per_muni),0,per_muni) + ///
cond(missing(per_govt),0,per_govt) + cond(missing(per_oth),0,per_oth) + cond(missing(per_cash),0,per_cash) + ///
cond(missing(per_bond),0,per_bond) + cond(missing(per_abs),0,per_abs) + cond(missing(per_mbs),0,per_mbs) + ///
cond(missing(per_eq_oth),0,per_eq_oth) + cond(missing(per_fi_oth),0,per_fi_oth)
replace total_per = round(total_per)
count if total_per == 100
// filter to complete records
drop if total_per != 100

// adjust so no holdings are negative
foreach perc in per_com per_pref per_conv per_corp per_muni per_govt per_oth per_cash per_bond per_abs per_mbs per_eq_oth per_fi_oth {
replace `perc' = 0 if `perc' < 0
}

// calculate share of cash and bonds in each fund
gen cash_bonds = cond(missing(per_conv),0,per_conv) + cond(missing(per_corp),0,per_corp) + cond(missing(per_muni),0,per_muni) + ///
cond(missing(per_govt),0,per_govt) + cond(missing(per_cash),0,per_cash) + cond(missing(per_bond),0,per_bond) + ///
cond(missing(per_abs),0,per_abs) + cond(missing(per_abs),0,per_abs) + cond(missing(per_fi_oth),0,per_fi_oth)
replace cash_bonds = cash_bonds/100
drop if round(cash_bonds,.1) < 0 | round(cash_bonds,.1) > 1

// calculate share of cash
gen cash_share = cond(missing(per_cash),0,per_cash)
replace cash_share = cash_share/100
drop if round(cash_share,.1) < 0 | round(cash_share,.1) > 1

// calculate share of bonds in each fund
gen bond_share = cond(missing(per_conv),0,per_conv) + cond(missing(per_corp),0,per_corp) + cond(missing(per_muni),0,per_muni) + ///
cond(missing(per_govt),0,per_govt) + cond(missing(per_bond),0,per_bond) + ///
cond(missing(per_abs),0,per_abs) + cond(missing(per_abs),0,per_abs) + cond(missing(per_fi_oth),0,per_fi_oth)
replace bond_share = bond_share/100
drop if round(bond_share,.1) < 0 | round(bond_share,.1) > 1

// calculate share of equities in each fund
gen equities = cond(missing(per_eq_oth),0,per_eq_oth) + cond(missing(per_pref),0,per_pref) + ///
cond(missing(per_com),0,per_com)
replace equities = equities/100
drop if round(equities,.1) < 0 | round(equities,.1) > 1

// calculate share of other investments in each fund
gen oth_investments = cond(missing(per_oth),0,per_oth)
replace oth_investments = oth_investments/100
drop if round(oth_investments,.1) < 0 | round(oth_investments,.1) > 1

gen date = (yofd(caldt) - 1960) * 12

// deal with missing expense ratios
// if expense ratio is missing, fill in with previous available ratio, if still missing, use next available expense ratio
replace exp_ratio = . if exp_ratio == -99 | exp_ratio > 1 | exp_ratio == 0
sort crsp_fundno date
by crsp_fundno: replace exp_ratio = exp_ratio[_n-1] if missing(exp_ratio)
forvalues i = 1/9 {
by crsp_fundno: replace exp_ratio = exp_ratio[_n+1] if missing(exp_ratio)
}

keep crsp_fundno date cash_bonds equities oth_investments cash_share bond_share exp_ratio

save "$temp/cashbond", replace

}

{ // load map of 2016 and 2017 funds to sector funds
import excel using "$input/2016 sector fund list.xlsx", clear firstrow
tempfile tempsector
save "`tempsector'"
import excel using "$input/2017_2018 Fund List.xls", clear firstrow
append using "`tempsector'"
drop perc_domestic_equities perc_intl_equities
bys Fund: keep if _n == 1
foreach var of varlist sector gold money_market bond equity tdf balanced real_estate {
replace `var' = 0 if missing(`var')
}

save "$temp/sectorfunds", replace

keep Fund intl_share_of_equities
rename Fund age_TDF
rename intl_share_of_equities tdf_intl_share
save "$temp/tdf_sectorfunds", replace

}

{ // load individual portfolio data
use "$temp/individual_ports.dta", clear // 12,442 unique

joinby Fund date using "$temp/fund_returns_series_crosswalk_post.dta"

// check for duplicates
duplicates drop

// save total assets by ScrubbedID and date
preserve
bys ScrubbedID date: keep if _n == 1
keep ScrubbedID date total_assets Gender RoundedSalary MaritialStatus
save "$temp/asset_list", replace
restore
// Vanguard 2010 TDF is pushed into Income TDF in 2016, so replace it with Income Fund from 2014 onward (so we will have at least 2 future years of returns data)
replace crsp_fundno = 31290 if (Fund == "OKKK-VANG TARGET RET 2010" & date <= 672 & date >= 648) | (Fund == "OV6N-VANG INST TR 2010" & date == 684)
replace crsp_fundno = 64321 if (Fund == "OKKK-VANG TARGET RET 2010" & date <= 672 & date >= 648)
replace crsp_fundno = 31290 if (Fund == "OV6N-VANG INST TR 2010" & date == 684)
replace Fund = "OSHO-VANG TARGET RET INC" if Fund == "OKKK-VANG TARGET RET 2010" & date <= 672 & date >= 648
replace Fund = "OV6M-VANG INST TR INCOME" if Fund == "OV6N-VANG INST TR 2010" & date == 684

// save a list of all funds by date
preserve
bys Fund date: keep if _n == 1
gen calyear = date/12 + 1960
keep Fund calyear crsp_fundno
save "$temp/fund_date_list", replace
restore

// save a list of all funds from 2016-2018
preserve
keep if inlist(date,672,684,696)
gen date_2016 = (date == 672)
gen date_2017 = (date == 684)
gen date_2018 = (date == 696)
bys Fund: egen flag_2016 = max(date_2016)
bys Fund: egen flag_2017 = max(date_2017)
bys Fund: egen flag_2018 = max(date_2018)
bys Fund: keep if _n == 1
keep Fund crsp_fundno flag_2016 flag_2017 flag_2018

export excel "$temp/limited_fund_list.xls", replace firstrow(variable)
restore

}

{ // merge in crsp data
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
preserve
import excel "$input/missing expense ratio data.xlsx", firstrow clear
rename exp_ratio exp_ratio2
bys crsp_fundno: keep if _n == 1
drop Fund
save "$temp/missing expense ratio data", replace
restore

cap drop _m
merge m:1 crsp_fundno using "$temp/missing expense ratio data"
drop if _m == 2
replace exp_ratio = exp_ratio2 if missing(exp_ratio)
assert !missing(exp_ratio) if inlist(date, 672, 684, 696)
drop _m exp_ratio2


// save list of missing equities ratios
preserve
keep if missing(equities)
keep if inlist(date, 672, 684, 696)
bys Fund crsp_fundno: keep if _n == 1
keep Fund crsp_fundno
export excel "$temp/missing equities.xlsx", replace firstrow(variables)
// manually found share equities (as of Dec. 2019) for these funds
restore

// import and merge in additional equities data
preserve
import excel "$input/missing equities data.xlsx", firstrow clear
rename equities equities2
bys crsp_fundno: keep if _n == 1
drop Fund
save "$temp/missing equities data", replace
restore

cap drop _m
merge m:1 crsp_fundno using "$temp/missing equities data"
drop if _m == 2
replace equities = equities2 if missing(equities)
assert !missing(equities) if inlist(date, 672, 684, 696)
drop _m equities2

}

 // drop 2019 data
drop if date >= 708


{ // merge in data on sector funds
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
preserve
keep Fund intl_equity_fund
bys Fund: keep if _n == 1
save "$temp/intl_equity_funds", replace
restore

keep ScrubbedID date crsp_fundno crsp_fundno_orig port_weight sector gold money_market AgeasofNov2018 ///
Fund intl_equity_share intl_share_of_equities exp_ratio cash_bonds cash_share bond_share equities oth_investments
}

{ // determine correct TDF and benchmark level of domestic equities & international equities
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
preserve
use "$temp/cashbond", clear
assert !missing(date)
bys crsp_fundno date: assert _N == 1

// append on for missing date & drop duplicates (since not all of those that appear in crsp have full the set of dates)
append using "$temp/missing expense ratio data"
replace date = 672 if missing(date)
append using "$temp/missing expense ratio data"
replace date = 684 if missing(date)
append using "$temp/missing expense ratio data"
replace date = 696 if missing(date)
append using "$temp/missing equities data"
replace date = 672 if missing(date)
append using "$temp/missing equities data"
replace date = 684 if missing(date)
append using "$temp/missing equities data"
replace date = 696 if missing(date)

bys crsp_fundno date: gen count = _N
drop if count == 3 & equities2 != .
drop count
bys crsp_fundno date: gen count = _N
assert count <= 2
drop if count == 2 & exp_ratio2 != .
drop exp_ratio2 equities2 count
bys crsp_fundno date: gen count = _N
asser count == 1
drop count

// merge in data for missing equities and expense ratio data
merge m:1 crsp_fundno using "$temp/missing expense ratio data"
replace exp_ratio = exp_ratio2 if missing(exp_ratio)
cap drop _m
merge m:1 crsp_fundno using "$temp/missing equities data"
replace equities = equities2 if missing(equities)
drop exp_ratio2 equities2 _m


// resave crsp data with manually collected values
save "$temp/cashbond", replace


rename crsp_fundno crsp_fundno_age_TDF
foreach var in cash_bonds equities oth_investments cash_share bond_share exp_ratio {
	rename `var' tdf_`var'
}

save "$temp/cashbond_tdf", replace

restore

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

}

{ // save glidepath data
preserve
keep if date == 672
gen target_age2018 = 2018 - (retirement_target - 65)
keep if retirement_target <= 2055 & retirement_target >= 2010
keep if AgeasofNov2018 == target_age2018
bys age_TDF: keep if _n == _N

gsort -AgeasofNov2018
gen age = AgeasofNov2018 - 3
gen empty = ""
la var age "Age"
la var age_TDF "Fund"
la var tdf_cash_share "% Cash"
la var tdf_bond_share "% Bonds"
la var tdf_cash_bonds "% Cash & Bonds"
la var tdf_intl_eq_share "% International Equities"
la var tdf_dom_eq_share "% Domestic Equities"
la var tdf_equities "% Equities"
la var empty " "

gen graph_equities = tdf_equities*100
gen graph_equities2 = graph_equities/2
gen graph_equities3 = graph_equities*2
replace graph_equities3 = 100 if graph_equities3 > 100
save "$temp/glidepath graph data", replace

keep age_TDF tdf_cash_share tdf_bond_share tdf_cash_bonds tdf_intl_eq_share tdf_dom_eq_share tdf_equities empty
order age_TDF tdf_cash_share tdf_bond_share tdf_intl_eq_share tdf_dom_eq_share empty tdf_cash_bonds tdf_equities

restore
}

{ // weight sector variables by portfolio share
// replace missing variables with zeros (only have flags for any funds that were present in 2016 and 2017 currently)
foreach var of varlist sector gold money_market intl_share_of_equities {
replace `var' = 0 if missing(`var')
}

assert !missing(sector) & !missing(gold) & !missing(money_market) & ! missing()
replace sector = port_weight*sector
replace gold = port_weight*gold
replace money_market = port_weight*money_market
}

{ // flag over- and under-weighting

// individual sector funds
gen temp = (gold > $ind_gold_lev & gold < .)
bys ScrubbedID date: egen goldbug = max(temp)
drop temp
gen temp = (sector > $ind_sec_lev & sector < .)
bys ScrubbedID date: egen one_sector_overweight = max(temp)
drop temp

// total sector funds cap
bys ScrubbedID date: egen total_sector_temp = total(sector)
gen total_sector_overweight = (total_sector_temp > $tot_sec_lev & sector < .)

// total money market funds cap
bys ScrubbedID date: egen total_mm_temp = total(money_market)
gen total_mm_overweight = (total_mm_temp > $tot_mm_lev & total_mm_temp < .)

// total international share of equities minimum
gen intl_weight = equities * port_weight
bys ScrubbedID date: egen total_intl_share_temp = wtmean(intl_share_of_equities), weight(intl_weight)
gen total_intl_share_under = (total_intl_share_temp < $intl_eq_perc)
drop intl_share_of_equities

// total expense ratio cap
bys ScrubbedID date: egen total_exp_temp = wtmean(exp_ratio), weight(port_weight)
gen total_exp_over = (total_exp_temp > $exp_ratio_cap & total_exp_temp < .)
gen total_exp_over_50 = (total_exp_temp > .0050 & total_exp_temp < .)
gen total_exp_over_100 = (total_exp_temp > .0100 & total_exp_temp < .)

// minimum half of glide path for equities, max double
bys ScrubbedID date: egen tot_eq = wtmean(equities), weight(port_weight)
gen total_eq_under = (tot_eq < (tdf_equities / 2))
gen total_eq_over = (tot_eq > (tdf_equities * 2) & tot_eq < .)
gen total_eq_violation = (total_eq_under == 1 | total_eq_over == 1)

}

{ // filter out portfolios that have weights that do not sum to one
bys ScrubbedID date: egen total_weight = total(port_weight)
assert !missing(total_weight) & total_weight >= .9999
drop total_weight
}

{ // save list portfolios affected by guardrails
preserve
keep if date == 672
keep ScrubbedID goldbug total_eq_under total_eq_over total_eq_violation total_exp_over total_exp_over_50 total_exp_over_100 total_intl_share_under total_mm_overweight total_sector_overweight one_sector_overweight AgeasofNov2018
bys ScrubbedID: keep if _n == 1
save "$temp/guardrails flags", replace
restore

preserve
keep ScrubbedID date goldbug total_eq_under total_eq_over total_eq_violation total_exp_over total_intl_share_under total_mm_overweight total_sector_overweight one_sector_overweight
bys ScrubbedID date: keep if _n == 1
save "$temp/guardrail each date flags", replace
restore

}

 // save data
save "$temp/cleaning_step_one.dta", replace



use "$temp/cleaning_step_one.dta", replace

sort Scr date

collapse (mean) crsp_fundno exp_ratio, by(Scr) // 12442 in ORP data

use "C:\Users\EI87\Dropbox (YLS)\Retirement Menu Design\code\STATA -- ZS\Temp\cleaning_step_one.dta", clear

sort Scr date

collapse (mean) crsp_fundno exp_ratio, by(Scr) // 14547 in old data

/*
Guardrails Counterfactual Setup -- joint, all extra funds to TDF
ZRS

Goal:
--

Notes:
--

Updates:
--

*/

// guardrails analysis setup (all guardrails, all modifications to tdfs)

use "$temp/cleaning_step_one.dta", clear

keep if inlist(date, 672, 684)

{ // sector fund guardrail
// first deal with those that have >x% in any individual sector fund
gen port_weight2 = port_weight
gen single_sec_over = sector - $ind_sec_lev
replace single_sec_over = 0 if single_sec_over < 0
// cap portfolio weight with single sector fund limits
replace port_weight2 = port_weight - single_sec_over if single_sec_over != .
bys ScrubbedID date: egen total_adjust_1 = total(single_sec_over)

preserve
keep ScrubbedID total_adjust_1
rename total_adjust_1 adjust_sector
bys ScrubbedID: keep if _n == 1
save "$temp/onlytdf_sector_adjust", replace
restore


preserve
keep if total_adjust_1 > 0
bys ScrubbedID date: keep if _n == 1
replace port_weight2 = total_adjust_1
keep ScrubbedID date Fund crsp_fundno port_weight2 one_sector_overweight goldbug total_sector_overweight ///
crsp_fundno_age_TDF age_TDF tdf_exp_ratio
gen sector = 0
gen gold = 0
gen money_market = 0

replace Fund = age_TDF
replace crsp_fundno = crsp_fundno_age_TDF
gen exp_ratio = tdf_exp_ratio
// assert Fund != ""
// assert crsp_fundno != .
tempfile filler
save "`filler'"
restore

append using "`filler'"

bys ScrubbedID date: egen temp = total(port_weight2)
// assert round(temp, .00001) == 1
replace port_weight = port_weight2
drop port_weight2

save "$temp/guard_intrm_onlytdf_sector_temp", replace

/*
** testing for r12 **

use "$temp/guard_intrm_onlytdf_sector_temp", replace

egen max = max(one_sector_over), by(Scr)
egen max2 = max(date), by(Scr)

*/
}

{ // expense ratio guardrail
// calculate portfolio expense ratio
cap drop total_exp_temp
bys ScrubbedID date: egen total_exp_temp = wtmean(exp_ratio), weight(port_weight)

// total non-missing port_weight under and over cutoff
bys ScrubbedID date: egen port_weight_under1 = total(port_weight) if !missing(exp_ratio) & exp_ratio <= $exp_ratio_cap
bys ScrubbedID date: egen port_weight_over1 = total(port_weight) if !missing(exp_ratio) & exp_ratio > $exp_ratio_cap
bys ScrubbedID date: egen port_weight_under2 = max(port_weight_under1)
bys ScrubbedID date: egen port_weight_over2 = min(port_weight_over1)
replace port_weight_under2 = 0 if missing(port_weight_under2)
replace port_weight_over2 = 0 if missing(port_weight_over2)
gen non_missing_weight = port_weight_over2 + port_weight_under2

// calculate portfolio expense ratio of funds under and over cutoff
bys ScrubbedID date: egen exp_under1 = wtmean(exp_ratio) if !missing(exp_ratio) & exp_ratio <= $exp_ratio_cap , weight(port_weight)
bys ScrubbedID date: egen exp_over1 = wtmean(exp_ratio) if !missing(exp_ratio) & exp_ratio > $exp_ratio_cap , weight(port_weight)
bys ScrubbedID date: egen exp_under2 = min(exp_under1)
bys ScrubbedID date: egen exp_over2 = min(exp_over1)
replace exp_under2 = 0 if missing(exp_under2)
replace exp_over2 = 0 if missing(exp_over2)

// solve for necessary port_weight in tdf to reduce expense ratio to cutoff -- only reducing holdings in funds that exceed the cutoff
//  $exp_ratio_cap = port_weight_under2/non_missing_weight * exp_under2 + (port_weight_over2/non_missing_weight - x) * exp_over2 + x * tdf_exp_ratio
//  $exp_ratio_cap - port_weight_under2/non_missing_weight * exp_under2 - port_weight_over2/non_missing_weight * exp_over2 = x * tdf_exp_ratio - x * exp_over2
gen total_adjust2 = ($exp_ratio_cap - port_weight_under2/non_missing_weight * exp_under2 - port_weight_over2/non_missing_weight * exp_over2) / (tdf_exp_ratio - exp_over2)
replace total_adjust2 = 0 if total_exp_temp <= $exp_ratio_cap

replace total_adjust2 = total_adjust2 * non_missing_weight
// if adjustment is missing, it is because no adjustment is needed or all funds in a portfolio are missing expense ratios
// assert total_exp_temp <= $exp_ratio_cap | missing(total_exp_temp) if missing(total_adjust2)
replace total_adjust2 = 0 if missing(total_adjust2) | total_adjust2 < 0

// adjust down the port_weight of those that are over cutoff (proportionate to their port_weight among those that are over cutoff)
gen share_total_over = port_weight / port_weight_over2
replace port_weight = port_weight - (share_total_over * total_adjust2) if exp_ratio > .0075 & !missing(exp_ratio)

// make sure port_weight sums correctly
bys ScrubbedID date: egen temp2 = total(port_weight)
// assert round(temp2 + total_adjust2, .0001) == round(temp,.0001)

preserve
keep ScrubbedID total_adjust2
rename total_adjust2 adjust_expense
bys ScrubbedID: keep if _n == 1
cap drop _m
merge 1:1 ScrubbedID using "$temp/onlytdf_sector_adjust"
drop _m
save "$temp/temp_adjustment1", replace
restore

preserve
keep if total_adjust2 > 0
bys ScrubbedID date: keep if _n == 1
replace port_weight = total_adjust2
keep ScrubbedID date Fund crsp_fundno port_weight one_sector_overweight goldbug total_sector_overweight ///
crsp_fundno_age_TDF age_TDF tdf_exp_ratio
gen sector = 0
gen gold = 0
gen money_market = 0

replace Fund = age_TDF
replace crsp_fundno = crsp_fundno_age_TDF
gen exp_ratio = tdf_exp_ratio
// assert Fund != ""
// assert crsp_fundno != .
tempfile filler2
save "`filler2'"
restore

append using "`filler2'"

// make sure port_weight sums correctly
cap drop temp2
bys ScrubbedID date: egen temp2 = total(port_weight)
// assert round(temp2,.000001) == 1

// calculate portfolio expense ratio (and fix rounding errors)
cap drop total_exp_temp
bys ScrubbedID date: egen total_exp_temp = wtmean(exp_ratio), weight(port_weight)
gen temp3 = round(total_exp_temp,.0001)
// assert round(total_exp_temp,.0001) <= round($exp_ratio_cap,.0001) | missing(total_exp_temp)
}

{ // lower glidepath
// merge in crsp data (for funds and tdfs)
drop equities tot_eq tdf_equities
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
drop if missing(date)

merge m:1 date crsp_fundno_age_TDF using "$temp/cashbond_tdf"
drop if _m == 2
drop _m
drop if missing(date)


// calculate lower guardrail violation
bys ScrubbedID date: egen tot_eq = wtmean(equities), weight(port_weight)
gen total_eq_under2 = (tot_eq < (tdf_equities / 2) & tot_eq < .)
gen lev_eq_under = tdf_equities * 2 - tot_eq
replace lev_eq_under = 0 if lev_eq_under < 0
replace lev_eq_under = 0 if missing(tot_eq)
count if lev_eq_under == .
// assert r(N) == 0

// tdf_equities / 2 = tot_eq * (1 - x) + x * tdf_equities
// tdf_equities / 2 - tot_eq = x * tdf_equities - x * tot_eq
gen total_adjust3 = (tdf_equities / 2 - tot_eq ) / (tdf_equities - tot_eq)
replace total_adjust3 = 0 if total_eq_under2 == 0
// assert !missing(total_adjust3)

preserve
keep ScrubbedID total_adjust3
rename total_adjust3 adjust_eq_under
bys ScrubbedID: keep if _n == 1
merge 1:1 ScrubbedID using "$temp/temp_adjustment1"
drop _m
save "$temp/temp_adjustment2", replace
restore


// adjust port_weights down
replace port_weight = port_weight * (1 - total_adjust3)
preserve
keep if total_adjust3 > 0
bys ScrubbedID date: keep if _n == 1
replace port_weight = total_adjust3
replace equities = tdf_equities
keep ScrubbedID date Fund crsp_fundno port_weight one_sector_overweight goldbug total_sector_overweight ///
crsp_fundno_age_TDF age_TDF tdf_exp_ratio equities tdf_equities
gen sector = 0
gen gold = 0
gen money_market = 0

replace Fund = age_TDF
replace crsp_fundno = crsp_fundno_age_TDF
gen exp_ratio = tdf_exp_ratio
// assert Fund != ""
// assert crsp_fundno != .
tempfile filler3
save "`filler3'"
restore

append using "`filler3'"

// make sure port_weight sums correctly
cap drop temp2
bys ScrubbedID date: egen temp2 = total(port_weight)
// assert round(temp2,.0001) == 1

// calculate portfolio equities
cap drop tot_eq
gen flag_eq = equities * port_weight
bys ScrubbedID date: egen tot_eq = wtmean(equities), weight(port_weight)
// assert round(tot_eq,.00001) >= (round(tdf_equities / 2, .00001)) | missing(tot_eq)
}

{ // upper glidepath
// merge in crsp data (for funds and tdfs)
drop equities tot_eq flag_eq tdf_equities
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
drop if missing(date)

merge m:1 date crsp_fundno_age_TDF using "$temp/cashbond_tdf"
drop if _m == 2
drop _m
drop if missing(date)

// calculate upper guardrail violation
bys ScrubbedID date: egen tot_eq = wtmean(equities), weight(port_weight)
gen total_eq_over2 = (tot_eq > (tdf_equities * 2) & tot_eq < .)
gen lev_eq_over = tot_eq - tdf_equities * 2
replace lev_eq_over = 0 if lev_eq_over < 0
replace lev_eq_over = 0 if missing(tot_eq)
count if lev_eq_over == .
// assert r(N) == 0

// 2 * tdf_equities = tot_eq * (1 - x) + x * tdf_equities
// 2 * tdf_equities - tot_eq = x * tdf_equities - x * tot_eq
gen total_adjust4 = (2 * tdf_equities - tot_eq) / (tdf_equities - tot_eq)
replace total_adjust4 = 0 if total_eq_over2 == 0
// assert !missing(total_adjust4)

// adjust port_weights down
replace port_weight = port_weight * (1 - total_adjust4)

preserve
keep ScrubbedID total_adjust4
rename total_adjust4 adjust_eq_over
bys ScrubbedID: keep if _n == 1
merge 1:1 ScrubbedID using "$temp/temp_adjustment2"
// must account for the fact that port_weight is scaled back when we implement each guardrail
gen adjust_non_intl = adjust_eq_over + ((1 - adjust_eq_over) * (adjust_eq_under + ((1 - adjust_eq_under) * (adjust_expense + ((1 - adjust_expense) * adjust_sector)))))
drop _m
save "$temp/temp_adjustment3", replace
restore

preserve
keep if total_adjust4 > 0
bys ScrubbedID date: keep if _n == 1
replace port_weight = total_adjust4
replace equities = tdf_equities
keep ScrubbedID date Fund crsp_fundno port_weight one_sector_overweight goldbug total_sector_overweight ///
crsp_fundno_age_TDF age_TDF tdf_exp_ratio equities tdf_equities
gen sector = 0
gen gold = 0
gen money_market = 0

replace Fund = age_TDF
replace crsp_fundno = crsp_fundno_age_TDF
gen exp_ratio = tdf_exp_ratio
// assert Fund != ""
// assert crsp_fundno != .
tempfile filler4
save "`filler4'"
restore

append using "`filler4'"

// make sure port_weight sums correctly
cap drop temp2
bys ScrubbedID date: egen temp2 = total(port_weight)
// assert round(temp2,.0001) == 1

// calculate portfolio equities
cap drop tot_eq
cap drop flag_eq
gen flag_eq = equities * port_weight
bys ScrubbedID date: egen tot_eq = wtmean(equities), weight(port_weight)
// assert round(tot_eq, .00001) <= round((tdf_equities * 2),.00001) | missing(tot_eq)

}

 // save non-intl set of guardrails
save "$temp/guard_intrm_onlytdf_joint_nonintl_temp", replace


{ // intl guardrails
// merge in equities data
drop equities tot_eq flag_eq tdf_equities
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
drop if missing(date)

merge m:1 date crsp_fundno_age_TDF using "$temp/cashbond_tdf"
drop if _m == 2
drop _m
drop if missing(date)

// merge in tdf intl_equity share
drop tdf_intl_share
merge m:1 age_TDF using "$temp/tdf_sectorfunds"
drop if _m == 2
// assert _m == 3 if inlist(date, 672,684,696)
drop _m

// calculate total international share of equities minimum
cap drop intl_share_of_equities
merge m:1 Fund using "$temp/sectorfunds"
// assert _m != 1
drop if _m != 3
drop _m
replace intl_share_of_equities = .3 if date < 672 & (inlist(Fund, "OV6M-VANG INST TR INCOME", "OV6N-VANG INST TR 2010", "OV6O-VANG INST TR 2015","OV6P-VANG INST TR 2020","OV6Q-VANG INST TR 2025") ///
| inlist(Fund, "OV6R-VANG INST TR 2030","OV6S-VANG INST TR 2035", "OV6T-VANG INST TR 2040", "OV6U-VANG INST TR 2045","OV6V-VANG INST TR 2050","OV6W-VANG INST TR 2055","OV6X-VANG INST TR 2060") ///
| inlist(Fund, "OSHO-VANG TARGET RET INC", "OKKK-VANG TARGET RET 2010",  "OSHQ-VANG TARGET RET 2015", "OKKL-VANG TARGET RET 2020", "OSHR-VANG TARGET RET 2025") ///
| inlist(Fund, "OKKM-VANG TARGET RET 2030", "OSHS-VANG TARGET RET 2035", "OKKN-VANG TARGET RET 2040", "OSHT-VANG TARGET RET 2045", "OKKO-VANG TARGET RET 2050", "OEKG-VANG TARGET RET 2055"))
replace equities = . if equities == 0
replace intl_share_of_equities = . if equities == .
replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0 & !missing(equities)
// assert equities ==. if intl_share_of_equities == .

cap drop non_missing_weight
bys ScrubbedID date: egen non_missing_weight1 = total(port_weight) if !missing(intl_share_of_equities) & !missing(equities)
bys ScrubbedID date: egen non_missing_weight = min(non_missing_weight)

// check intl weighting
cap drop intl_weight
gen intl_weight = port_weight * equities
bys ScrubbedID date: egen total_intl_share_temp2 = wtmean(intl_share_of_equities), weight(intl_weight)

cap drop tot_eq
cap drop flag_eq
bys ScrubbedID date: egen tot_eq = wtmean(equities), weight(port_weight)

gen total_adjust5 = ($intl_eq_perc * tot_eq - total_intl_share_temp2 * tot_eq) / (tdf_intl_share * tdf_equities - $intl_eq_perc * tdf_equities + $intl_eq_perc * tot_eq - total_intl_share_temp2 * tot_eq)
replace total_adjust5 = 0 if total_adjust5 < 0
replace total_adjust5 = 0 if total_intl_share_temp2 >= $intl_eq_perc & !missing(total_intl_share_temp2)
replace total_adjust5 = 0 if missing(equities) & missing(total_adjust5)

preserve
keep ScrubbedID total_adjust5
rename total_adjust5 adjust_intl
bys ScrubbedID: keep if _n == 1
merge 1:1 ScrubbedID using "$temp/temp_adjustment3"
gen adjust_joint = (adjust_non_intl * (1 - adjust_intl)) + adjust_intl
drop _m
keep ScrubbedID adjust_non_intl adjust_joint
save "$temp/onlytdf_joint_adjust", replace
restore

// adjust port_weights down
replace port_weight = port_weight * (1 - total_adjust5)

preserve
keep if total_adjust5 > 0
bys ScrubbedID date: keep if _n == 1
replace port_weight = total_adjust5
replace equities = tdf_equities
replace intl_share_of_equities = tdf_intl_share
keep ScrubbedID date Fund crsp_fundno port_weight one_sector_overweight goldbug total_sector_overweight ///
crsp_fundno_age_TDF age_TDF tdf_exp_ratio equities tdf_equities intl_share_of_equities tdf_intl_share
gen sector = 0
gen gold = 0
gen money_market = 0

replace Fund = age_TDF
replace crsp_fundno = crsp_fundno_age_TDF
gen exp_ratio = tdf_exp_ratio
// assert Fund != ""
// assert crsp_fundno != .
tempfile filler5
save "`filler5'"
restore

append using "`filler5'"

// make sure port_weight sums correctly
cap drop temp2
bys ScrubbedID date: egen temp2 = total(port_weight)
// assert round(temp2,.0001) == 1

// update weighting
replace intl_weight = port_weight * equities

// calculate portfolio equities
cap drop total_intl_share_temp2
bys ScrubbedID date: egen total_intl_share_temp2 = wtmean(intl_share_of_equities), weight(intl_weight)
// assert round(total_intl_share_temp2, .0001) >= round($intl_eq_perc, .0001)


}

{ // final checks
// merge in equities data (must remerge because of changes made in previous step)
drop equities tot_eq tdf_equities
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
drop if missing(date)

merge m:1 date crsp_fundno_age_TDF using "$temp/cashbond_tdf"
drop if _m == 2
drop _m
drop if missing(date)

// merge in tdf intl_equity share
drop tdf_intl_share
merge m:1 age_TDF using "$temp/tdf_sectorfunds"
drop if _m == 2
// assert _m == 3 if inlist(date, 672,684,696)
drop _m

// calculate portfolio equities
cap drop tot_eq
cap drop flag_eq
gen flag_eq = equities * port_weight
bys ScrubbedID date: egen tot_eq = wtmean(equities), weight(port_weight)
// assert round(tot_eq, .00001) <= round((tdf_equities * 2),.00001) | missing(tot_eq)
// assert round(tot_eq,.00001) >= (round(tdf_equities / 2, .00001)) | missing(tot_eq)


// calculate portfolio expense ratio (and fix rounding errors)
cap drop total_exp_temp temp3
bys ScrubbedID date: egen total_exp_temp = wtmean(exp_ratio), weight(port_weight)
gen temp3 = round(total_exp_temp,.0001)
// assert round(total_exp_temp,.0001) <= round($exp_ratio_cap,.0001) | missing(total_exp_temp)

// check sector funds
// assert !missing(sector)
replace sector = port_weight if sector != 0
// assert round(sector, .00001) <= round($ind_sec_lev, .00001)

}

{ // collapse in case repeatedly placed in same TDF and make sure we have all necessary variables
collapse (sum) port_weight, by(ScrubbedID Fund crsp_fundno crsp_fundno_orig date)

// merge in additional fund data
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
merge m:1 Fund using "$temp/sectorfunds"
// assert _m != 1
drop if _m != 3
drop _m

replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0
gen intl_equity_share = intl_share_of_equities*equities
// define international equities as equity funds that are > 50% international
gen intl_equity_fund = (equity == 1 & intl_share_of_equities > .5)

// merge in guardrails flags
merge m:1 ScrubbedID using "$temp/guardrails flags"
// assert _m == 3 if date == 672
drop _m
}

 // save file
save "$temp/guard_intrm_onlytdf_joint_all", replace


{ // re-save non-intl set of guardrails with correct variables
use "$temp/guard_intrm_onlytdf_joint_nonintl_temp", clear

collapse (sum) port_weight, by(ScrubbedID Fund crsp_fundno crsp_fundno_orig date)

// merge in additional fund data
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
merge m:1 Fund using "$temp/sectorfunds"
// assert _m != 1
drop if _m != 3
drop _m

replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0
gen intl_equity_share = intl_share_of_equities*equities
// define international equities as equity funds that are > 50% international
gen intl_equity_fund = (equity == 1 & intl_share_of_equities > .5)

// merge in guardrails flags
merge m:1 ScrubbedID using "$temp/guardrails flags"
// // assert _m == 3 if date == 672
drop _m


save "$temp/guard_intrm_onlytdf_joint_nonintl", replace
}

// sector fund individual guardrail
use "$temp/guard_intrm_onlytdf_sector_temp", clear

collapse (sum) port_weight, by(ScrubbedID Fund crsp_fundno crsp_fundno_orig date)

// merge in additional fund data
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
merge m:1 Fund using "$temp/sectorfunds"
assert _m != 1
drop if _m != 3
drop _m

replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0
gen intl_equity_share = intl_share_of_equities*equities
// define international equities as equity funds that are > 50% international
gen intl_equity_fund = (equity == 1 & intl_share_of_equities > .5)

// merge in guardrails flags
merge m:1 ScrubbedID using "$temp/guardrails flags"
assert _m == 3 if date == 672
drop _m

save "$temp/guard_intrm_onlytdf_sector", replace
// expense ratio individual guardrail

use "$temp/cleaning_step_one.dta", clear

keep if inlist(date, 672, 684)

// calculate portfolio expense ratio
cap drop total_exp_temp
bys ScrubbedID date: egen total_exp_temp = wtmean(exp_ratio), weight(port_weight)

// total non-missing port_weight under and over cutoff
bys ScrubbedID date: egen port_weight_under1 = total(port_weight) if !missing(exp_ratio) & exp_ratio <= $exp_ratio_cap
bys ScrubbedID date: egen port_weight_over1 = total(port_weight) if !missing(exp_ratio) & exp_ratio > $exp_ratio_cap
bys ScrubbedID date: egen port_weight_under2 = max(port_weight_under1)
bys ScrubbedID date: egen port_weight_over2 = min(port_weight_over1)
replace port_weight_under2 = 0 if missing(port_weight_under2)
replace port_weight_over2 = 0 if missing(port_weight_over2)
gen non_missing_weight = port_weight_over2 + port_weight_under2

// calculate portfolio expense ratio of funds under and over cutoff
bys ScrubbedID date: egen exp_under1 = wtmean(exp_ratio) if !missing(exp_ratio) & exp_ratio <= $exp_ratio_cap , weight(port_weight)
bys ScrubbedID date: egen exp_over1 = wtmean(exp_ratio) if !missing(exp_ratio) & exp_ratio > $exp_ratio_cap , weight(port_weight)
bys ScrubbedID date: egen exp_under2 = min(exp_under1)
bys ScrubbedID date: egen exp_over2 = min(exp_over1)
replace exp_under2 = 0 if missing(exp_under2)
replace exp_over2 = 0 if missing(exp_over2)

gen total_adjust2 = ($exp_ratio_cap - port_weight_under2/non_missing_weight * exp_under2 - port_weight_over2/non_missing_weight * exp_over2) / (tdf_exp_ratio - exp_over2)
replace total_adjust2 = 0 if total_exp_temp <= $exp_ratio_cap


replace total_adjust2 = total_adjust2 * non_missing_weight
// if adjustment is missing, it is because no adjustment is needed or all funds in a portfolio are missing expense ratios
assert total_exp_temp <= .0075 | missing(total_exp_temp) if missing(total_adjust2)
replace total_adjust2 = 0 if missing(total_adjust2) | total_adjust2 < 0

// adjust down the port_weight of those that are over cutoff (proportionate to their port_weight among those that are over cutoff)
gen share_total_over = port_weight / port_weight_over2
replace port_weight = port_weight - (share_total_over * total_adjust2) if exp_ratio > .0075 & !missing(exp_ratio)

// make sure port_weight sums correctly
bys ScrubbedID date: egen temp2 = total(port_weight)
// assert round(temp2 + total_adjust2, .0001) == 1

preserve
keep ScrubbedID total_adjust2
rename total_adjust2 adjust_exp_ratio
bys ScrubbedID: keep if _n == 1
save "$temp/onlytdf_exp_ratio_adjust", replace
restore

preserve
keep if total_adjust2 > 0
bys ScrubbedID date: keep if _n == 1
replace port_weight = total_adjust2
keep ScrubbedID date Fund crsp_fundno port_weight one_sector_overweight goldbug total_sector_overweight ///
crsp_fundno_age_TDF age_TDF tdf_exp_ratio
gen sector = 0
gen gold = 0
gen money_market = 0

replace Fund = age_TDF
replace crsp_fundno = crsp_fundno_age_TDF
gen exp_ratio = tdf_exp_ratio
assert Fund != ""
assert crsp_fundno != .
tempfile filler2
save "`filler2'"
restore

append using "`filler2'"

// make sure port_weight sums correctly
cap drop temp2
bys ScrubbedID date: egen temp2 = total(port_weight)
// assert round(temp2,.0001) == 1

// calculate portfolio expense ratio (and fix rounding errors)
cap drop total_exp_temp
bys ScrubbedID date: egen total_exp_temp = wtmean(exp_ratio), weight(port_weight)
gen temp3 = round(total_exp_temp,.0001)
// assert round(total_exp_temp,.0001) <= round($exp_ratio_cap,.0001) | missing(total_exp_temp)

{ // collapse in case repeatedly placed in same TDF and make sure we have all necessary variables
collapse (sum) port_weight, by(ScrubbedID Fund crsp_fundno crsp_fundno_orig date)

// merge in additional fund data
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
merge m:1 Fund using "$temp/sectorfunds"
assert _m != 1
drop if _m != 3
drop _m

replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0
gen intl_equity_share = intl_share_of_equities*equities
// define international equities as equity funds that are > 50% international
gen intl_equity_fund = (equity == 1 & intl_share_of_equities > .5)

// merge in guardrails flags
merge m:1 ScrubbedID using "$temp/guardrails flags"
assert _m == 3 if date == 672
drop _m
}

save "$temp/guard_intrm_onlytdf_expenseratio", replace

// lower glidepath individual guardrail

use "$temp/cleaning_step_one.dta", clear

keep if inlist(date, 672, 684)

// merge in crsp data (for funds and tdfs)
drop equities tot_eq tdf_equities
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
drop if missing(date)

merge m:1 date crsp_fundno_age_TDF using "$temp/cashbond_tdf"
drop if _m == 2
drop _m
drop if missing(date)

// calculate lower guardrail violation
gen flag_eq = equities * port_weight
bys ScrubbedID date: egen tot_eq = total(flag_eq)
gen total_eq_under2 = (tot_eq < (tdf_equities / 2) & tot_eq < .)
gen lev_eq_under = tdf_equities * 2 - tot_eq
replace lev_eq_under = 0 if lev_eq_under < 0
count if lev_eq_under == .
assert r(N) == 0

// tdf_equities / 2 = tot_eq * (1 - x) + x * tdf_equities
// tdf_equities / 2 - tot_eq = x * tdf_equities - x * tot_eq
gen total_adjust3 = (tdf_equities / 2 - tot_eq ) / (tdf_equities - tot_eq)
replace total_adjust3 = 0 if total_eq_under2 == 0
assert !missing(total_adjust3)

preserve
keep ScrubbedID total_adjust3
rename total_adjust3 adjust_eq_under
bys ScrubbedID: keep if _n == 1
save "$temp/onlytdf_eq_under_adjust", replace
restore


// adjust port_weights down
replace port_weight = port_weight * (1 - total_adjust3)
preserve
keep if total_adjust3 > 0
bys ScrubbedID date: keep if _n == 1
replace port_weight = total_adjust3
replace equities = tdf_equities
keep ScrubbedID date Fund crsp_fundno port_weight one_sector_overweight goldbug total_sector_overweight ///
crsp_fundno_age_TDF age_TDF tdf_exp_ratio equities tdf_equities
gen sector = 0
gen gold = 0
gen money_market = 0

replace Fund = age_TDF
replace crsp_fundno = crsp_fundno_age_TDF
gen exp_ratio = tdf_exp_ratio
assert Fund != ""
assert crsp_fundno != .
tempfile filler3
save "`filler3'"
restore

append using "`filler3'"

// make sure port_weight sums correctly
cap drop temp2
bys ScrubbedID date: egen temp2 = total(port_weight)
// assert round(temp2,.0001) == 1

// calculate portfolio equities
cap drop flag_eq tot_eq
gen flag_eq = equities * port_weight
bys ScrubbedID date: egen tot_eq = total(flag_eq)
// assert round(tot_eq,.00001) >= (round(tdf_equities / 2, .00001)) | missing(tot_eq)

{ // collapse in case repeatedly placed in same TDF and make sure we have all necessary variables
collapse (sum) port_weight, by(ScrubbedID Fund crsp_fundno crsp_fundno_orig date)

// merge in additional fund data
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
merge m:1 Fund using "$temp/sectorfunds"
assert _m != 1
drop if _m != 3
drop _m

replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0
gen intl_equity_share = intl_share_of_equities*equities
// define international equities as equity funds that are > 50% international
gen intl_equity_fund = (equity == 1 & intl_share_of_equities > .5)

// merge in guardrails flags
merge m:1 ScrubbedID using "$temp/guardrails flags"
assert _m == 3 if date == 672
drop _m
}

save "$temp/guard_intrm_onlytdf_equitiesunder", replace

// upper glidepath individual guardrail

use "$temp/cleaning_step_one.dta", clear

keep if inlist(date, 672, 684)

// merge in crsp data (for funds and tdfs)
drop equities tot_eq tdf_equities
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
drop if missing(date)

merge m:1 date crsp_fundno_age_TDF using "$temp/cashbond_tdf"
drop if _m == 2
drop _m
drop if missing(date)

// calculate upper guardrail violation
gen flag_eq = equities * port_weight
bys ScrubbedID date: egen tot_eq = total(flag_eq)
gen total_eq_over2 = (tot_eq > (tdf_equities * 2) & tot_eq < .)
gen lev_eq_over = tot_eq - tdf_equities * 2
replace lev_eq_over = 0 if lev_eq_over < 0
count if lev_eq_over == .
assert r(N) == 0

// 2 * tdf_equities = tot_eq * (1 - x) + x * tdf_equities
// 2 * tdf_equities - tot_eq = x * tdf_equities - x * tot_eq
gen total_adjust4 = (2 * tdf_equities - tot_eq) / (tdf_equities - tot_eq)
replace total_adjust4 = 0 if total_eq_over2 == 0
// assert !missing(total_adjust4)

// adjust port_weights down
replace port_weight = port_weight * (1 - total_adjust4)

preserve
keep ScrubbedID total_adjust4
rename total_adjust4 adjust_eq_over
bys ScrubbedID: keep if _n == 1
save "$temp/onlytdf_eq_over_adjust", replace
restore

preserve
keep if total_adjust4 > 0
bys ScrubbedID date: keep if _n == 1
replace port_weight = total_adjust4
replace equities = tdf_equities
keep ScrubbedID date Fund crsp_fundno port_weight one_sector_overweight goldbug total_sector_overweight ///
crsp_fundno_age_TDF age_TDF tdf_exp_ratio equities tdf_equities
gen sector = 0
gen gold = 0
gen money_market = 0

replace Fund = age_TDF
replace crsp_fundno = crsp_fundno_age_TDF
gen exp_ratio = tdf_exp_ratio
assert Fund != ""
assert crsp_fundno != .
tempfile filler4
save "`filler4'"
restore

append using "`filler4'"

// make sure port_weight sums correctly
cap drop temp2
bys ScrubbedID date: egen temp2 = total(port_weight)
// assert round(temp2,.0001) == 1

// calculate portfolio equities
cap drop flag_eq tot_eq
gen flag_eq = equities * port_weight
bys ScrubbedID date: egen tot_eq = total(flag_eq)
// assert round(tot_eq, .00001) <= round((tdf_equities * 2),.00001) | missing(tot_eq)

{ // collapse in case repeatedly placed in same TDF and make sure we have all necessary variables
collapse (sum) port_weight, by(ScrubbedID Fund crsp_fundno crsp_fundno_orig date)

// merge in additional fund data
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
merge m:1 Fund using "$temp/sectorfunds"
assert _m != 1
drop if _m != 3
drop _m

replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0
gen intl_equity_share = intl_share_of_equities*equities
// define international equities as equity funds that are > 50% international
gen intl_equity_fund = (equity == 1 & intl_share_of_equities > .5)

// merge in guardrails flags
merge m:1 ScrubbedID using "$temp/guardrails flags"
assert _m == 3 if date == 672
drop _m
}

save "$temp/guard_intrm_onlytdf_equitiesover", replace
// intl share of equities individual guardrail

use "$temp/cleaning_step_one.dta", clear

keep if inlist(date, 672, 684)

// merge in equities data
drop equities tot_eq tdf_equities
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
drop if missing(date)

merge m:1 date crsp_fundno_age_TDF using "$temp/cashbond_tdf"
drop if _m == 2
drop _m
drop if missing(date)

// merge in tdf intl_equity share
drop tdf_intl_share
merge m:1 age_TDF using "$temp/tdf_sectorfunds"
drop if _m == 2
assert _m == 3 if inlist(date, 672,684,696)
drop _m

// calculate total international share of equities minimum
cap drop intl_share_of_equities
merge m:1 Fund using "$temp/sectorfunds"
assert _m != 1
drop if _m != 3
drop _m
replace intl_share_of_equities = .3 if date < 672 & (inlist(Fund, "OV6M-VANG INST TR INCOME", "OV6N-VANG INST TR 2010", "OV6O-VANG INST TR 2015","OV6P-VANG INST TR 2020","OV6Q-VANG INST TR 2025") ///
| inlist(Fund, "OV6R-VANG INST TR 2030","OV6S-VANG INST TR 2035", "OV6T-VANG INST TR 2040", "OV6U-VANG INST TR 2045","OV6V-VANG INST TR 2050","OV6W-VANG INST TR 2055","OV6X-VANG INST TR 2060") ///
| inlist(Fund, "OSHO-VANG TARGET RET INC", "OKKK-VANG TARGET RET 2010",  "OSHQ-VANG TARGET RET 2015", "OKKL-VANG TARGET RET 2020", "OSHR-VANG TARGET RET 2025") ///
| inlist(Fund, "OKKM-VANG TARGET RET 2030", "OSHS-VANG TARGET RET 2035", "OKKN-VANG TARGET RET 2040", "OSHT-VANG TARGET RET 2045", "OKKO-VANG TARGET RET 2050", "OEKG-VANG TARGET RET 2055"))
replace equities = . if equities == 0
replace intl_share_of_equities = . if equities == .
replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0 & !missing(equities)
assert equities == . if intl_share_of_equities == .

cap drop non_missing_weight
bys ScrubbedID date: egen non_missing_weight1 = total(port_weight) if !missing(intl_share_of_equities) & !missing(equities)
bys ScrubbedID date: egen non_missing_weight = min(non_missing_weight)

// check intl weighting
cap drop intl_weight
gen intl_weight = port_weight * equities
gen intl_tot_1 = equities * intl_share_of_equities
bys ScrubbedID date: egen intl_tot_2 = wtmean(intl_tot_1), weight(port_weight)
bys ScrubbedID date: egen intl_tot_3 = wtmean(equities), weight(port_weight)
gen intl_tot_4 = intl_tot_2/intl_tot_3
bys ScrubbedID date: egen total_intl_share_temp2 = wtmean(intl_share_of_equities), weight(intl_weight)
// assert round(total_intl_share_temp2, .0001) == round(intl_tot_4, .0001)

cap drop flag_eq tot_eq
gen flag_eq = equities * port_weight
bys ScrubbedID date: egen tot_eq = total(flag_eq)

gen total_adjust5 = ($intl_eq_perc * tot_eq - total_intl_share_temp2 * tot_eq) / (tdf_intl_share * tdf_equities - $intl_eq_perc * tdf_equities + $intl_eq_perc * tot_eq - total_intl_share_temp2 * tot_eq)
replace total_adjust5 = 0 if total_adjust5 < 0
replace total_adjust5 = 0 if total_intl_share_temp2 >= $intl_eq_perc & !missing(total_intl_share_temp2)
replace total_adjust5 = 0 if missing(equities) & missing(total_adjust5)

preserve
keep ScrubbedID total_adjust5
rename total_adjust5 adjust_intl
bys ScrubbedID: keep if _n == 1
save "$temp/onlytdf_intl_adjust", replace
restore


// adjust port_weights down
replace port_weight = port_weight * (1 - total_adjust5)

preserve
keep if total_adjust5 > 0
bys ScrubbedID date: keep if _n == 1
replace port_weight = total_adjust5
replace equities = tdf_equities
replace intl_share_of_equities = tdf_intl_share
keep ScrubbedID date Fund crsp_fundno port_weight one_sector_overweight goldbug total_sector_overweight ///
crsp_fundno_age_TDF age_TDF tdf_exp_ratio equities tdf_equities intl_share_of_equities tdf_intl_share
gen sector = 0
gen gold = 0
gen money_market = 0

replace Fund = age_TDF
replace crsp_fundno = crsp_fundno_age_TDF
gen exp_ratio = tdf_exp_ratio
assert Fund != ""
assert crsp_fundno != .
tempfile filler5
save "`filler5'"
restore

append using "`filler5'"

// make sure port_weight sums correctly
cap drop temp2
bys ScrubbedID date: egen temp2 = total(port_weight)
// assert round(temp2,.0001) == 1

// update weighting
replace intl_weight = port_weight * equities

// calculate portfolio equities
cap drop total_intl_share_temp2
bys ScrubbedID date: egen total_intl_share_temp2 = wtmean(intl_share_of_equities), weight(intl_weight)
// assert round(total_intl_share_temp2, .0001) >= round($intl_eq_perc, .0001)

{ // collapse in case repeatedly placed in same TDF and make sure we have all necessary variables
collapse (sum) port_weight, by(ScrubbedID Fund crsp_fundno crsp_fundno_orig date)

// merge in additional fund data
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
merge m:1 Fund using "$temp/sectorfunds"
assert _m != 1
drop if _m != 3
drop _m

replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0
gen intl_equity_share = intl_share_of_equities*equities
// define international equities as equity funds that are > 50% international
gen intl_equity_fund = (equity == 1 & intl_share_of_equities > .5)

// merge in guardrails flags
merge m:1 ScrubbedID using "$temp/guardrails flags"
assert _m == 3 if date == 672
drop _m
}

save "$temp/guard_intrm_onlytdf_intl", replace

// summarize the share of each portoflio affected by guardrails


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

reshape long adjust, i(ScrubbedID) j(guardrail, string)
bys ScrubbedID: assert _N == 7

save "$temp/guardrail assets affected", replace

// filter to those that where affected by guardrail
keep if adjust != 0

collapse (mean) adjust, by(guardrail)

la var guardrail "Guardrail"
la var adjust "Average Share of Portfolio Modified for Affected Portfolios"
replace guardrail = "Joint Guardrails to TDF, All" if guardrail == "_joint"
replace guardrail = "Joint Guardrails to TDF, No Intl" if guardrail == "_non_intl"
replace guardrail = "International Share of Equities Guardrail to TDF" if guardrail == "_intl"
replace guardrail = "Maximum Equities Guardrail to TDF" if guardrail == "_eq_over"
replace guardrail = "Minimum Equities Guardrail to TDF" if guardrail == "_eq_under"
replace guardrail = "Sector Fund Guardrail to TDF" if guardrail == "_sector"
replace guardrail = "Expense Ratio Guardrail to TDF" if guardrail == "_exp_ratio"

// export excel "$output/66 - Share of Portfolio Affected By Guardrails.xlsx", replace firstrow(varlabels)

foreach file in cleaning_step_one guard_intrm_onlytdf_joint_nonintl guard_intrm_onlytdf_joint_all guard_intrm_onlytdf_intl guard_intrm_onlytdf_equitiesover guard_intrm_onlytdf_equitiesunder guard_intrm_onlytdf_sector guard_intrm_onlytdf_expenseratio {

di "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX FILE: `file' XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
// Estimate Individual Portfolio Moments

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


use "$temp/`file'.dta", clear
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

//local dt 660
//local id 4823

matrix results = [.,.,.,.]
matrix coln results = month ScrubbedID return variance

set matsize 11000

foreach dt of local dates {

matrix results = [.,.,.,.]

foreach id of local ids {

	local counter = `counter' + 1
	display "Processing observation `counter' out of `total_obs'"

qui {
	preserve

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
		restore
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


use "C:\Users\EI87\Dropbox (YLS)\Retirement Menu Design\code\STATA -- ZS\Temp\investor_mean_var_cleaning_step_one.dta", clear

collapse ret var, by(Scr)


preserve

use "$temp\investor_mean_var_cleaning_step_one.dta", replace

collapse ret var, by(Scr)

save "$temp\number_check.dta", replace

restore

append using "$temp\number_check.dta"

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

 // prepare portfolio factors
do "$home/portfolio_factor.do"

foreach var in cleaning_step_one guard_intrm_onlytdf_joint_nonintl guard_intrm_onlytdf_joint_all guard_intrm_onlytdf_intl guard_intrm_onlytdf_equitiesover guard_intrm_onlytdf_equitiesunder guard_intrm_onlytdf_sector guard_intrm_onlytdf_expenseratio {

di "`var'"
// local var = "guard_intrm_onlytdf_intl"
// local var = "cleaning_step_one"

{ // merge returns data

use "$temp/`var'.dta", clear

use "$temp/cleaning_step_one.dta", clear

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

use "$temp/joined_fund_data", replace


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

 // filter out individuals whose portfolio weights no longer sum to one (since some of their holdings did not merge with the returns data
bys ScrubbedID date caldt: egen total_weight = total(port_weight)
keep if round(total_weight,.01) == 1

gen n_funds = 1

{ // collapse funds to portfolio
collapse (sum) n_funds ret dominated_simple cash_bonds equities oth_investments sector gold money_market exp_ratio cash_share bond_share intl_equity_share ///
(first) five_years_flag goldbug one_sector_overweight total_sector_overweight total_mm_overweight, by(ScrubbedID date caldt)

assert cash_bonds != .
assert oth_investments != .
assert equities != .
assert dominated_simple != .

save "$temp/monthly_joined_collapsed", replace

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
/*
use "$temp/annreturna", replace
drop ann

sort ScrubbedID date year caldt

keep if Scr < 10

gen date2 = dofm(date)
format date2 %d
gen yr=year(date2)

bys ScrubbedID yr: asrol rf_ret, s(product) add(1)
*/
bys ScrubbedID year date: gen annualized_return = 1 + rf_ret if _n == 1
bys ScrubbedID year date: replace annualized_return = (1 + rf_ret) * annualized_return[_n-1] if _n != 1
bys ScrubbedID year date: replace annualized_return = annualized_return[_N]
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
// Nb: using arithmetic returns for risk-free because we do not want to distort the sharpe ratio

bys ScrubbedID date id_order: gen double future_monthly_return = 1 + ret[1]
by ScrubbedID date id_order: replace future_monthly_return = future_monthly_return[_n-1] * (1 + ret) if _n > 1
by ScrubbedID date id_order: replace future_monthly_return = future_monthly_return[_N] // annualized future monthly return
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
//use "$temp/five_year_rets.dta", replace


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

//	use "$temp/full_data.dta", clear

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

 // save intermediate dataset
save "$temp/collapse_nosmart_1.dta", replace
//use "$temp/collapse_nosmart_1.dta", replace

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

// export excel "$output/38 - Affected By Guardrails.xlsx", sheet("Without TDF or Non-Streamlined") replace
// putexcel set "$output/38 - Affected By Guardrails.xlsx", sheet("Without TDF or Non-Streamlined") modify
// putexcel B1:C1, merge hcenter
// putexcel A20 = "In our analysis, we implement the 75 basis point expense ratio guardrail. The rows for Any Guardrail and Any Non-International Guardrail do not include the 50 basis point guardrail."
// putexcel close


}

{ // calculate share affected by guardrails -- including smart/steady investors

use "$temp/collapse2_combined", clear

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

/*
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
*/

}

/*
Guardrails Baseline Graphs
ZRS
10/01/2019

*/


use "$temp/collapse2_combined", clear

sum if date == 672 | date == 684

gen ian_flag = (ScrubbedID == 43315)

gen graph_helper = .

{ // original graphs


use "$temp/collapse2_combined", clear

// variance of the sharpe ratio is higher in 2016
// However, if we restrict to observations with sharpe >= 0, then variance of the sharpe ratio is higher in 2017
// if we remove all outliers ( <0 | >10 ) then 2017 is lower variance in sharpe ratio
la drop date
la def date 672 "Pre-Reform" ///
684 "Post-Reform"
la val date date
estpost tabstat sharpe if sharpe >= 0 & sharpe <= 10 & inlist(date,672,684), by(date) statistics(count mean sd min max)
// esttab . using "$output/18 - Sharpe Ratio Table.rtf", cells("count(fmt(0)) mean(fmt(3)) sd(fmt(3)) min(fmt(3)) max(fmt(3))") not nostar unstack nomtitle nonumber nonote noobs label replace


}

{ // expense ratios

preserve

use "$temp/joined_fund_data", clear
keep if inlist(date,672,684)
bys Fund date: keep if _n == 1
keep if exp_ratio >= 0
replace exp_ratio = exp_ratio*100

restore


}


{ // glidepath graph
// determine average guardrail violation rate by age
use "$temp/collapse2_combined.dta", clear
keep if inlist(date,672)
keep ScrubbedID steady_pre smart
tempfile ids_used
save "`ids_used'"
use "$temp/guardrails flags", replace
merge m:1 ScrubbedID using "`ids_used'"
keep if _m == 3
drop _m
gen age = round(AgeasofNov2018 - 2,5)
replace age = 25 if age < 25
replace age = 70 if age > 70 & age < .

// determine average for each way of violating glidepath guardrail
summ total_eq_under total_eq_over total_eq_violation
summ total_eq_under total_eq_over total_eq_violation if age > 60
summ total_eq_under total_eq_over total_eq_violation if steady_pre != 1 & smart != 1

// collapse violation rate by age
collapse (mean) total_eq_violation, by(age)
la var total_eq_violation "Percent Violating Glide Path Guardrails"
replace total_eq_violation = total_eq_violation*100
save "$temp/glidepath violation by age", replace

// graph glidepath data
use "$temp/glidepath graph data", clear
merge 1:1 age using "$temp/glidepath violation by age"
assert _m == 3

}

{ // save fund type summary
use "$temp/collapse2_combined.dta", clear
keep if inlist(date,672)
keep ScrubbedID
tempfile ids_used
save "`ids_used'"

use "$temp/individual_ports.dta", clear
joinby Fund date using "$temp/fund_returns_series_crosswalk_post.dta"

// Vanguard 2010 TDF is pushed into Income TDF in 2016, so replace it with Income Fund from 2014 onward (so we will have at least 2 future years of returns data)
replace crsp_fundno = 31290 if (Fund == "OKKK-VANG TARGET RET 2010" & date <= 672 & date >= 648) | (Fund == "OV6N-VANG INST TR 2010" & date == 684)
replace crsp_fundno = 64321 if (Fund == "OKKK-VANG TARGET RET 2010" & date <= 672 & date >= 648)
replace crsp_fundno = 31290 if (Fund == "OV6N-VANG INST TR 2010" & date == 684)
replace Fund = "OSHO-VANG TARGET RET INC" if Fund == "OKKK-VANG TARGET RET 2010" & date <= 672 & date >= 648
replace Fund = "OV6M-VANG INST TR INCOME" if Fund == "OV6N-VANG INST TR 2010" & date == 684

merge m:1 ScrubbedID using "`ids_used'"
keep if _m == 3
drop _m

merge m:1 Fund using "$temp/sectorfunds"
assert _m == 3 if inlist(date,672,684)
drop if _m == 2
drop _m

merge m:1 Fund using "$temp/intl_equity_funds"
assert _m != 1
drop if _m != 3
drop _m

keep if inlist(date,672,684)
bys Fund date: keep if _n == 1
keep Fund crsp_fundno date money_market bond equity balanced tdf intl_equity sector real_estate

gen fund_type = 1 if equity == 1 & intl_equity == 0 & sector == 0
replace  fund_type = 2 if equity == 1 & intl_equity == 0 & sector == 1
replace fund_type = 3 if equity == 1 & intl_equity == 1 & sector == 0
replace fund_type = 4 if equity == 1 & intl_equity == 1 & sector == 1
replace fund_type = 5 if tdf == 1
replace fund_type = 6 if balanced == 1
replace fund_type = 7 if bond == 1
replace fund_type = 8 if real_estate == 1
replace fund_type = 9 if money_market == 1

la define fund_type 1 "Domestic Equities - Broad" ///
2 "Domestic Equities - Sector" ///
3 "International Equities - Broad" ///
4 "International Equities - Region Funds" ///
5 "TDFs" ///
6 "Balanced" ///
7 "Bonds" ///
8 "Real Estate" ///
9 "Money Market"
la val fund_type fund_type

la define date 672 "Pre-Reform" ///
684 "Post-Reform"
la val date date

save "$temp/fund_types_summary", replace
}

{ // extra data cleaning steps (filtered to only 2016)
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
keep if inlist(date, 672, 684, 696)

{ // clean variables
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
}


}

{ // reallocation fund balances table
preserve
	keep if inlist(date,672)

	save "$temp/streamlining assets affected", replace

	collapse (sum) fund_counter counter (mean) FundsHeld dropped_dollars steady_dollars, by(steady_pre)
	foreach var in FundsHeld dropped_dollars steady_dollars {
		replace `var' = round(`var',.01)
	}
	sort steady_pre
	order steady_pre counter fund_counter FundsHeld steady_dollars dropped_dollars

	la var fund_counter "No. funds"
	la var counter "No. participants"
	la var FundsHeld "Mean balance funds (USD per participant)"
	la var steady_dollars "Mean balance in non-deleted funds (USD per participant)"
	la var dropped_dollars "Mean balance in deleted funds (USD per participant)"
	la var steady_pre " "

	// export excel "$output/41 - Streamlined Reallocation.xlsx", replace firstrow(varlabels) sheet("2016 Steamlining Allocations")
restore
}

{ // individual characteristics table
preserve
	keep if inlist(date,672)

	bys ScrubbedID: keep if _n == 1

	la var n_funds "No. funds per person"

	gen sal30 = (RoundedSalary > 0 & RoundedSalary <= 30000)
	gen sal60 = (RoundedSalary > 30000 & RoundedSalary <= 60000)
	gen sal100 = (RoundedSalary > 60000 & RoundedSalary <= 100000)
	gen sal200 = (RoundedSalary > 100000 & RoundedSalary <= 200000)
	gen saltop = (RoundedSalary > 200000 & RoundedSalary < .)
	gen salmissing = (RoundedSalary == 0 | missing(RoundedSalary))

	la var sal30 "Salary 30,000 or under"
	la var sal60 "Salary 30,000-60,000"
	la var sal100 "Salary 60,000-100,000"
	la var sal200 "Salary 100,000-200,000"
	la var saltop "Salary over 200,000"
	la var salmissing "Salary data missing"


	iebaltab age20s age30s age40s age50s age60s age70s female male unknown_gender ///
	sal30 sal60 sal100 sal200 saltop salmissing n_funds, grpvar(steady_pre) ///
	rowvarlabels vce(robust) pttest onerow tblnote("Statistics are for January 2016 portfolios of individuals that appear in both 2016 and 2017." ///
	"Individuals with all assets invested in TDFs or in funds that were still available after reforms are included." ///
	"Ages are as of November 2016.") ///
//	save("$output/42 - Differences in Streamlined Individual Characteristics.xlsx") replace
restore
}

{ // merge in fund types and create table
preserve
	use "$temp/fund_types_summary", clear
	bys Fund: keep if _n == 1
	save "$temp/fundtypes1", replace
restore

preserve
	keep if inlist(date,672)

	merge m:1 Fund using "$temp/fundtypes1"
	assert _m != 1
	keep if _m == 3
	drop _m

	gen counter = 1
	duplicates drop Fund, force
	collapse (sum) counter, by(fund_type)
	egen total = sum(counter)

	collapse (sum) port_weight (mean) steady_pre, by(ScrubbedID fund_type)

	// fill in missing fund types for each person so that we calculate a correct average
	tsset ScrubbedID fund_type
	tsfill, full
	replace port_weight = 0 if missing(port_weight)
	gen temp = steady_pre
	replace temp = 0 if missing(temp)
	drop steady_pre
	bys ScrubbedID: egen steady_pre = max(temp)
	bys ScrubbedID: gen count = (_n == 1)
	drop temp

	collapse (count) count (mean) port_weight, by(fund_type steady_pre)
	replace port_weight = round(port_weight, .01)
	reshape wide count port_weight, i(fund_type) j(steady_pre)

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

	la var port_weight0 "Streamlined"
	la var port_weight1 "Non-streamlined"

	// export excel "$output/43 - Reallocation Pre-Reform Share of Assets.xlsx", firstrow(varlabels) replace

restore
}

{ // merge in dominated funds and create table
preserve
	use "$temp/fund_types_summary", clear
	bys Fund: keep if _n == 1
	save "$temp/fundtypes1", replace
restore

preserve
	keep if inlist(date,672)

	merge m:1 Fund using "$temp/fundtypes1"
	assert _m != 1
	keep if _m == 3
	drop _m

	merge m:1 Fund date crsp_fundno using "$temp/dominated.dta"
	drop if _m == 2
	replace dominated_simple = 0 if missing(dominated_simple)
	drop _m

	collapse (sum) port_weight (mean) steady_pre, by(ScrubbedID dominated_simple)

	// fill in missing fund types for each person so that we calculate a correct average
	tsset ScrubbedID dominated_simple
	tsfill, full
	replace port_weight = 0 if missing(port_weight)
	gen temp = steady_pre
	replace temp = 0 if missing(temp)
	drop steady_pre
	bys ScrubbedID: egen steady_pre = max(temp)
	bys ScrubbedID: gen count = (_n == 1)
	drop temp

	collapse (count) count (mean) port_weight, by(dominated_simple steady_pre)
	replace port_weight = round(port_weight, .001)
	reshape wide count port_weight, i(dominated_simple) j(steady_pre)

	la define dominated_simple 1 "Dominated" 0 "Not Dominated"
	la val dominated_simple dominated_simple
	decode dominated_simple, gen(dominated_string)
	drop dominated_simple
	order dominated_string
	la var dominated_string "Fund Dominated"
	set obs `=_N+1'
	gen row = _n
	summ row
	local maxrow = r(max)
	replace dominated_string = "N" if row == `maxrow'
	replace port_weight0 = count0[_n-1] if row == `maxrow'
	replace port_weight1 = count1[_n-1] if row == `maxrow'
	drop count* row

	la var port_weight0 "Streamlined"
	la var port_weight1 "Non-streamlined"

//	export excel "$output/43.1 - Reallocation Pre-Reform Share of Dominated Funds.xlsx", firstrow(varlabels) replace

restore
}

{ // set up fund mapping based on the age measure that we have
preserve
	import excel "$input/fund_transfer_crosswalk update 2019_10_23.xls", firstrow clear
	keep Fund mapped_to_target_date map_to_fund
	expand 80
	bys Fund mapped_to_target_date map_to_fund: gen age2016 = _n + 18
	replace map_to_fund = "OV6M-VANG INST TR INCOME" if age2016 > 73 & mapped_to_target_date == 1
	replace map_to_fund = "OV6N-VANG INST TR 2010" if age2016 > 68 & age2016 <= 73 & mapped_to_target_date == 1
	replace map_to_fund = "OV6O-VANG INST TR 2015" if age2016 > 63 & age2016 <= 68 & mapped_to_target_date == 1
	replace map_to_fund = "OV6P-VANG INST TR 2020" if age2016 > 58 & age2016 <= 63 & mapped_to_target_date == 1
	replace map_to_fund = "OV6Q-VANG INST TR 2025" if age2016 > 53 & age2016 <= 58 & mapped_to_target_date == 1
	replace map_to_fund = "OV6R-VANG INST TR 2030" if age2016 > 48 & age2016 <= 53 & mapped_to_target_date == 1
	replace map_to_fund = "OV6S-VANG INST TR 2035" if age2016 > 43 & age2016 <= 48 & mapped_to_target_date == 1
	replace map_to_fund = "OV6T-VANG INST TR 2040" if age2016 > 38 & age2016 <= 45 & mapped_to_target_date == 1
	replace map_to_fund = "OV6U-VANG INST TR 2045" if age2016 > 33 & age2016 <= 38 & mapped_to_target_date == 1
	replace map_to_fund = "OV6V-VANG INST TR 2050" if age2016 > 28 & age2016 <= 33 & mapped_to_target_date == 1
	replace map_to_fund = "OV6W-VANG INST TR 2055" if age2016 > 23 & age2016 <= 28 & mapped_to_target_date == 1
	replace map_to_fund = "OV6X-VANG INST TR 2060" if age2016 <= 23 & mapped_to_target_date == 1
	save "$temp/reform_mapping", replace
restore


merge m:1 Fund age2016 using "$temp/reform_mapping"
drop if _m == 2
replace mapped_to_target_date = . if date != 672
replace map_to_fund = "" if date != 672
replace _merge = . if date != 672
assert _m == 3 if date == 672
drop _m

count if date == 672 & map_to_fund == ""
assert r(N) == 0
}

{ // save 2017 port_weights
preserve
	// filter to individuals whose portfolios are streamlined
	keep if steady_pre == 0
	keep if date == 684
	keep ScrubbedID Fund port_weight
	rename port_weight port_weight17
	// collapse since some funds listed twice (but still sum to port_weight of 1)
	collapse (sum) port_weight17, by(ScrubbedID Fund)

	save "$temp/2017 simple holdings", replace
restore
}

{ // save 2018 port_weights
preserve
	// filter to individuals whose portfolios are streamlined
	keep if steady_pre == 0
	keep if date == 696
	keep ScrubbedID Fund port_weight
	rename port_weight port_weight18
	// collapse since some funds listed twice (but still sum to port_weight of 1)
	collapse (sum) port_weight18, by(ScrubbedID Fund)

	// adjust Fidelity TDF names since they are slightly different in 2018
	replace Fund = "2171-FID FREEDOM K INCOME" if Fund == "3019-FID FREEDOM INC K"
	replace Fund = "2173-FID FREEDOM K 2005" if Fund == "3020-FID FREEDOM 2005 K"
	replace Fund = "2174-FID FREEDOM K 2010" if Fund == "3021-FID FREEDOM 2010 K"
	replace Fund = "2175-FID FREEDOM K 2015" if Fund == "3022-FID FREEDOM 2015 K"
	replace Fund = "2176-FID FREEDOM K 2020" if Fund == "3023-FID FREEDOM 2020 K"
	replace Fund = "2177-FID FREEDOM K 2025" if Fund == "3024-FID FREEDOM 2025 K"
	replace Fund = "2178-FID FREEDOM K 2030" if Fund == "3025-FID FREEDOM 2030 K"
	replace Fund = "2179-FID FREEDOM K 2035" if Fund == "3026-FID FREEDOM 2035 K"
	replace Fund = "2180-FID FREEDOM K 2040" if Fund == "3027-FID FREEDOM 2040 K"
	replace Fund = "2181-FID FREEDOM K 2045" if Fund == "3028-FID FREEDOM 2045 K"
	replace Fund = "2182-FID FREEDOM K 2050" if Fund == "3029-FID FREEDOM 2050 K"
	replace Fund = "2332-FID FREEDOM K 2055" if Fund == "3030-FID FREEDOM 2055 K"

	save "$temp/2018 simple holdings", replace
restore
}

{ // flag plan defaulted 2017 portfolios
preserve
	// filter to individuals whose portfolios are streamlined
	keep if steady_pre == 0
	keep if date == 672
	replace Fund = map_to_fund
	keep ScrubbedID Fund port_weight
	collapse (sum) port_weight, by(ScrubbedID Fund)
	rename port_weight port_weight16
	merge 1:1 ScrubbedID Fund using "$temp/2017 simple holdings"

	// allow individuals that are in any TDF not to be flagged
	replace _m = 3 if (strpos(Fund,"VANG INST TR") > 0 | ///
	strpos(Fund,"FID FREEDOM") > 0)

	bys ScrubbedID: egen temp = min(_m)
	gen no_merge17 = (temp != 3)
	drop temp _m

	gen temp = ((!missing(port_weight17) & !missing(port_weight16)) | (strpos(Fund,"VANG INST TR") > 0 | ///
	strpos(Fund,"FID FREEDOM") > 0))
	bys ScrubbedID: egen same_funds = min(temp)
	drop temp

	gen plan_defaulted17 = (same_funds == 1 & no_merge17 == 0)
	tab plan_defaulted17
	gen port_diff = port_weight16 - port_weight17
	la var port_diff "Differences in Allocation (%)"
//	hist port_diff if same_funds == 1, ylabel(,nogrid) color(ebblue*.7) percent
//	graph export "$output/47 - Allocation Changes in Default Funds.png", replace

	keep ScrubbedID plan_defaulted17
	bys ScrubbedID: keep if _n == 1

	save "$temp/plan_defaulted17", replace
restore
}

{ // flag plan defaulted 2018 portfolios
preserve
	// filter to individuals whose portfolios are streamlined
	keep if steady_pre == 0
	keep if date == 672
	replace Fund = map_to_fund
	keep ScrubbedID Fund port_weight
	collapse (sum) port_weight, by(ScrubbedID Fund)
	rename port_weight port_weight16
	merge 1:1 ScrubbedID Fund using "$temp/2018 simple holdings"

	// allow individuals that are in any TDF not to be flagged
	replace _m = 3 if (strpos(Fund,"VANG INST TR") > 0 | ///
	strpos(Fund,"FID FREEDOM") > 0)

	bys ScrubbedID: egen temp = min(_m)
	gen no_merge18 = (temp != 3)
	drop temp _m

	gen temp = ((!missing(port_weight18) & !missing(port_weight16)) | (strpos(Fund,"VANG INST TR") > 0 | ///
	strpos(Fund,"FID FREEDOM") > 0))
	bys ScrubbedID: egen same_funds = min(temp)
	drop temp

	gen plan_defaulted18 = (same_funds == 1 & no_merge18 == 0)
	gen port_diff = port_weight16 - port_weight18
	la var port_diff "Differences in Allocation (%)"

	keep ScrubbedID plan_defaulted18
	bys ScrubbedID: keep if _n == 1

	save "$temp/plan_defaulted18", replace
restore
}

{ // merge in data on plan defaulted
merge m:1 ScrubbedID using "$temp/plan_defaulted17"
replace plan_defaulted17 = 2 if steady_pre == 1
drop _m

merge m:1 ScrubbedID using "$temp/plan_defaulted18"
replace plan_defaulted18 = 2 if steady_pre == 1
drop _m

preserve
	bys ScrubbedID date: gen temp1 = (_n == 1)
	drop if date == 696
	bys ScrubbedID: egen temp2 = total(temp1)
	assert temp2 == 2 if date != 696
	drop temp*
restore
}

{ // summary stats for share of portfolio streamlined
preserve

	keep if date == 672
	bys ScrubbedID: assert plan_defaulted17 == plan_defaulted17[1]
	bys ScrubbedID: assert plan_defaulted18 == plan_defaulted18[1]
	cap drop counter

	collapse (sum) dropped_dollars steady_dollars (first) plan_defaulted17, by(ScrubbedID date)

	gen counter = 1
	gen person_per_stream = dropped_dollars / (dropped_dollars + steady_dollars)
	assert !missing(person_per_stream)
	gen over_50 = (person_per_stream >= .5)
	gen over_90 = (person_per_stream >= .9)


	collapse (sum) counter dropped_dollars steady_dollars (mean) over_50 over_90, by(plan_defaulted17)
	gen per_streamlined = round(dropped_dollars / (dropped_dollars + steady_dollars), .001)
	keep plan_defaulted17 per_streamlined counter over_50 over_90

	la var plan_defaulted17 " "
	la define plan_defaulted17 0 "Streamlined, affirmative choice" ///
	1 "Streamlined, plan-defaulted" ///
	2 "Non-streamlined"
	la val plan_defaulted17 plan_defaulted17
	la var per_streamlined "Percent of assets changed by streamlining"
	la var counter "N"
	la var over_50 "Percent of investors with at least than 50% of assets changed by streamlining"
	la var over_90 "Percent of investors with at least than 90% of assets changed by streamlining"

//	export excel "$output/63 - Share of Portfolio Streamlined.xlsx", replace firstrow(varlabels) keepcellfmt

restore
}

{ // share plan defaulted in each year
preserve
	gen temp = (date == 696)
	bys ScrubbedID: egen present_2018 = max(temp)
	drop temp

	keep if date == 672 & present_2018 == 1

	// filter to one observation per person
	bys ScrubbedID: keep if _n == 1

	gen affirmative17 = (plan_defaulted17 == 0)
	gen defaulted17 = (plan_defaulted17 == 1)
	gen non17 = (plan_defaulted17 == 2)
	gen affirmative18 = (plan_defaulted18 == 0)
	gen defaulted18 = (plan_defaulted18 == 1)
	gen non18 = (plan_defaulted18 == 2)

	collapse (mean) affirmative17 affirmative18 defaulted17 defaulted18 non17 non18
	gen row = _n
	reshape long affirmative defaulted non, i(row) j(date)
	replace date = 2000 + date
	drop row

	gen share_of_streamlined = defaulted / (defaulted + affirmative)

	la var affirmative "Streamlined, affirmative choice"
	la var defaulted "Streamlined, plan-defaulted"
	la var non "Non-streamlined"
	la var date "Date"
	la var share_of_streamlined "Share of streamlined that are in plan default funds"

	order date share_of_streamlined affirmative defaulted non

//	export excel "$output/64 - Streamlined Defaults 2017-2018.xlsx", sheet("Ignoring Share Class") replace firstrow(varlabels) keepcellfmt

restore
}

{ // add summary stats for share of portfolio streamlined (a row for all streamlined individuals
preserve
	keep if date == 672
	replace plan_defaulted17 = 1 if plan_defaulted17 == 0
	collapse (sum) dropped_dollars steady_dollars (first) plan_defaulted17, by(ScrubbedID date)

	gen counter = 1
	gen person_per_stream = dropped_dollars / (dropped_dollars + steady_dollars)
	assert !missing(person_per_stream)
	gen over_50 = (person_per_stream >= .5)
	gen over_90 = (person_per_stream >= .9)


	collapse (sum) counter dropped_dollars steady_dollars (mean) over_50 over_90, by(plan_defaulted17)
	gen per_streamlined = round(dropped_dollars / (dropped_dollars + steady_dollars), .001)
	keep plan_defaulted17 per_streamlined counter over_50 over_90

	la var plan_defaulted17 " "
	la define plan_defaulted17 1 "Streamlined, all" ///
	2 "Non-streamlined"
	la val plan_defaulted17 plan_defaulted17
	la var per_streamlined "Percent of assets changed by streamlining"
	la var counter "N"
	la var over_50 "Percent of investors with at least than 50% of assets changed by streamlining"
	la var over_90 "Percent of investors with at least than 90% of assets changed by streamlining"

	keep if plan_defaulted17 == 1
	assert _N == 1

	// putexcel set "$output/63 - Share of Portfolio Streamlined.xlsx", modify
	//
	// putexcel A6 = ("Streamlined, all")
	// putexcel B6 = (counter[1])
	// putexcel C6 = (over_50[1])
	// putexcel D6 = (over_90[1])
	// putexcel E6 = (per_streamlined[1])
	//
	// putexcel close

restore
}

{ // Difference in Mean Allocation Post-Pre Reform
preserve

	keep if inlist(date,672,684)

	merge m:1 Fund using "$temp/fundtypes1"
	assert _m != 1
	keep if _m == 3
	drop _m

	collapse (sum) port_weight (mean) plan_defaulted17, by(ScrubbedID fund_type date)

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
	gen temp = plan_defaulted17
	replace temp = 0 if missing(temp)
	drop plan_defaulted17
	bys ScrubbedID: egen plan_defaulted17 = max(temp)
	drop temp id

	sort ScrubbedID fund_type date
	by ScrubbedID fund_type: replace port_weight = port_weight - port_weight[_n-1] if _n == 2
	rename port_weight delta_port_weight
	by ScrubbedID fund_type: keep if _n == 2
	assert date == 684
	drop date
	bys ScrubbedID: gen count = (_n == 1)

	forvalues i = 1/9 {
		forvalues j = 0/2 {
			di "t-test for fund type `i' and plan defaulted `j'"
			ttest delta_port_weight == 0 if plan_defaulted17 == `j' & fund_type == `i'
			local p_`i'_`j' = r(p)
			di  "p_`i'_`j' is `p_`i'_`j''"
		}
	}

	collapse (count) count (mean) delta_port_weight, by(fund_type plan_defaulted17)
	replace delta_port_weight = round(delta_port_weight, .001)
	reshape wide count delta_port_weight, i(fund_type) j(plan_defaulted17)

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
	replace delta_port_weight2 = count2[_n-1] if row == `maxrow'
	tostring delta_port_weight*, replace force

	forvalues i = 0/2 {
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
	/*
	forvalues i = 1/9 {
		forvalues j = 0/2 {
			replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .1
			replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .05
			replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .01
		}
	}
	*/
	drop fund_type
	la var delta_port_weight0 "Streamlined, affirmative choice"
	la var delta_port_weight1 "Streamlined, plan-defaulted"
	la var delta_port_weight2 "Non-streamlined"

//	export excel "$output/44 - Difference in Mean Allocation Post-Pre Reform.xlsx", firstrow(varlabels) replace


restore
}

{ // Difference in Mean Allocation Post (2018) - Pre Reform
preserve

	keep if inlist(date,672,696)

	// adjust fund names for merge
	replace Fund = "2171-FID FREEDOM K INCOME" if Fund == "3019-FID FREEDOM INC K"
	replace Fund = "2173-FID FREEDOM K 2005" if Fund == "3020-FID FREEDOM 2005 K"
	replace Fund = "2174-FID FREEDOM K 2010" if Fund == "3021-FID FREEDOM 2010 K"
	replace Fund = "2175-FID FREEDOM K 2015" if Fund == "3022-FID FREEDOM 2015 K"
	replace Fund = "2176-FID FREEDOM K 2020" if Fund == "3023-FID FREEDOM 2020 K"
	replace Fund = "2177-FID FREEDOM K 2025" if Fund == "3024-FID FREEDOM 2025 K"
	replace Fund = "2178-FID FREEDOM K 2030" if Fund == "3025-FID FREEDOM 2030 K"
	replace Fund = "2179-FID FREEDOM K 2035" if Fund == "3026-FID FREEDOM 2035 K"
	replace Fund = "2180-FID FREEDOM K 2040" if Fund == "3027-FID FREEDOM 2040 K"
	replace Fund = "2181-FID FREEDOM K 2045" if Fund == "3028-FID FREEDOM 2045 K"
	replace Fund = "2182-FID FREEDOM K 2050" if Fund == "3029-FID FREEDOM 2050 K"
	replace Fund = "2332-FID FREEDOM K 2055" if Fund == "3030-FID FREEDOM 2055 K"

	merge m:1 Fund using "$temp/fundtypes1"
	assert _m != 1
	keep if _m == 3
	drop _m

	collapse (sum) port_weight (mean) plan_defaulted18, by(ScrubbedID fund_type date)

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
	gen temp = plan_defaulted18
	replace temp = 0 if missing(temp)
	drop plan_defaulted18
	bys ScrubbedID: egen plan_defaulted18 = max(temp)
	drop temp id

	sort ScrubbedID fund_type date
	by ScrubbedID fund_type: replace port_weight = port_weight - port_weight[_n-1] if _n == 2
	rename port_weight delta_port_weight
	by ScrubbedID fund_type: keep if _n == 2
	assert date == 696
	drop date
	bys ScrubbedID: gen count = (_n == 1)

	forvalues i = 1/9 {
		forvalues j = 0/2 {
			di "t-test for fund type `i' and plan defaulted `j'"
			ttest delta_port_weight == 0 if plan_defaulted18 == `j' & fund_type == `i'
			local p_`i'_`j' = r(p)
			di  "p_`i'_`j' is `p_`i'_`j''"
		}
	}

	collapse (count) count (mean) delta_port_weight, by(fund_type plan_defaulted18)
	replace delta_port_weight = round(delta_port_weight, .001)
	reshape wide count delta_port_weight, i(fund_type) j(plan_defaulted18)

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
	replace delta_port_weight2 = count2[_n-1] if row == `maxrow'
	tostring delta_port_weight*, replace force

	forvalues i = 0/2 {
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
		forvalues j = 0/2 {
			replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .1
			replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .05
			replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .01
		}
	}

	drop fund_type
	la var delta_port_weight0 "Streamlined, affirmative choice"
	la var delta_port_weight1 "Streamlined, plan-defaulted"
	la var delta_port_weight2 "Non-streamlined"

//	export excel "$output/44.1  - Difference in Mean Allocation 2016-2018.xlsx", firstrow(varlabels) replace


restore
}

{ // reallocation regressions
// this analysis includes individuals that were entirely in TDFs/steady funds before reform

use "$temp/collapse2_combined.dta", replace
keep if inlist(date,672,684,991)
sort ScrubbedID date
merge m:1 ScrubbedID using "$temp/plan_defaulted17"
replace plan_defaulted17 = 2 if steady_pre == 1

// make sure dates are in the correct order
assert date[1] == 672
assert date[2] == 684
// assert date[3] == 991

local vars = "equities dominated_simple exp_ratio n_funds"

foreach var in `vars' {
	di "`var'"
	gen `var'_prepost = `var'[_n+1] - `var' if date == 672 & ScrubbedID == ScrubbedID[_n+1]
	gen `var'_preguardrails = `var'[_n+2] - `var' if date == 672 & ScrubbedID == ScrubbedID[_n+2]
	//drop `var'
}
keep if date == 672

// generate and label variables for regression
la var equities_prepost "Delta % Equities Post Minus Pre"
la var equities_preguardrails "Delta % Equities Guardrails Minus Pre"
la var dominated_simple_prepost "Delta % Dominated Funds Post Minus Pre"
la var dominated_simple_preguardrails "Delta % Dominated Funds Guardrails Minus Pre"
la var exp_ratio_prepost "Delta Expense Ratio Post Minus Pre"
la var exp_ratio_preguardrails "Delta Expense Ratio Guardrails Minus Pre"
la var n_funds_prepost "Delta No. Funds Post Minus Pre"
la var n_funds_preguardrails "Delta No. Funds Guardrails Minus Pre"

gen sal30 = (RoundedSalary > 0 & RoundedSalary <= 30000)
gen sal60 = (RoundedSalary > 30000 & RoundedSalary <= 60000)
gen sal100 = (RoundedSalary > 60000 & RoundedSalary <= 100000)
gen sal200 = (RoundedSalary > 100000 & RoundedSalary <= 200000)
gen saltop = (RoundedSalary > 200000 & RoundedSalary < .)
gen salmissing = (RoundedSalary == 0 | missing(RoundedSalary))

la var sal30 "Salary 30,000 or under"
la var sal60 "Salary 30,000-60,000"
la var sal100 "Salary 60,000-100,000"
la var sal200 "Salary 100,000-200,000"
la var saltop "Salary over 200,000"
la var salmissing "Salary data missing"

gen female = (Gender == "F")
gen male = (Gender == "M")
gen unknown_gender = (male == 0 & female == 0)

gen age2016 = age2018 - 2
la var age2016 "Age as of 2016"
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

gen age_2 = age2016^2
la var age_2 "Age-squared"

gen total_assets_100 = total_assets/100000
la var total_assets_100 "Total assets (100,000 USD)"

la define plan_defaulted17 0 "Streamlined, affirmative choice" ///
1 "Streamlined, plan-defaulted"	///
2 "Non-streamlined"
la val plan_defaulted17 plan_defaulted17

gen streamlined_pd = (plan_defaulted17 == 1)
la var streamlined_pd "Streamlined, plan-defaulted"
gen streamlined_npd = (plan_defaulted17 == 0)
la var streamlined_npd "Streamlined, non-plan-defaulted"

rename dominated_simple_preguardrails dom_simple_preguard


// regression output
outreg2 using "$temp/48 - Reallocation Regressions.xls", replace skip
local vars = "equities_prepost equities_preguardrails dominated_simple_prepost dom_simple_preguard exp_ratio_prepost exp_ratio_preguardrails n_funds_prepost n_funds_preguardrails"
local n_vars : word count `vars'
local controls streamlined_pd streamlined_npd age2016 age_2 female unknown_gender total_assets_100 sal60 sal100 sal200 saltop salmissing
forvalues i = 1/`n_vars' {
	local var : word `i' of `vars'
	local lab: variable label `var'
	di "`var'"
	regress `var' `controls', robust
	outreg2 using "$temp/48 - Reallocation Regressions.xls", append ctitle(`lab') label stats(coef pval) drop(equities_prepost equities_preguardrails dominated_simple_prepost dominated_simple_preguardrails exp_ratio_prepost exp_ratio_preguardrails n_funds_prepost n_funds_preguardrails)

	test streamlined_pd == streamlined_npd
	local `var'_p = round(r(p),.001)
	local `var'_mean = round(_b[streamlined_pd] - _b[streamlined_npd],.00001)

}

/// must resave as .xlsx
preserve
	import delimited "$temp\48 - Reallocation Regressions.txt", clear
	drop v1
	replace v2 = "" if _n == 2
	drop if _n == 4 | _n == 5
	replace v2 = "N" if _n == 31
	replace v2 = "R-Squared" if _n == 32
//	export excel "$output\48 - Reallocation Regressions.xlsx", replace
restore

// add in variable means
// putexcel set "$output/48 - Reallocation Regressions.xlsx", modify sheet("Sheet1")
// putexcel B1 = "Mean"
// putexcel C1 = "(1)"
// putexcel D1 = "(2)"
// putexcel E1 = "(3)"
// putexcel F1 = "(4)"
// putexcel G1 = "(5)"
// putexcel H1 = "(6)"
// putexcel I1 = "(7)"
// putexcel J1 = "(8)"

local controls "streamlined_pd streamlined_npd age2016 age_2 female unknown_gender total_assets_100 sal60 sal100 sal200 saltop salmissing"
local n_controls : word count `controls'
di `n_controls'
forvalues i = 1/`n_controls' {
	di `i'
	local var : word `i' of `controls'
	di "`var'"
	local row = `i' * 2 + 2
	di `row'
	summ `var'
	local mean = r(mean)
	putexcel B`row' = `mean'
}

putexcel A35 = "Diff(β(Streamlined, plan-defaulted) – β(Streamlined, non-plan-defaulted))"
putexcel A36 = "Mean of dep var"
local letters "C D E F G H I J"
local vars = "equities_prepost equities_preguardrails dominated_simple_prepost dom_simple_preguard exp_ratio_prepost exp_ratio_preguardrails n_funds_prepost n_funds_preguardrails"
local n_vars : word count `vars'
forvalues i = 1/`n_vars' {
	local var : word `i' of `vars'
	local letter : word `i' of `letters'
	local stars = ""
	di ``var'_p'
	if (``var'_p' < .1) {
		local stars = "*"
	}
	if (``var'_p' < .05) {
		local stars = "**"
	}
	if (``var'_p' < .01) {
		local stars = "***"
	}
	putexcel `letter'35 = "``var'_mean'`stars'"
	summ `var'
	local dep_mean = round(r(mean), .001)
	putexcel `letter'36 = "`dep_mean'"
}

}


// EI

/*
Guardrails Overweighting Tables
ZRS
11/13/2019

Updates:
-- changing to share less than x% for most tables
*/

{ // individual fund allocation percentiles
use "$temp/collapse2_combined.dta", clear
keep if inlist(date,672)
keep ScrubbedID
tempfile ids_used
save "`ids_used'"

use "$temp/individual_ports.dta", clear
joinby Fund date using "$temp/fund_returns_series_crosswalk_post.dta"

merge m:1 ScrubbedID using "`ids_used'"
keep if _m == 3
drop _m

gen counter = 1

foreach date in 672 684 {
	di "`date'"
	if `date' == 672 {
		local sheet = "Pre Reform"
		di "`sheet'"
	}
	else {
		local sheet = "Post Reform"
		di "`sheet'"
	}
	preserve
		keep if date == `date'
		collapse (count) count = counter (p1) p1 = port_weight (p5) p5 = port_weight (p10) p10 = port_weight (p25) p25 = port_weight ///
		(p50) p50 = port_weight (p75) p75 = port_weight (p90) p90 = port_weight (p95) p95 = port_weight ///
		(p99) p99 = port_weight, by(Fund)

//		export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(variables) sheet("`sheet'") sheetreplace keepcellfmt
	restore
}


}

{ // bonds by age

use "$temp/collapse2_combined.dta", clear

gen counter = 1
gen age = age2018 - (2018-year)

gen age_bin = 1 if age < 30
replace age_bin = 2 if age >= 30 & age < 40
replace age_bin = 3 if age >= 40 & age < 50
replace age_bin = 4 if age >= 50 & age < 60
replace age_bin = 5 if age >= 60 & age < 70
replace age_bin = 6 if age >= 70 & age < .
keep if inlist(date, 684, 672, 990)

// create variables for weight over x%
gen share_any = cash_bonds == 0
gen share_10_under = cash_bonds < .10
gen share_20_under = cash_bonds < .20
gen share_30_under = cash_bonds < .30
gen share_40_under = cash_bonds < .40
gen share_50_under = cash_bonds < .50
gen share_60_under = cash_bonds < .60
gen share_70_under = cash_bonds < .70
gen share_80_under = cash_bonds < .80
gen share_90_under = cash_bonds < .90
gen share_100 = cash_bonds < 1

	// collapse to summarize share of investors over x% in each fund
collapse (mean) share_*, by(date age_bin)

la define age_bin 1 "Under 30" ///
2 "30-39" ///
3 "40-49" ///
4 "50-59" ///
5 "60-69" ///
6 "70+"
la val age_bin age_bin
la var age_bin "Age"

la var share_any "Share of investors with no cash & bonds"
la var share_10_under "Share of investors with less than 10% of assets in cash & bonds"
la var share_20_under "Share of investors with less than 20% of assets in cash & bonds"
la var share_30_under "Share of investors with less than 30% of assets in cash & bonds"
la var share_40_under "Share of investors with less than 40% of assets in cash & bonds"
la var share_50_under "Share of investors with less than 50% of assets in cash & bonds"
la var share_60_under "Share of investors with less than 60% of assets in cash & bonds"
la var share_70_under "Share of investors with less than 70% of assets in cash & bonds"
la var share_80_under "Share of investors with less than 80% of assets in cash & bonds"
la var share_90_under "Share of investors with less than 90% of assets in cash & bonds"
la var share_100 "Share of investors with less than 100% of assets in cash & bonds"
sort age_bin date
decode date, gen(date2)
la var date2 "Date"
drop date
keep age_bin date2 share_any share_10_under share_20_under share_30_under share_40_under share_50_under
order age_bin date2 share_*

// export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Cash_Bond Age") sheetreplace keepcellfmt

}

{ // equities by age -- with solely tdf investors

use "$temp/collapse2_combined.dta", clear

gen counter = 1
gen age = age2018 - (2018-year)

gen age_bin = 1 if age < 30
replace age_bin = 2 if age >= 30 & age < 40
replace age_bin = 3 if age >= 40 & age < 50
replace age_bin = 4 if age >= 50 & age < 60
replace age_bin = 5 if age >= 60 & age < 70
replace age_bin = 6 if age >= 70 & age < .
keep if inlist(date, 684, 672, 990)
keep if inlist(date,672)


// create variables for weight over x%
gen share_any = round(equities,.01) == 0
gen share_10_under = equities < .10
gen share_20_under = equities < .20
gen share_30_under = equities < .30
gen share_40_under = equities < .40
gen share_50_under = equities < .50
gen share_60_under = equities < .60
gen share_70_under = equities < .70
gen share_80_over = equities > .80 if equities < .
gen share_90_over = equities > .90 if equities < .
gen share_95_over = equities > .95 if equities < .

// collapse to summarize share of investors over x% in each fund
collapse (mean) share_*, by(date age_bin)

la define age_bin 1 "Under 30" ///
2 "30-39" ///
3 "40-49" ///
4 "50-59" ///
5 "60-69" ///
6 "70+"
la val age_bin age_bin
la var age_bin "Age"
la var share_any "Share of investors with no equities"
la var share_10_under "Share of investors with less than 10% of assets in equities"
la var share_20_under "Share of investors with less than 20% of assets in equities"
la var share_30_under "Share of investors with less than 30% of assets in equities"
la var share_40_under "Share of investors with less than 40% of assets in equities"
la var share_50_under "Share of investors with less than 50% of assets in equities"
la var share_60_under "Share of investors with less than 60% of assets in equities"
la var share_70_under "Share of investors with less than 70% of assets in equities"
la var share_80_over "Share of investors with over 80% of assets in equities"
la var share_90_over "Share of investors with over 90% of assets in equities"
la var share_95_over "Share of investors with over 95% of assets in equities"
sort age_bin date
decode date, gen(date2)
la var date2 "Date"
drop date
keep age_bin date2 share_any share_10_under share_20_under share_80_over share_90_over share_95_over
order age_bin date2 share_*

export excel using "$output/chapter4.xlsx" , firstrow(varlabels) sheet("4.6") sheetreplace keepcellfmt

}

{ // equities by age -- without solely tdf investors

use "$temp/collapse2_combined.dta", clear

// filter out individuals solely in one tdf
drop if smart == 1

gen counter = 1
gen age = age2018 - (2018-year)

gen age_bin = 1 if age < 30
replace age_bin = 2 if age >= 30 & age < 40
replace age_bin = 3 if age >= 40 & age < 50
replace age_bin = 4 if age >= 50 & age < 60
replace age_bin = 5 if age >= 60 & age < 70
replace age_bin = 6 if age >= 70 & age < .
keep if inlist(date, 684, 672, 990)
keep if inlist(date,672)

// create variables for weight over x%
gen share_any = round(equities,.01) == 0
gen share_10_under = equities < .10
gen share_20_under = equities < .20
gen share_30_under = equities < .30
gen share_40_under = equities < .40
gen share_50_under = equities < .50
gen share_60_under = equities < .60
gen share_70_under = equities < .70
gen share_80_over = equities > .80 if equities < .
gen share_90_over = equities > .90 if equities < .
gen share_95_over = equities > .95 if equities < .

// collapse to summarize share of investors over x% in each fund
collapse (mean) share_*, by(date age_bin)

la define age_bin 1 "Under 30" ///
2 "30-39" ///
3 "40-49" ///
4 "50-59" ///
5 "60-69" ///
6 "70+"
la val age_bin age_bin
la var age_bin "Age"
la var share_any "Share of investors with no equities"
la var share_10_under "Share of investors with less than 10% of assets in equities"
la var share_20_under "Share of investors with less than 20% of assets in equities"
la var share_30_under "Share of investors with less than 30% of assets in equities"
la var share_40_under "Share of investors with less than 40% of assets in equities"
la var share_50_under "Share of investors with less than 50% of assets in equities"
la var share_60_under "Share of investors with less than 60% of assets in equities"
la var share_70_under "Share of investors with less than 70% of assets in equities"
la var share_80_over "Share of investors with over 80% of assets in equities"
la var share_90_over "Share of investors with over 90% of assets in equities"
la var share_95_over "Share of investors with over 95% of assets in equities"
sort age_bin date
decode date, gen(date2)
la var date2 "Date"
drop date
keep age_bin date2 share_any share_10_under share_20_under share_80_over share_90_over share_95_over
order age_bin date2 share_*


// export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Equities Age No Sole TDFs") sheetreplace keepcellfmt

}

{ // money market by age

use "$temp/collapse2_combined.dta", clear

gen counter = 1
gen age = age2018 - (2018-year)

gen age_bin = 1 if age < 30
replace age_bin = 2 if age >= 30 & age < 40
replace age_bin = 3 if age >= 40 & age < 50
replace age_bin = 4 if age >= 50 & age < 60
replace age_bin = 5 if age >= 60 & age < 70
replace age_bin = 6 if age >= 70  & age < .

keep if inlist(date, 684, 672, 990)

// create variables for weight over x%
gen share_any = money_market == 0
gen share_10_under = money_market < .10
gen share_20_under = money_market < .20
gen share_30_under = money_market < .30
gen share_40_under = money_market < .40
gen share_50_under = money_market < .50
gen share_60_under = money_market < .60
gen share_70_under = money_market < .70
gen share_80_under = money_market < .80
gen share_90_under = money_market < .90
gen share_100 = money_market < 1

	// collapse to summarize share of investors over x% in each fund
collapse (mean) share_*, by(date age_bin)


la define age_bin 1 "Under 30" ///
2 "30-39" ///
3 "40-49" ///
4 "50-59" ///
5 "60-69" ///
6 "70+"
la val age_bin age_bin

la var age_bin "Age"
la var share_any "Share of investors with no money market funds"
la var share_10_under "Share of investors with less than 10% of assets in money market funds"
la var share_20_under "Share of investors with less than 20% of assets in money market funds"
la var share_30_under "Share of investors with less than 30% of assets in money market funds"
la var share_40_under "Share of investors with less than 40% of assets in money market funds"
la var share_50_under "Share of investors with less than 50% of assets in money market funds"
la var share_60_under "Share of investors with less than 60% of assets in money market funds"
la var share_70_under "Share of investors with less than 70% of assets in money market funds"
la var share_80_under "Share of investors with less than 80% of assets in money market funds"
la var share_90_under "Share of investors with less than 90% of assets in money market funds"
la var share_100 "Share of investors with less than 100% of assets in money market funds"
sort age_bin date
decode date, gen(date2)
la var date2 "Date"
drop date
keep age_bin date2 share_any share_10_under share_20_under share_30_under share_40_under share_50_under
order age_bin date2 share_*

// export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Money Market Age") sheetreplace keepcellfmt

}

{ // gold bugs graphs (note that these variables are only flagged for 2016 funds)
// Eni edited
use "$temp/collapse2_combined.dta", clear
gen graph_helper = .

summ goldbug if date == 672

keep if inlist(date,672,684)

use "$temp/collapse2_combined.dta", clear
gen graph_helper = .

summ goldbug if date == 672

keep if inlist(date,672,684,990,991)

// arrow graph
keep if inlist(date, 672, 684)
keep if goldbug16 == 1
keep ScrubbedID date return_used var_used

reshape wide return_used var_used, i(ScrubbedID) j(date)


}


{ // flagging joint nonintl guardrails with decreases in Sharpe ratios
use "$temp/collapse2_combined.dta", clear
gen graph_helper = .

keep if inlist(date, 672, 991)

gen sharpe1 = sharpe if date == 672
gen sharpe2 = sharpe if date == 991
bys ScrubbedID: egen sharpe672 = max(sharpe1)
bys ScrubbedID: egen sharpe991 = max(sharpe2)
// assert !missing(sharpe672) & !missing(sharpe991)
gen decrease_and_affected = sharpe991 < sharpe672 & guardrail_not_intl == 1
gen increase_and_affected = sharpe991 > sharpe672 & guardrail_not_intl == 1

keep if inlist(date,672)

// filter to a random subset of those with an increase and display in the graph as two groups (groups equal in size to the decrease)
// first seed chosen by random number generator and set for consistency
keep if guardrail_not_intl == 1
keep if decrease_and_affected == 1 | increase_and_affected == 1

set seed 522268
gen rand =  runiformint(0, 100000000)
// bys rand: assert _N == 1

count if decrease_and_affected == 1
local count = r(N)
sort rand
bys decrease_and_affected: gen rand2 = _n
keep if decrease_and_affected == 1 | (increase_and_affected == 1 & rand2 <= `count' * 2)
gen increase_group = (rand2 <= `count') if increase_and_affected == 1

}

{ // weighting of asset categories
use "$temp/collapse2_combined.dta", clear

keep ScrubbedID date cash_bonds intl_equity_share domestic_equity_share oth_investments
keep if inlist(date, 684, 672)

rename intl_equity_share share_intl_equities
rename domestic_equity_share share_domestic_equities
rename cash_bonds share_cash_bonds
rename oth_investments share_oth_investments

reshape long share, i(ScrubbedID date) j(investment_type, string)
replace investment_type = "Cash/Bonds" if investment_type == "_cash_bonds"
replace investment_type = "International Equities" if investment_type == "_intl_equities"
replace investment_type = "Domestic Equities" if investment_type == "_domestic_equities"
replace investment_type = "Other" if investment_type == "_oth_investments"
replace share = 0 if missing(share)

// create variables for weight over x%
gen share_any = share == 0
gen share_10_under = share < .10
gen share_20_under = share < .20
gen share_30_under = share < .30
gen share_40_under = share < .40
gen share_50_under = share < .50
gen share_60_under = share < .60
gen share_70_under = share < .70
gen share_80_under = share < .80
gen share_90_under = share < .90
gen share_100 = share < 1

// collapse to summarize share of investors over x% in each fund
collapse (mean) share_*, by(date investment_type)

la var share_any "Share of investors with no assets in category"
la var share_10_under "Share of investors with less than 10% of assets in category"
la var share_20_under "Share of investors with less than 20% of assets in category"
la var share_30_under "Share of investors with less than 30% of assets in category"
la var share_40_under "Share of investors with less than 40% of assets in category"
la var share_50_under "Share of investors with less than 50% of assets in category"
la var share_60_under "Share of investors with less than 60% of assets in category"
la var share_70_under "Share of investors with less than 70% of assets in category"
la var share_80_under "Share of investors with less than 80% of assets in category"
la var share_90_under "Share of investors with less than 90% of assets in category"
la var share_100 "Share of investors with less than 100% of assets in category"
sort investment_type date
decode date, gen(date2)
la var date2 "Date"
la var investment_type "Investment Type"
drop date
keep investment_type date2 share_any share_10_under share_20_under share_30_under share_40_under share_50_under
order investment_type date2 share_*

// export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Investment Category") sheetreplace keepcellfmt

}

{ // weighting of intl equities among equities -- excluding investors entirely in TDFs or non-streamlined funds

use "$temp/collapse_nosmart_combined.dta", clear
keep if inlist(date,672)
keep ScrubbedID
tempfile ids_used
save "`ids_used'"

use "$temp/guard_intrm_onlytdf_joint_nonintl_fulldata.dta", clear
keep ScrubbedID date Fund port_weight intl_equity_share equities
keep if date == 672
replace date = 673
tempfile temp_guardrail
save "`temp_guardrail'"

use "$temp/full_data.dta", clear
keep ScrubbedID date Fund port_weight intl_equity_share equities
append using  "`temp_guardrail'"
merge m:1 ScrubbedID using "`ids_used'"
keep if _m == 3
drop _m

keep if inlist(date,672,684,673)
la define date 672 "Pre-Reform" ///
684 "Post-Reform" ///
673 "Guardrails"
la val date date
bys ScrubbedID date: egen total_equity = total(equities)
bys ScrubbedID date: egen total_intl = total(intl_equity_share)
gen intl_share_of_equities = total_intl/total_equity

bys ScrubbedID date: keep if _n == 1
keep ScrubbedID date intl_share_of_equities
keep if intl_share_of_equities < .

// create variables for weight over x%
gen share_any = intl_share_of_equities == 0
gen share_10_under = intl_share_of_equities < .10
gen share_20_under = intl_share_of_equities < .20
gen share_30_under = intl_share_of_equities < .30
gen share_40_under = intl_share_of_equities < .40
gen share_50_under = intl_share_of_equities < .50
gen share_60_under = intl_share_of_equities < .60
gen share_70_under = intl_share_of_equities < .70
gen share_80_under = intl_share_of_equities < .80
gen share_90_under = intl_share_of_equities < .90
gen share_100 = intl_share_of_equities < 1

// collapse to summarize share of investors over x% in each fund
collapse (mean) share_*, by(date)

la var share_any "Share of investors with no international equities"
la var share_10_under "Share of investors with less than 10% of equities in international equities"
la var share_20_under "Share of investors with less than 20% of equities in international equities"
la var share_30_under "Share of investors with less than 30% of equities in international equities"
la var share_40_under "Share of investors with less than 40% of equities in international equities"
la var share_50_under "Share of investors with less than 50% of equities in international equities"
la var share_60_under "Share of investors with less than 60% of equities in international equities"
la var share_70_under "Share of investors with less than 70% of equities in international equities"
la var share_80_under "Share of investors with less than 80% of equities in international equities"
la var share_90_under "Share of investors with less than 90% of equities in international equities"
la var share_100 "Share of investors with less than 100% of equities in international equities"
sort date
decode date, gen(date2)
la var date2 "Date"
drop date
keep date2 share_any share_10_under share_20_under share_30_under share_40_under share_50_under
order date2 share_*

export excel using "$output/chapter4.xlsx" , firstrow(varlabel) sheet("4.4") sheetreplace keepcellfmt

putexcel set "$output/chapter4.xlsx" , modify sheet("4.4")
putexcel A12 = "Share of all investors with less than x% of equities in international equities"
putexcel A13 = "Excludes all individuals that are entirely in TDFs or entirely in funds that are not dropped by plan reform"
putexcel close

}

{ // weighting of intl equities among equities -- all investors

use "$temp/collapse2_combined.dta", clear
keep if inlist(date,672)
keep ScrubbedID
tempfile ids_used
save "`ids_used'"

use "$temp/guard_intrm_onlytdf_joint_nonintl_fulldata.dta", clear
keep ScrubbedID date Fund port_weight intl_equity_share equities
keep if date == 672
replace date = 673
tempfile temp_guardrail
save "`temp_guardrail'"

use "$temp/full_data.dta", clear
keep ScrubbedID date Fund port_weight intl_equity_share equities
append using  "`temp_guardrail'"
merge m:1 ScrubbedID using "`ids_used'"
keep if _m == 3
drop _m

keep if inlist(date,672,684,673)
la define date 672 "Pre-Reform" ///
684 "Post-Reform" ///
673 "Guardrails"
la val date date
bys ScrubbedID date: egen total_equity = total(equities)
bys ScrubbedID date: egen total_intl = total(intl_equity_share)
gen intl_share_of_equities = total_intl/total_equity

bys ScrubbedID date: keep if _n == 1
keep ScrubbedID date intl_share_of_equities
keep if intl_share_of_equities < .

// create variables for weight over x%
gen share_any = intl_share_of_equities == 0
gen share_10_under = intl_share_of_equities < .10
gen share_20_under = intl_share_of_equities < .20
gen share_30_under = intl_share_of_equities < .30
gen share_40_under = intl_share_of_equities < .40
gen share_50_under = intl_share_of_equities < .50
gen share_60_under = intl_share_of_equities < .60
gen share_70_under = intl_share_of_equities < .70
gen share_80_under = intl_share_of_equities < .80
gen share_90_under = intl_share_of_equities < .90
gen share_100 = intl_share_of_equities < 1

// collapse to summarize share of investors over x% in each fund
collapse (mean) share_*, by(date)

la var share_any "Share of investors with no international equities"
la var share_10_under "Share of investors with less than 10% of equities in international equities"
la var share_20_under "Share of investors with less than 20% of equities in international equities"
la var share_30_under "Share of investors with less than 30% of equities in international equities"
la var share_40_under "Share of investors with less than 40% of equities in international equities"
la var share_50_under "Share of investors with less than 50% of equities in international equities"
la var share_60_under "Share of investors with less than 60% of equities in international equities"
la var share_70_under "Share of investors with less than 70% of equities in international equities"
la var share_80_under "Share of investors with less than 80% of equities in international equities"
la var share_90_under "Share of investors with less than 90% of equities in international equities"
la var share_100 "Share of investors with less than 100% of equities in international equities"
sort date
decode date, gen(date2)
la var date2 "Date"
drop date
keep date2 share_any share_10_under share_20_under share_30_under share_40_under share_50_under
order date2 share_*

//export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabel) sheet("% Eq That Are Intl - All") sheetreplace keepcellfmt

// putexcel set "$output/25 - Fund Allocations.xlsx" , modify sheet("% Eq That Are Intl - All")
// putexcel A12 = "Share of all investors with less than x% of equities in international equities"
// putexcel A13 = "Includes all investors"
// putexcel close

}

{ // tables for share of people with over x% of assets in each fund/fund type
// funds, all investors
preserve

	replace port_weight = round(port_weight, .0001)
	// create variables for weight over 50%
	//assert port_weight != .
	gen share_any = port_weight > 0
	gen share_10_plus = port_weight > .10
	gen share_20_plus = port_weight > .20
	gen share_30_plus = port_weight > .30
	gen share_40_plus = port_weight > .40
	gen share_50_plus = port_weight > .50
	gen share_60_plus = port_weight > .60
	gen share_70_plus = port_weight > .70
	gen share_80_plus = port_weight > .80
	gen share_90_plus = port_weight > .90
	gen share_100 = port_weight == 1

	// collapse to summarize share of investors over 50% in each fund
	collapse (mean) share_*, by(Fund)

	la var share_any "Share of investors with any assets in fund"
	la var share_10_plus "Share of investors with over 10% of assets in fund"
	la var share_20_plus "Share of investors with over 20% of assets in fund"
	la var share_30_plus "Share of investors with over 30% of assets in fund"
	la var share_40_plus "Share of investors with over 40% of assets in fund"
	la var share_50_plus "Share of investors with over 50% of assets in fund"
	la var share_60_plus "Share of investors with over 60% of assets in fund"
	la var share_70_plus "Share of investors with over 70% of assets in fund"
	la var share_80_plus "Share of investors with over 80% of assets in fund"
	la var share_90_plus "Share of investors with over 90% of assets in fund"
	la var share_100 "Share of investors with all assets in fund"

	// merge in sector fund flags
	merge 1:1 Fund using "$temp/sectorfunds"
	//assert _m != 1
	drop if _m != 3
	la var sector "Sector Fund"
	la define sector 0 "No" 1 "Yes"
	la val sector sector
	keep Fund sector share_*
	order Fund sector share_*
	tostring sector, replace

	// export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("All inv over x% in fund") sheetreplace keepcellfmt
	//
	// putexcel set "$output/25 - Fund Allocations.xlsx" , modify sheet("All inv over x% in fund")
	// putexcel A282 = "Share of all investors with over x% in fund, pre-reform"
	// putexcel close

restore

// funds, subset of investors in the funds
preserve

	drop if port_weight == 0

	replace port_weight = round(port_weight, .0001)
	// create variables for weight over 50%
	assert port_weight != .
	gen share_10_plus = port_weight > .10
	gen share_20_plus = port_weight > .20
	gen share_30_plus = port_weight > .30
	gen share_40_plus = port_weight > .40
	gen share_50_plus = port_weight > .50
	gen share_60_plus = port_weight > .60
	gen share_70_plus = port_weight > .70
	gen share_80_plus = port_weight > .80
	gen share_90_plus = port_weight > .90
	gen share_100 = port_weight == 1

	gen counter = 1
	// collapse to summarize share of investors over 50% in each fund
	collapse (count) counter (mean) share_*, by(Fund)

	la var share_10_plus "Share of investors with over 10% of assets in fund"
	la var share_20_plus "Share of investors with over 20% of assets in fund"
	la var share_30_plus "Share of investors with over 30% of assets in fund"
	la var share_40_plus "Share of investors with over 40% of assets in fund"
	la var share_50_plus "Share of investors with over 50% of assets in fund"
	la var share_60_plus "Share of investors with over 60% of assets in fund"
	la var share_70_plus "Share of investors with over 70% of assets in fund"
	la var share_80_plus "Share of investors with over 80% of assets in fund"
	la var share_90_plus "Share of investors with over 90% of assets in fund"
	la var share_100 "Share of investors with all assets in fund"
	la var count "N"

	// merge in sector fund flags
	merge 1:1 Fund using "$temp/sectorfunds"
	assert _m != 1
	drop if _m != 3
	la var sector "Sector Fund"
	la define sector 0 "No" 1 "Yes"
	la val sector sector
	keep Fund sector counter share_*
	order Fund sector counter share_*
	tostring sector, replace

	// export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Subset inv over x% in fund") sheetreplace keepcellfmt
	//
	// putexcel set "$output/25 - Fund Allocations.xlsx" , modify sheet("Subset inv over x% in fund")
	// putexcel A282 = "Share of investors that own a given fund that hold over x% of assets in fund, pre-reform"
	// putexcel close

restore

// funds, subset of investors in the funds, example funds
preserve

	keep if inlist(Fund, "0041-FID SEL GOLD", "0046-FID SEL RETAILING", "0042-FID SEL BIOTECH" ///
	, "0063-FID SEL HEALTHCARE", "0069-FID SEL CHEMICALS", "0580-FID SEL PHARMACEUTCL" ///
	"OQNG-VANGUARD ENERGY ADM", "0354-FID SEL MED TECH&DV", "0028-FID SEL SOFTWARE", "0514-FID SEL NATURAL RES")

	drop if port_weight == 0

	replace port_weight = round(port_weight, .0001)
	// create variables for weight over 50%
	assert port_weight != .
	gen share_10_plus = port_weight > .10
	gen share_20_plus = port_weight > .20
	gen share_30_plus = port_weight > .30
	gen share_40_plus = port_weight > .40
	gen share_50_plus = port_weight > .50
	gen share_60_plus = port_weight > .60
	gen share_70_plus = port_weight > .70
	gen share_80_plus = port_weight > .80
	gen share_90_plus = port_weight > .90
	gen share_100 = port_weight == 1

	gen counter = 1
	// collapse to summarize share of investors over 50% in each fund
	collapse (count) counter (mean) share_*, by(Fund)

	la var share_10_plus "Share of investors with over 10% of assets in fund"
	la var share_20_plus "Share of investors with over 20% of assets in fund"
	la var share_30_plus "Share of investors with over 30% of assets in fund"
	la var share_40_plus "Share of investors with over 40% of assets in fund"
	la var share_50_plus "Share of investors with over 50% of assets in fund"
	la var share_60_plus "Share of investors with over 60% of assets in fund"
	la var share_70_plus "Share of investors with over 70% of assets in fund"
	la var share_80_plus "Share of investors with over 80% of assets in fund"
	la var share_90_plus "Share of investors with over 90% of assets in fund"
	la var share_100 "Share of investors with all assets in fund"
	la var count "N"


	// merge in sector fund flags
	merge 1:1 Fund using "$temp/sectorfunds"
	assert _m != 1
	drop if _m != 3
	la var sector "Sector Fund"
	la define sector 0 "No" 1 "Yes"
	la val sector sector
	keep Fund counter sector share_50_plus share_70_plus share_90_plus
	order Fund counter sector counter share_*
	gsort -share_50_plus
	tostring sector, replace

	export excel using "$output/chapter4.xlsx" , firstrow(varlabels) sheet("4.2") sheetreplace keepcellfmt

	putexcel set "$output/chapter4.xlsx" , modify sheet("4.2")
	putexcel A12 = "Share of investors that own a given fund that hold over x% of assets in fund, pre-reform, for example sector funds"
	putexcel A13 = "This table presents examples of domestic equities sector funds. We also observe overweighting of foreign region funds (e.g. portfolios that contain significant holdings in the Fidelity Japan fund."
	putexcel close

restore


// fund types, all investors
preserve

	// merge in sector fund flags
	merge m:1 Fund using "$temp/sectorfunds"
	assert _m != 1
	drop if _m != 3
	drop _m
	la var sector "Sector Fund"
	la define sector 0 "No" 1 "Yes"
	la val sector sector
	merge m:1 Fund using "$temp/intl_equity_funds"
	assert _m != 1
	drop if _m != 3
	drop _m

	gen fund_type = 1 if equity == 1 & intl_equity_fund == 0 & sector == 0
	replace fund_type = 2 if equity == 1 & intl_equity_fund == 0 & sector == 1
	replace fund_type = 3 if equity == 1 & intl_equity_fund == 1 & sector == 0
	replace fund_type = 4 if equity == 1 & intl_equity_fund == 1 & sector == 1
	replace fund_type = 5 if tdf == 1
	replace fund_type = 6 if balanced == 1
	replace fund_type = 7 if bond == 1
	replace fund_type = 8 if real_estate == 1
	replace fund_type = 9 if money_market == 1

	collapse (sum) port_weight, by(ScrubbedID date fund_type)
	replace port_weight = round(port_weight, .0001)


	// create variables for weight over x%
	assert port_weight != .
	gen share_any = port_weight == 0
	gen share_10_plus = port_weight < .10
	gen share_20_plus = port_weight < .20
	gen share_30_plus = port_weight < .30
	gen share_40_plus = port_weight < .40
	gen share_50_plus = port_weight < .50
	gen share_60_plus = port_weight < .60
	gen share_70_plus = port_weight < .70
	gen share_80_plus = port_weight < .80
	gen share_90_plus = port_weight < .90
	gen share_100 = port_weight < 1

	// collapse to summarize share of investors over 50% in each fund
	collapse (mean) share_*, by(fund_type)

	la var share_any "Share of investors with no assets in fund type"
	la var share_10_plus "Share of investors with less than 10% of assets in fund type"
	la var share_20_plus "Share of investors with less than 20% of assets in fund type"
	la var share_30_plus "Share of investors with less than 30% of assets in fund type"
	la var share_40_plus "Share of investors with less than 40% of assets in fund type"
	la var share_50_plus "Share of investors with less than 50% of assets in fund type"
	la var share_60_plus "Share of investors with less than 60% of assets in fund type"
	la var share_70_plus "Share of investors with less than 70% of assets in fund type"
	la var share_80_plus "Share of investors with less than 80% of assets in fund type"
	la var share_90_plus "Share of investors with less than 90% of assets in fund type"
	la var share_100 "Share of investors less than 100% of assets in fund type"

	la define fund_type 1 "Domestic Equities - Broad" ///
	2 "Domestic Equities - Sector" ///
	3 "International Equities - Broad" ///
	4 "International Equities - Region" ///
	5 "TDFs" ///
	6 "Balanced" ///
	7 "Bonds" ///
	8 "Real Estate" ///
	9 "Money Market"
	la val fund_type fund_type
	decode fund_type, gen(fund_type_text)
	drop fund_type
	rename fund_type_text fund_type

	keep fund_type share_*
	order fund_type
	la var fund_type "Fund Type"

	// export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("All under x% in fund type") sheetreplace keepcellfmt
	//
	// putexcel set "$output/25 - Fund Allocations.xlsx" , modify sheet("All under x% in fund type")
	// putexcel A13 = "Share of all investors that have under x% of assets in fund type, pre-reform"
	// putexcel close

restore

// fund types, subset of investors in specific fund type
preserve

	keep if port_weight != 0

	// merge in sector fund flags
	merge m:1 Fund using "$temp/sectorfunds"
	assert _m != 1
	drop if _m != 3
	drop _m
	la var sector "Sector Fund"
	la define sector 0 "No" 1 "Yes"
	la val sector sector
	merge m:1 Fund using "$temp/intl_equity_funds"
	assert _m != 1
	drop if _m != 3
	drop _m

	gen fund_type = 1 if equity == 1 & intl_equity_fund == 0 & sector == 0
	replace fund_type = 2 if equity == 1 & intl_equity_fund == 0 & sector == 1
	replace fund_type = 3 if equity == 1 & intl_equity_fund == 1 & sector == 0
	replace fund_type = 4 if equity == 1 & intl_equity_fund == 1 & sector == 1
	replace fund_type = 5 if tdf == 1
	replace fund_type = 6 if balanced == 1
	replace fund_type = 7 if bond == 1
	replace fund_type = 8 if real_estate == 1
	replace fund_type = 9 if money_market == 1

	collapse (sum) port_weight, by(ScrubbedID date fund_type)
	replace port_weight = round(port_weight, .0001)


	// create variables for weight over x%
	assert port_weight != .
	gen share_10_plus = port_weight > .10
	gen share_20_plus = port_weight > .20
	gen share_30_plus = port_weight > .30
	gen share_40_plus = port_weight > .40
	gen share_50_plus = port_weight > .50
	gen share_60_plus = port_weight > .60
	gen share_70_plus = port_weight > .70
	gen share_80_plus = port_weight > .80
	gen share_90_plus = port_weight > .90
	gen share_100 = port_weight == 1

	gen counter = 1
	// collapse to summarize share of investors over 50% in each fund
	collapse (count) counter (mean) share_*, by(fund_type)

	la var share_10_plus "Share of investors with over 10% of assets in fund type"
	la var share_20_plus "Share of investors with over 20% of assets in fund type"
	la var share_30_plus "Share of investors with over 30% of assets in fund type"
	la var share_40_plus "Share of investors with over 40% of assets in fund type"
	la var share_50_plus "Share of investors with over 50% of assets in fund type"
	la var share_60_plus "Share of investors with over 60% of assets in fund type"
	la var share_70_plus "Share of investors with over 70% of assets in fund type"
	la var share_80_plus "Share of investors with over 80% of assets in fund type"
	la var share_90_plus "Share of investors with over 90% of assets in fund type"
	la var share_100 "Share of investors with all assets in fund type"
	la var counter "N"

	la define fund_type 1 "Domestic Equities - Broad" ///
	2 "Domestic Equities - Sector" ///
	3 "International Equities - Broad" ///
	4 "International Equities - Region" ///
	5 "TDFs" ///
	6 "Balanced" ///
	7 "Bonds" ///
	8 "Real Estate" ///
	9 "Money Market"
	la val fund_type fund_type
	decode fund_type, gen(fund_type_text)
	drop fund_type
	rename fund_type_text fund_type

	keep fund_type counter share_*
	order fund_type counter
	la var fund_type "Fund Type"

	// export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Subset inv over x% in fund type") sheetreplace keepcellfmt
	//
	// putexcel set "$output/25 - Fund Allocations.xlsx" , modify sheet("Subset inv over x% in fund type")
	// putexcel A13 = "Share of investors that hold a given fund type that have over x% of assets in fund type, pre-reform"
	// putexcel close

restore


}

{ // table for share of people with over x% of assets in high-fee funds
// load data
use "$temp/joined_fund_data", clear
keep if month == date

// filter to pre-reform
keep if date == 672

// filter to ScrubbedIDs in cleaned data
cap drop _m
merge m:1 ScrubbedID date using "$temp/collapse2.dta"
keep if _m == 3

// create expense ratio categories
gen exp_category = 1 if exp_ratio <= .0025
replace exp_category = 2 if exp_ratio > .0025 & exp_ratio <= .0050
replace exp_category = 3 if exp_ratio > .0050 & exp_ratio <= .0075
replace exp_category = 4 if exp_ratio > .0075 & exp_ratio <= .0100
replace exp_category = 5 if exp_ratio > .0100 & exp_ratio < .
replace exp_category = 6 if missing(exp_ratio)
la define exp_category 1 "Expense ratio 0.25% or lower" ///
2 "Expense ratio 0.26% - 0.50%" ///
3 "Expense ratio 0.51% - 0.75%" ///
4 "Expense ratio 0.76% - 1.00%" ///
5 "Expense ratio over 1.00%" ///
6 "Missing expense ratio"
la val exp_category exp_category

// filter to necessary variables
keep ScrubbedID date port_weight exp_category

// collapse to exp ratio-category level
collapse (sum) port_weight, by(ScrubbedID date exp_category)
replace port_weight = round(port_weight, .0001)

// fill out so we have equal number of observations for all funds
gen double id = ScrubbedID + date/1000
tsset ScrubbedID exp_category
tsfill, full
tostring id, force replace
drop ScrubbedID date
gen ScrubbedID2 = substr(id,1,strpos(id,".")-1)
gen date = substr(id,strpos(id,".")+1,3)
destring ScrubbedID2 date, replace
order ScrubbedID2 date
replace port_weight = 0 if missing(port_weight)
drop id

// create variables for weight over x%
assert port_weight != .
gen share_any = port_weight > 0
gen share_10_plus = port_weight > .10
gen share_20_plus = port_weight > .20
gen share_30_plus = port_weight > .30
gen share_40_plus = port_weight > .40
gen share_50_plus = port_weight > .50
gen share_60_plus = port_weight > .60
gen share_70_plus = port_weight > .70
gen share_80_plus = port_weight > .80
gen share_90_plus = port_weight > .90
gen share_100 = port_weight == 1

// expense ratio categories, all investors
preserve
	// collapse to summarize share of investors over x% in each fund
	collapse (mean) share_*, by(exp_category)

	la var share_any "Share of investors with any assets in category"
	la var share_10_plus "Share of investors with over 10% of assets in category"
	la var share_20_plus "Share of investors with over 20% of assets in category"
	la var share_30_plus "Share of investors with over 30% of assets in category"
	la var share_40_plus "Share of investors with over 40% of assets in category"
	la var share_50_plus "Share of investors with over 50% of assets in category"
	la var share_60_plus "Share of investors with over 60% of assets in category"
	la var share_70_plus "Share of investors with over 70% of assets in category"
	la var share_80_plus "Share of investors with over 80% of assets in category"
	la var share_90_plus "Share of investors with over 90% of assets in category"
	la var share_100 "Share of investors with all assets in category"
	decode(exp_category), gen(exp_cat)
	la var exp_cat "Expense ratio"
	keep exp_cat share_*
	order exp_cat

	export excel using "$output/chapter4.xlsx" , firstrow(varlabels) sheet("4.5") sheetreplace keepcellfmt

	putexcel set "$output/chapter4.xlsx" , modify sheet("4.5")
	putexcel A10 = "Share of all investors over x% by expense ratio category, pre-reform"
	putexcel close
restore

// expense ratio categories, subset of investors in category
preserve

	keep if port_weight != 0
	drop share_any

	gen counter = 1
	// collapse to summarize share of investors over x% in each fund
	collapse (count) counter (mean) share_*, by(exp_category)

	la var share_10_plus "Share of investors with over 10% of assets in category"
	la var share_20_plus "Share of investors with over 20% of assets in category"
	la var share_30_plus "Share of investors with over 30% of assets in category"
	la var share_40_plus "Share of investors with over 40% of assets in category"
	la var share_50_plus "Share of investors with over 50% of assets in category"
	la var share_60_plus "Share of investors with over 60% of assets in category"
	la var share_70_plus "Share of investors with over 70% of assets in category"
	la var share_80_plus "Share of investors with over 80% of assets in category"
	la var share_90_plus "Share of investors with over 90% of assets in category"
	la var share_100 "Share of investors with all assets in category"
	la var counter "N"
	decode(exp_category), gen(exp_cat)
	la var exp_cat "Expense ratio"
	keep exp_cat counter share_*
	order exp_cat counter

	// export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Subset over x% by exp ratio") sheetreplace keepcellfmt
	//
	// putexcel set "$output/25 - Fund Allocations.xlsx" , modify sheet("Subset over x% by exp ratio")
	// putexcel A10 = "Share of investors in a given expense ratio category with over x% in expense ratio category, pre-reform"
	// putexcel close
restore
}

// EI



{ // determine share of people solely in Fidelity TDFs pre-reform
use "$temp/individual_ports.dta", clear
joinby Fund date using "$temp/fund_returns_series_crosswalk_post.dta"

// check for duplicates
bys ScrubbedID CalendarDay  AgeasofNov2018 Fund MarketValue FundsHeld Gender MaritialStatus RoundedSalary AcaMCFlag HireDate TerminationDate date crsp_fundno crsp_fundno_orig hand_match lipper_obj_cd series_length longest_series_length month RF _rmse _Nobs _R2 _adjR2 _b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX sigma_hat_ido missing_data total_assets port_weight: gen dup = cond(_N==1,0,_n)
tab dup
drop if dup > 1
drop dup

// filter to ScrubbedIDs in cleaned data
cap drop _m
merge m:1 ScrubbedID date using "$temp/collapse2.dta"
keep if _m == 3

// filter to pre-reform
keep if date == 672

// flag those entirely in fidelity tdfs
gen fid_tdf_all = (fid_tdf_share == 1)
bys ScrubbedID date: keep if _n == 1
summ fid_tdf_all
// 53% of all people are entirely in Fidelity TDFs

}

{ // investors with gold -- how much would they need to have in outside assets and is that reasonable

use "$temp/individual_ports.dta", clear
joinby Fund date using "$temp/fund_returns_series_crosswalk_post.dta"

// check for duplicates
bys ScrubbedID CalendarDay  AgeasofNov2018 Fund MarketValue FundsHeld Gender MaritialStatus RoundedSalary AcaMCFlag HireDate TerminationDate date crsp_fundno crsp_fundno_orig hand_match lipper_obj_cd series_length longest_series_length month RF _rmse _Nobs _R2 _adjR2 _b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX sigma_hat_ido missing_data total_assets port_weight: gen dup = cond(_N==1,0,_n)
tab dup
drop if dup > 1
drop dup

// filter to pre-reform
keep if date == 672

// filter to ScrubbedIDs in cleaned data
cap drop _m
merge m:1 ScrubbedID date using "$temp/collapse2.dta"
keep if _m == 3

// filter to gold
keep if Fund == "0041-FID SEL GOLD"

// filter to necessary variables
keep ScrubbedID date port_weight age2018 FundsHeld total_assets RoundedSalary
bys ScrubbedID: assert _N == 1

// calculate non-gold assets needed for these gold holdings to be reasonable (assuming that 2% holdings in gold are rational)
gen non_gold_assets = FundsHeld/.02
gen non_plan_non_gold_assets = non_gold_assets - total_assets + FundsHeld
replace non_plan_non_gold_assets = 0 if non_plan_non_gold_assets < 0
summ non_plan_non_gold_assets if non_plan_non_gold_assets != 0

// some salaries missing (e.g. no longer working at UVA)
replace RoundedSalary = . if RoundedSalary == 0

// calculate outside non-gold assets as a multiple of current salary and graph
gen non_plan_over_savings = non_plan_non_gold_assets/total_assets
summ non_plan_over_savings if non_plan_non_gold_assets != 0
la var non_plan_over_savings "Multiple of UVA 403(b) Savings"

// conservatively calculate reasonable outside savings as 10% of current salary since age 22 ("Diversification Across Time" mentions as a constant 10% savings rate)
// substract half of savings in UVA account (assuming 1:1 employer matching)
// assuming compounded annually
// balance(Y) = P(1 + r)Y   +   c[ ((1 + r)Y - 1) / r ]; P = 0, c = 10% of current salary, r = 5%, Y = years since age 22
gen reasonable_outside = .1 * RoundedSalary * ((1.05 * (age2018 - 2 - 22) - 1) / 1.05) - total_assets/2
replace reasonable_outside  = 0 if reasonable_outside < 0

gen diff_savings = non_plan_non_gold_assets - reasonable_outside
replace diff_savings = 0 if port_weight <= .02
summ diff_savings

// create variable to flag people that should have enough outside assets to justify gold holdings
gen enough_outside = ((reasonable_outside >= non_plan_non_gold_assets & reasonable_outside < .) | port_weight <= .02)
replace enough_outside = . if missing(non_plan_non_gold_assets) & port_weight > .02

// graph share likely can justify gold holdings

save "$temp/gold_outside_holdings", replace
}

{ // investors with sector funds -- how much would they need to have in outside assets and is that reasonable

use "$temp/individual_ports.dta", clear
joinby Fund date using "$temp/fund_returns_series_crosswalk_post.dta"

// check for duplicates
bys ScrubbedID CalendarDay  AgeasofNov2018 Fund MarketValue FundsHeld Gender MaritialStatus RoundedSalary AcaMCFlag HireDate TerminationDate date crsp_fundno crsp_fundno_orig hand_match lipper_obj_cd series_length longest_series_length month RF _rmse _Nobs _R2 _adjR2 _b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX sigma_hat_ido missing_data total_assets port_weight: gen dup = cond(_N==1,0,_n)
tab dup
drop if dup > 1
drop dup

// filter to pre-reform
keep if date == 672

// filter to ScrubbedIDs in cleaned data
cap drop _m
merge m:1 ScrubbedID date using "$temp/collapse2.dta"
keep if _m == 3

// filter to sector-fund-holding portfolios
bys ScrubbedID date: egen temp = max(sector)
assert round(temp, .00001) == round(sector, .00001)
bys ScrubbedID: keep if _n == 1
drop if sector == 0

// filter to necessary variables
keep ScrubbedID date sector age2018 FundsHeld total_assets RoundedSalary

// calculate non-sector assets needed for these sector holdings to be reasonable (assuming that 10% holdings in sectors are rational)
gen non_sector_assets = FundsHeld/.10
gen non_plan_non_sector_assets = non_sector_assets - total_assets + FundsHeld
replace non_plan_non_sector_assets = 0 if non_plan_non_sector_assets < 0
summ non_plan_non_sector_assets if non_plan_non_sector_assets != 0

/// some salaries missing (e.g. no longer working at UVA)
replace RoundedSalary = . if RoundedSalary == 0

// calculate outside non-sector assets as a multiple of current salary and graph
gen non_plan_over_savings = non_plan_non_sector_assets/total_assets
summ non_plan_over_savings if non_plan_non_sector_assets != 0
la var non_plan_over_savings "Multiple of UVA 403(b) Savings"

// conservatively calculate reasonable outside savings as 10% of current salary since age 22 ("Diversification Across Time" mentions as a constant 10% savings rate)
// substract half of savings in UVA account (assuming 1:1 employer matching)
// assuming compounded annually
// balance(Y) = P(1 + r)Y   +   c[ ((1 + r)Y - 1) / r ]; P = 0, c = 10% of current salary, r = 5%, Y = years since age 22
gen reasonable_outside = .1 * RoundedSalary * ((1.05 * (age2018 - 2 - 22) - 1) / 1.05) - total_assets/2
replace reasonable_outside  = 0 if reasonable_outside < 0

gen diff_savings = non_plan_non_sector_assets - reasonable_outside

// create variable to flag people that should have enough outside assets to justify gold holdings
gen enough_outside = ((reasonable_outside >= non_plan_non_sector_assets & reasonable_outside < .) | sector <= .10)
replace enough_outside = . if missing(non_plan_non_sector_assets) & sector > .02

// graph share likely can justify gold holdings

save "$temp/sector_outside_holdings", replace
}

{ // sharpe ratio graphs for guardrails
use "$temp/collapse2_combined.dta", clear
gen graph_helper = .

keep if inlist(date,672)

gen sharpe2 = sharpe
replace sharpe = -1 if sharpe < -1
replace sharpe = 10 if sharpe > 10

// putexcel set "$output/59 - Guardrails Sharpe Ratio Means.xlsx", replace
// putexcel A4 = "Expense Ratio Guardrail"
// putexcel A5 = "Equity Exposure Guardrail"
// putexcel A6 = "Minimum Equity Exposure Guardrail"
// putexcel A7 = "Maximum Equity Exposure Guardrail"
// putexcel A8 = "International Equities As Share of Equities Guardrail"
// putexcel A9 = "Sector Fund Guardrail"
// putexcel A10 = "Goldbugs"
// putexcel B1:E1, hcenter merge
// putexcel F1:I1, hcenter merge
// putexcel J1:M1, hcenter merge
// putexcel B2:C2, hcenter merge
// putexcel D2:E2, hcenter merge
// putexcel F2:G2, hcenter merge
// putexcel H2:I2, hcenter merge
// putexcel J2:K2, hcenter merge
// putexcel L2:M2, hcenter merge
// putexcel B1 = "Without Top- And Bottom-Coding"
// putexcel F1 = "With Top- And Bottom-Coding"
// putexcel J1 = "Dropping If > 10 or < -1"
// putexcel B2 = "Violating Guardrail"
// putexcel D2 = "Not Violating Guardrail"
// putexcel F2 = "Violating Guardrail"
// putexcel H2 = "Not Violating Guardrail"
// putexcel J2 = "Violating Guardrail"
// putexcel L2 = "Not Violating Guardrail"
// putexcel B3 = "Mean", hcenter
// putexcel C3 = "SD", hcenter
// putexcel D3 = "Mean", hcenter
// putexcel E3 = "SD", hcenter
// putexcel F3 = "Mean", hcenter
// putexcel G3 = "SD", hcenter
// putexcel H3 = "Mean", hcenter
// putexcel I3 = "SD", hcenter
// putexcel J3 = "Mean", hcenter
// putexcel K3 = "SD", hcenter
// putexcel L3 = "Mean", hcenter
// putexcel M3 = "SD", hcenter
//

summ sharpe2 if total_exp_over == 0
local base_sd_0 = string(r(sd),"%3.2f")
local base_mean_0 = string(r(mean),"%3.2f")
summ sharpe if total_exp_over == 0
local bound_sd_0 = string(r(sd),"%3.2f")
local bound_mean_0 = string(r(mean),"%3.2f")
summ sharpe2 if total_exp_over == 1
local base_sd_1 = string(r(sd),"%3.2f")
local base_mean_1 = string(r(mean),"%3.2f")
summ sharpe if total_exp_over == 1
local bound_sd_1 = string(r(sd),"%3.2f")
local bound_mean_1 = string(r(mean),"%3.2f")
summ sharpe2 if total_exp_over == 0 & sharpe2 >= -1 & sharpe2 <= 10
local drop_sd_0 = string(r(sd),"%3.2f")
local drop_mean_0 = string(r(mean),"%3.2f")
summ sharpe2 if total_exp_over == 1 & sharpe2 >= -1 & sharpe2 <= 10
local drop_mean_1 = string(r(mean),"%3.2f")
local drop_sd_1 = string(r(sd),"%3.2f")

// putexcel B4 = `base_mean_1'
// putexcel D4 = `base_mean_0'
// putexcel F4 = `bound_mean_1'
// putexcel H4 = `bound_mean_0'
// putexcel J4 = `drop_mean_1'
// putexcel L4 = `drop_mean_0'
// putexcel C4 = `base_sd_1'
// putexcel E4 = `base_sd_0'
// putexcel I4 = `bound_sd_0'
// putexcel G4 = `bound_sd_1'
// putexcel K4 = `drop_sd_1'
// putexcel M4 = `drop_sd_0'

summ sharpe2 if total_eq_violation == 0
local base_sd_0 = string(r(sd),"%3.2f")
local base_mean_0 = string(r(mean),"%3.2f")
summ sharpe if total_eq_violation == 0
local bound_sd_0 = string(r(sd),"%3.2f")
local bound_mean_0 = string(r(mean),"%3.2f")
summ sharpe2 if total_eq_violation == 1
local base_sd_1 = string(r(sd),"%3.2f")
local base_mean_1 = string(r(mean),"%3.2f")
summ sharpe if total_eq_violation == 1
local bound_sd_1 = string(r(sd),"%3.2f")
local bound_mean_1 = string(r(mean),"%3.2f")
summ sharpe2 if total_eq_violation == 0 & sharpe2 >= -1 & sharpe2 <= 10
local drop_sd_0 = string(r(sd),"%3.2f")
local drop_mean_0 = string(r(mean),"%3.2f")
summ sharpe2 if total_eq_violation == 1 & sharpe2 >= -1 & sharpe2 <= 10
local drop_mean_1 = string(r(mean),"%3.2f")
local drop_sd_1 = string(r(sd),"%3.2f")

// putexcel B5 = `base_mean_1'
// putexcel D5 = `base_mean_0'
// putexcel F5 = `bound_mean_1'
// putexcel H5 = `bound_mean_0'
// putexcel J5 = `drop_mean_1'
// putexcel L5 = `drop_mean_0'
// putexcel C5 = `base_sd_1'
// putexcel E5 = `base_sd_0'
// putexcel I5 = `bound_sd_0'
// putexcel G5 = `bound_sd_1'
// putexcel K5 = `drop_sd_1'
// putexcel M5 = `drop_sd_0'

summ sharpe2 if total_eq_under == 0
local base_sd_0 = string(r(sd),"%3.2f")
local base_mean_0 = string(r(mean),"%3.2f")
summ sharpe if total_eq_under == 0
local bound_sd_0 = string(r(sd),"%3.2f")
local bound_mean_0 = string(r(mean),"%3.2f")
summ sharpe2 if total_eq_under == 1
local base_sd_1 = string(r(sd),"%3.2f")
local base_mean_1 = string(r(mean),"%3.2f")
summ sharpe if total_eq_under == 1
local bound_sd_1 = string(r(sd),"%3.2f")
local bound_mean_1 = string(r(mean),"%3.2f")
summ sharpe2 if total_eq_under == 0 & sharpe2 >= -1 & sharpe2 <= 10
local drop_sd_0 = string(r(sd),"%3.2f")
local drop_mean_0 = string(r(mean),"%3.2f")
summ sharpe2 if total_eq_under == 1 & sharpe2 >= -1 & sharpe2 <= 10
local drop_mean_1 = string(r(mean),"%3.2f")
local drop_sd_1 = string(r(sd),"%3.2f")

// putexcel B6 = `base_mean_1'
// putexcel D6 = `base_mean_0'
// putexcel F6 = `bound_mean_1'
// putexcel H6 = `bound_mean_0'
// putexcel J6 = `drop_mean_1'
// putexcel L6 = `drop_mean_0'
// putexcel C6 = `base_sd_1'
// putexcel E6 = `base_sd_0'
// putexcel I6 = `bound_sd_0'
// putexcel G6 = `bound_sd_1'
// putexcel K6 = `drop_sd_1'
// putexcel M6 = `drop_sd_0'

summ sharpe2 if total_eq_over == 0
local base_sd_0 = string(r(sd),"%3.2f")
local base_mean_0 = string(r(mean),"%3.2f")
summ sharpe if total_eq_over == 0
local bound_sd_0 = string(r(sd),"%3.2f")
local bound_mean_0 = string(r(mean),"%3.2f")
summ sharpe2 if total_eq_over == 1
local base_sd_1 = string(r(sd),"%3.2f")
local base_mean_1 = string(r(mean),"%3.2f")
summ sharpe if total_eq_over == 1
local bound_sd_1 = string(r(sd),"%3.2f")
local bound_mean_1 = string(r(mean),"%3.2f")
summ sharpe2 if total_eq_over == 0 & sharpe2 >= -1 & sharpe2 <= 10
local drop_sd_0 = string(r(sd),"%3.2f")
local drop_mean_0 = string(r(mean),"%3.2f")
summ sharpe2 if total_eq_over == 1 & sharpe2 >= -1 & sharpe2 <= 10
local drop_mean_1 = string(r(mean),"%3.2f")
local drop_sd_1 = string(r(sd),"%3.2f")

// putexcel B7 = `base_mean_1'
// putexcel D7 = `base_mean_0'
// putexcel F7 = `bound_mean_1'
// putexcel H7 = `bound_mean_0'
// putexcel J7 = `drop_mean_1'
// putexcel L7 = `drop_mean_0'
// putexcel C7 = `base_sd_1'
// putexcel E7 = `base_sd_0'
// putexcel I7 = `bound_sd_0'
// putexcel G7 = `bound_sd_1'
// putexcel K7 = `drop_sd_1'
// putexcel M7 = `drop_sd_0'

summ sharpe2 if total_intl_share_under == 0
local base_sd_0 = string(r(sd),"%3.2f")
local base_mean_0 = string(r(mean),"%3.2f")
summ sharpe if total_intl_share_under == 0
local bound_sd_0 = string(r(sd),"%3.2f")
local bound_mean_0 = string(r(mean),"%3.2f")
summ sharpe2 if total_intl_share_under == 1
local base_sd_1 = string(r(sd),"%3.2f")
local base_mean_1 = string(r(mean),"%3.2f")
summ sharpe if total_intl_share_under == 1
local bound_sd_1 = string(r(sd),"%3.2f")
local bound_mean_1 = string(r(mean),"%3.2f")
summ sharpe2 if total_intl_share_under == 0 & sharpe2 >= -1 & sharpe2 <= 10
local drop_sd_0 = string(r(sd),"%3.2f")
local drop_mean_0 = string(r(mean),"%3.2f")
summ sharpe2 if total_intl_share_under == 1 & sharpe2 >= -1 & sharpe2 <= 10
local drop_mean_1 = string(r(mean),"%3.2f")
local drop_sd_1 = string(r(sd),"%3.2f")

// putexcel B8 = `base_mean_1'
// putexcel D8 = `base_mean_0'
// putexcel F8 = `bound_mean_1'
// putexcel H8 = `bound_mean_0'
// putexcel J8 = `drop_mean_1'
// putexcel L8 = `drop_mean_0'
// putexcel C8 = `base_sd_1'
// putexcel E8 = `base_sd_0'
// putexcel I8 = `bound_sd_0'
// putexcel G8 = `bound_sd_1'
// putexcel K8 = `drop_sd_1'
// putexcel M8 = `drop_sd_0'

summ sharpe2 if one_sector_overweight == 0
local base_sd_0 = string(r(sd),"%3.2f")
local base_mean_0 = string(r(mean),"%3.2f")
summ sharpe if one_sector_overweight == 0
local bound_sd_0 = string(r(sd),"%3.2f")
local bound_mean_0 = string(r(mean),"%3.2f")
summ sharpe2 if one_sector_overweight == 1
local base_sd_1 = string(r(sd),"%3.2f")
local base_mean_1 = string(r(mean),"%3.2f")
summ sharpe if one_sector_overweight == 1
local bound_sd_1 = string(r(sd),"%3.2f")
local bound_mean_1 = string(r(mean),"%3.2f")
summ sharpe2 if one_sector_overweight == 0 & sharpe2 >= -1 & sharpe2 <= 10
local drop_sd_0 = string(r(sd),"%3.2f")
local drop_mean_0 = string(r(mean),"%3.2f")
summ sharpe2 if one_sector_overweight == 1 & sharpe2 >= -1 & sharpe2 <= 10
local drop_mean_1 = string(r(mean),"%3.2f")
local drop_sd_1 = string(r(sd),"%3.2f")

// putexcel B9 = `base_mean_1'
// putexcel D9 = `base_mean_0'
// putexcel F9 = `bound_mean_1'
// putexcel H9 = `bound_mean_0'
// putexcel J9 = `drop_mean_1'
// putexcel L9 = `drop_mean_0'
// putexcel C9 = `base_sd_1'
// putexcel E9 = `base_sd_0'
// putexcel I9 = `bound_sd_0'
// putexcel G9 = `bound_sd_1'
// putexcel K9 = `drop_sd_1'
// putexcel M9 = `drop_sd_0'

summ sharpe2 if goldbug16 == 0
local base_sd_0 = string(r(sd),"%3.2f")
local base_mean_0 = string(r(mean),"%3.2f")
summ sharpe if goldbug16 == 0
local bound_sd_0 = string(r(sd),"%3.2f")
local bound_mean_0 = string(r(mean),"%3.2f")
summ sharpe2 if goldbug16 == 1
local base_sd_1 = string(r(sd),"%3.2f")
local base_mean_1 = string(r(mean),"%3.2f")
summ sharpe if goldbug16 == 1
local bound_sd_1 = string(r(sd),"%3.2f")
local bound_mean_1 = string(r(mean),"%3.2f")
summ sharpe2 if goldbug16 == 0 & sharpe2 >= -1 & sharpe2 <= 10
local drop_sd_0 = string(r(sd),"%3.2f")
local drop_mean_0 = string(r(mean),"%3.2f")
summ sharpe2 if goldbug16 == 1 & sharpe2 >= -1 & sharpe2 <= 10
local drop_mean_1 = string(r(mean),"%3.2f")
local drop_sd_1 = string(r(sd),"%3.2f")

// putexcel B10 = `base_mean_1'
// putexcel D10 = `base_mean_0'
// putexcel F10 = `bound_mean_1'
// putexcel H10 = `bound_mean_0'
// putexcel J10 = `drop_mean_1'
// putexcel L10 = `drop_mean_0'
// putexcel C10 = `base_sd_1'
// putexcel E10 = `base_sd_0'
// putexcel I10 = `bound_sd_0'
// putexcel G10 = `bound_sd_1'
// putexcel K10 = `drop_sd_1'
// putexcel M10 = `drop_sd_0'

// putexcel close

}

// PIK UP HERE 
{ // sharpe ratio delta table -- bounded

use "$temp/streamlining assets affected", replace
gen adjust = dropped_dollars / total_assets
keep ScrubbedID adjust date
collapse (sum) adjust, by(ScrubbedID date)
save "$temp/streamlining assets affected clean", replace

use "$temp/guardrail assets affected", replace
gen date = 990 if guardrail == "_joint"
replace date = 991 if guardrail == "_non_intl"
replace date = 992 if guardrail == "_intl"
replace date = 993 if guardrail == "_eq_over"
replace date = 994 if guardrail == "_eq_under"
replace date = 995 if guardrail == "_sector"
replace date = 996 if guardrail == "_exp_ratio"
keep ScrubbedID adjust date
append using "$temp/streamlining assets affected clean"
save "$temp/change asset effects", replace

use "$temp/collapse2_combined.dta", clear
gen graph_helper = .

// fill in variables that are constant at ScrubbedID level but missing for guardrails
bys ScrubbedID: egen steady = max(steady_pre)
gen not_steady = (steady == 0)
foreach var in any_guardrail guardrail_not_intl total_intl_share_under total_eq_under total_eq_over total_exp_over one_sector_overweight {
	replace `var' = 0 if !(inlist(date, 672, 684) | date > 900 & !missing(date))
	bys ScrubbedID: egen `var'x = max(`var')
	replace `var' = `var'x
}

keep ScrubbedID date sharpe not_steady any_guardrail guardrail_not_intl total_intl_share_under total_eq_under total_eq_over total_exp_over one_sector_overweight
keep if inlist(date, 672, 684) | (date > 900 & !missing(date))

// merge in asset adjustments
merge 1:1 ScrubbedID date using "$temp/change asset effects"
drop if _m == 2
// assert _m == 3 if date != 684
drop _m

reshape wide sharpe adjust, i(ScrubbedID) j(date)

// determine how streamlining and guardrails affected sharpe ratios
// abbreviations for guardrails are g (guardrail), tdf (for guardrails pushing to tdf rather than idiosyncratic guardrail), and guardrail name abbreviation
local dates = "684 990 991 995 996 994 993 992"
local names "stream g_tdf_all g_tdf_nointl g_tdf_sec g_tdf_exp g_tdf_equnder g_tdf_eqover g_tdf_intl"
local count : word count `dates'

replace sharpe672 = 10 if sharpe672 > 10 & !missing(sharpe672)
replace sharpe672 = -1 if sharpe672 < -1

gen top_pre = sharpe672 == 10
gen bottom_pre = sharpe672 == -1

forvalues i = 1/`count' {
	local date : word `i' of `dates'
	local name : word `i' of `names'

	replace sharpe`date' = 10 if sharpe`date' > 10 & !missing(sharpe`date')
	replace sharpe`date' = -1 if sharpe`date' < -1

	gen delta_`name' = sharpe`date' - sharpe672
	replace delta_`name' = -1 if delta_`name' < -1
	replace delta_`name' = 1 if delta_`name' > 1 & !missing(delta_`name')

	gen pos_sharpe_`name' = (delta_`name' > 0) if !missing(delta_`name')
	gen neg_sharpe_`name' = (delta_`name' < 0) if !missing(delta_`name')
	gen zero_sharpe_`name' = (delta_`name' == 0) if !missing(delta_`name')

	rename sharpe`date' sharpe_`name'
	rename adjust`date' adjust_`name'
}
cap drop adjust_stream
rename adjust672 adjust_stream

{ // set up table
putexcel set "$output/62 - Delta Sharpe Ratio Table.xlsx", modify sheet("Bounded Delta and Sharpe")

putexcel A2 = "Streamlined"
putexcel A4 = "Any Guardrail"
putexcel A5 = "Any Non-International Guardrail"
putexcel A6 = "Sector Fund Guardrail"
putexcel A7 = "Expense Ratio Guardrail"
putexcel A8 = "Minimum Equity Exposure Guardrail"
putexcel A9 = "Maximum Equity Exposure Guardrail"
putexcel A10 = "International Equities As Share of Equities Guardrail"

putexcel A13 = "Note: Changes in Sharpe ratios are top-homed at 1 and bottom-homed at -1."
putexcel A14 = "Sharpe ratios are top-homed at 10 and bottom-homed at -1."
putexcel A15 = "Values are not weighted by assets."
putexcel A16 = "* Values in terms of standard deviations included in parentheses."
putexcel A17 = "* Standard deviations are calculated as the pre-reform standard deviation for the affected group."

putexcel B1 = "% of Investors Affected"
putexcel C1 = "% of Assets Affected in Affected Portfolios"
putexcel D1 = "% of Affected with Increased Sharpe Ratio"
putexcel E1 = "% of Affected with Decreased Sharpe Ratio"
putexcel F1 = "% of Affected with Same Sharpe Ratio"
putexcel G1 = "Mean Change for Affected"
putexcel H1 = "5th Percentile of Change for Affected*"
putexcel I1 = "Median Change for Affected"
putexcel J1 = "95th Percentile of Change for Affected*"
putexcel K1 = "Mean Change for Affected with Negative Change"
putexcel L1 = "Mean Change for Affected with Positive Change"
putexcel M1 = "Number with Positive Change in Sharpe Greater of Equal to Magnitude of Fifth Percentile Per Number at or Under Fifth Percentile"
putexcel B1:Z20, hcenter
putexcel B1:P1, border(bottom)
}

{ // fill in table with data
local names "stream g_tdf_all g_tdf_nointl g_tdf_sec g_tdf_exp g_tdf_equnder g_tdf_eqover g_tdf_intl"
local summary_vars = "not_steady any_guardrail guardrail_not_intl one_sector_overweight total_exp_over total_eq_under total_eq_over total_intl_share_under"

forvalues i = 1/`count' {
	if `i' == 1 {
		local row = `i' + 1
	}
	else {
		local row = `i' + 2
	}

	di "Row `row'"
	local name : word `i' of `names'
	local summary_var : word `i' of `summary_vars'

	summ `summary_var'
	local mean = r(mean)
	putexcel B`row' = formula(=`mean'), nformat("0.0%")

	summ delta_`name' if `summary_var' == 1, d
	local mean = r(mean)
	local fifth_num = r(p5)
	local median = r(p50)
	local ninetyfifth = r(p95)
	summ sharpe672 if `summary_var' == 1, d
	local sd = r(sd)
	local sd_fifth = `fifth_num' / `sd'
	local sd_median =`median' / `sd'
	local sd_mean = `mean' / `sd'
	local sd_ninetyfifth = `ninetyfifth' / `sd'
	local mean = string(`mean', "%9.2f")
	local fifth = string(`fifth_num', "%9.2f")
	local median = string(`median', "%9.2f")
	local ninetyfifth = string(`ninetyfifth', "%9.2f")
	local sd_fifth = string(`sd_fifth', "%9.3f")
	local sd_ninetyfifth = string(`sd_ninetyfifth', "%9.3f")
	local sd_median = string(`sd_median', "%9.3f")
	local sd_mean = string(`sd_mean', "%9.3f")
	local sd = string(`sd', "%9.3f")

	putexcel G`row' = ("`mean' (`sd_mean')")
	putexcel H`row' = ("`fifth' (`sd_fifth')")
	putexcel I`row' = ("`median' (`sd_median')")
	putexcel J`row' = ("`ninetyfifth' (`sd_ninetyfifth')")

	summ pos_sharpe_`name' if `summary_var' == 1
	local mean = r(mean)
	putexcel D`row' = formula(=`mean'), nformat("0.0%")

	summ neg_sharpe_`name' if `summary_var'== 1
	local mean = r(mean)
	putexcel E`row' = formula(=`mean'), nformat("0.0%")

	summ zero_sharpe_`name' if `summary_var' == 1
	local mean = r(mean)
	putexcel F`row' = formula(=`mean'), nformat("0.0%")

	summ adjust_`name' if `summary_var' == 1, d
	local mean = r(mean)
	putexcel C`row' = formula(=`mean'), nformat("0.0%")

	summ delta_`name' if `summary_var' == 1 & neg_sharpe_`name' == 1, d
	if r(N) == 0 {
		local mean = 0
	}
	else {
		local mean = r(mean)
		local mean = string(`mean', "%9.2f")
	}
	putexcel K`row' = (`mean')

	summ delta_`name' if `summary_var' == 1 & pos_sharpe_`name' == 1, d
	if r(N) == 0 {
		local mean = 0
	}
	else {
		local mean = r(mean)
		local mean = string(`mean', "%9.2f")
	}
	putexcel L`row' = (`mean')

	count if delta_`name' >= abs(`fifth_num') & `summary_var' == 1
	local count_over = r(N)
	count if delta_`name' <= `fifth_num' & `summary_var' == 1
	local count_under = r(N)
	local proportion = `count_over'/`count_under'
	di `proportion'
	putexcel M`row' = (`proportion')

}

}

putexcel close


}

{ // previous 5-year returns robustness check sharpe ratio delta table -- subset of original approach with 5 years of returns data
use "$temp/collapse2_combined.dta", clear
gen graph_helper = .

keep if five_years_flag == 1

// fill in variables that are constant at ScrubbedID level but missing for guardrails
bys ScrubbedID: egen steady = max(steady_pre)
gen not_steady = (steady == 0)
foreach var in any_guardrail guardrail_not_intl total_intl_share_under total_eq_under total_eq_over total_exp_over one_sector_overweight {
	bys ScrubbedID: egen `var'x = max(`var')
	replace `var' = `var'x
}


keep ScrubbedID date sharpe not_steady any_guardrail guardrail_not_intl total_intl_share_under total_eq_under total_eq_over total_exp_over one_sector_overweight
keep if inlist(date, 672, 684) | (date > 900 & !missing(date))

// merge in asset adjustments
merge 1:1 ScrubbedID date using "$temp/change asset effects"
drop if _m == 2
// assert _m == 3 if date != 684
drop _m

reshape wide sharpe adjust, i(ScrubbedID) j(date)


// determine how streamlining and guardrails affected sharpe ratios
// abbreviations for guardrails are g (guardrail), tdf (for guardrails pushing to tdf rather than idiosyncratic guardrail), and guardrail name abbreviation
local dates = "684 990 991 995 996 994 993 992"
local names "stream g_tdf_all g_tdf_nointl g_tdf_sec g_tdf_exp g_tdf_equnder g_tdf_eqover g_tdf_intl"
local count : word count `dates'

replace sharpe672 = 10 if sharpe672 > 10 & !missing(sharpe672)
replace sharpe672 = -1 if sharpe672 < -1


forvalues i = 1/`count' {
	local date : word `i' of `dates'
	local name : word `i' of `names'

	replace sharpe`date' = 10 if sharpe`date' > 10 & !missing(sharpe`date')
	replace sharpe`date' = -1 if sharpe`date' < -1

	gen delta_`name' = sharpe`date' - sharpe672
	replace delta_`name' = -1 if delta_`name' < -1
	replace delta_`name' = 1 if delta_`name' > 1 & !missing(delta_`name')

	gen pos_sharpe_`name' = (delta_`name' > 0) if !missing(delta_`name')
	gen neg_sharpe_`name' = (delta_`name' < 0) if !missing(delta_`name')
	gen zero_sharpe_`name' = (delta_`name' == 0) if !missing(delta_`name')

	rename sharpe`date' sharpe_`name'
	rename adjust`date' adjust_`name'
}
cap drop adjust_stream
rename adjust672 adjust_stream

{ // set up table
putexcel set "$output/62.1 - 5 Previous Years Delta Sharpe Ratio Table.xlsx", modify sheet("2 Year Ret (Subset w 5 years)")

putexcel A2 = "Streamlined"
putexcel A4 = "Any Guardrail"
putexcel A5 = "Any Non-International Guardrail"
putexcel A6 = "Sector Fund Guardrail"
putexcel A7 = "Expense Ratio Guardrail"
putexcel A8 = "Minimum Equity Exposure Guardrail"
putexcel A9 = "Maximum Equity Exposure Guardrail"
putexcel A10 = "International Equities As Share of Equities Guardrail"

putexcel A20 = "Note: Changes in Sharpe ratios are top-homed at 1 and bottom-homed at -1."
putexcel A21 = "Sharpe ratios are top-homed at 10 and bottom-homed at -1."
putexcel A22 = "Values are not weighted by assets."
putexcel A23 = "* Values in terms of standard deviations included in parentheses."
putexcel A24 = "* Standard deviations are calculated as the pre-reform standard deviation for the affected group."

putexcel B1 = "% of Investors Affected"
putexcel C1 = "% of Assets Affected in Affected Portfolios"
putexcel D1 = "% of Affected with Increased Sharpe Ratio"
putexcel E1 = "% of Affected with Decreased Sharpe Ratio"
putexcel F1 = "% of Affected with Same Sharpe Ratio"
putexcel G1 = "Mean Change for Affected"
putexcel H1 = "5th Percentile of Change for Affected*"
putexcel I1 = "Median Change for Affected"
putexcel J1 = "95th Percentile of Change for Affected*"
putexcel N1 = "Mean Change for Affected with Negative Change"
putexcel O1 = "Mean Change for Affected with Positive Change"
putexcel P1 = "Number with Positive Change in Sharpe Greater of Equal to Magnitude of Fifth Percentile Per Number at or Under Fifth Percentile"
putexcel B1:Z20, hcenter
putexcel B1:P1, border(bottom)
}

{ // fill in table with data
local names "stream g_tdf_all g_tdf_nointl g_tdf_sec g_tdf_exp g_tdf_equnder g_tdf_eqover g_tdf_intl"
local summary_vars = "not_steady any_guardrail guardrail_not_intl one_sector_overweight total_exp_over total_eq_under total_eq_over total_intl_share_under"

forvalues i = 1/`count' {
	if `i' == 1 {
		local row = `i' + 1
	}
	else {
		local row = `i' + 2
	}

	di "Row `row'"
	local name : word `i' of `names'
	local summary_var : word `i' of `summary_vars'

	summ `summary_var'
	local mean = r(mean)
	putexcel B`row' = formula(=`mean'), nformat("0.0%")

	summ delta_`name' if `summary_var' == 1, d
	local mean = r(mean)
	local fifth_num = r(p5)
	local median = r(p50)
	local ninetyfifth = r(p95)
	summ sharpe672 if `summary_var' == 1, d
	local sd = r(sd)
	local sd_fifth = `fifth_num' / `sd'
	local sd_median =`median' / `sd'
	local sd_mean = `mean' / `sd'
	local sd_ninetyfifth = `ninetyfifth' / `sd'
	local mean = string(`mean', "%9.2f")
	local fifth = string(`fifth_num', "%9.2f")
	local median = string(`median', "%9.2f")
	local ninetyfifth = string(`ninetyfifth', "%9.2f")
	local sd_fifth = string(`sd_fifth', "%9.3f")
	local sd_ninetyfifth = string(`sd_ninetyfifth', "%9.3f")
	local sd_median = string(`sd_median', "%9.3f")
	local sd_mean = string(`sd_mean', "%9.3f")
	local sd = string(`sd', "%9.3f")

	putexcel G`row' = ("`mean' (`sd_mean')")
	putexcel H`row' = ("`fifth' (`sd_fifth')")
	putexcel I`row' = ("`median' (`sd_median')")
	putexcel J`row' = ("`ninetyfifth' (`sd_ninetyfifth')")

	summ pos_sharpe_`name' if `summary_var' == 1
	local mean = r(mean)
	putexcel D`row' = formula(=`mean'), nformat("0.0%")

	summ neg_sharpe_`name' if `summary_var'== 1
	local mean = r(mean)
	putexcel E`row' = formula(=`mean'), nformat("0.0%")

	summ zero_sharpe_`name' if `summary_var' == 1
	local mean = r(mean)
	putexcel F`row' = formula(=`mean'), nformat("0.0%")

	summ adjust_`name' if `summary_var' == 1, d
	local mean = r(mean)
	putexcel C`row' = formula(=`mean'), nformat("0.0%")

	summ delta_`name' if `summary_var' == 1 & neg_sharpe_`name' == 1, d
	if r(N) == 0 {
		local mean = 0
	}
	else {
		local mean = r(mean)
		local mean = string(`mean', "%9.2f")
	}
	putexcel N`row' = (`mean')

	summ delta_`name' if `summary_var' == 1 & pos_sharpe_`name' == 1, d
	if r(N) == 0 {
		local mean = 0
	}
	else {
		local mean = r(mean)
		local mean = string(`mean', "%9.2f")
	}
	putexcel O`row' = (`mean')

	count if delta_`name' >= abs(`fifth_num') & `summary_var' == 1
	local count_over = r(N)
	count if delta_`name' <= `fifth_num' & `summary_var' == 1
	local count_under = r(N)
	local proportion = `count_over'/`count_under'
	di `proportion'
	putexcel P`row' = (`proportion')

}

}

putexcel close


}

{ // previous 5-year returns robustness check sharpe ratio delta table -- 5-year returns calculation
use "$temp/collapse2_combined.dta", clear

// filter to individuals with 5 years of returns
keep if five_years_flag == 1

gen graph_helper = .

// fill in variables that are constant at ScrubbedID level but missing for guardrails
bys ScrubbedID: egen steady = max(steady_pre)
gen not_steady = (steady == 0)
foreach var in any_guardrail guardrail_not_intl total_intl_share_under total_eq_under total_eq_over total_exp_over one_sector_overweight {
	bys ScrubbedID: egen `var'x = max(`var')
	replace `var' = `var'x
}


keep ScrubbedID date sharpe_fiveyear not_steady any_guardrail guardrail_not_intl total_intl_share_under total_eq_under total_eq_over total_exp_over one_sector_overweight
keep if inlist(date, 672, 684) | (date > 900 & !missing(date))

// merge in asset adjustments
merge 1:1 ScrubbedID date using "$temp/change asset effects"
drop if _m == 2
// assert _m == 3 if date != 684
drop _m

reshape wide sharpe_fiveyear adjust, i(ScrubbedID) j(date)


// determine how streamlining and guardrails affected sharpe ratios
// abbreviations for guardrails are g (guardrail), tdf (for guardrails pushing to tdf rather than idiosyncratic guardrail), and guardrail name abbreviation
local dates = "684 990 991 995 996 994 993 992"
local names "stream g_tdf_all g_tdf_nointl g_tdf_sec g_tdf_exp g_tdf_equnder g_tdf_eqover g_tdf_intl"
local count : word count `dates'

replace sharpe_fiveyear672 = 10 if sharpe_fiveyear672 > 10 & !missing(sharpe_fiveyear672)
replace sharpe_fiveyear672 = -1 if sharpe_fiveyear672 < -1


forvalues i = 1/`count' {
	local date : word `i' of `dates'
	local name : word `i' of `names'

	replace sharpe_fiveyear`date' = 10 if sharpe_fiveyear`date' > 10 & !missing(sharpe_fiveyear`date')
	replace sharpe_fiveyear`date' = -1 if sharpe_fiveyear`date' < -1

	gen delta_`name' = sharpe_fiveyear`date' - sharpe_fiveyear672
	replace delta_`name' = -1 if delta_`name' < -1
	replace delta_`name' = 1 if delta_`name' > 1 & !missing(delta_`name')

	gen pos_sharpe_`name' = (delta_`name' > 0) if !missing(delta_`name')
	gen neg_sharpe_`name' = (delta_`name' < 0) if !missing(delta_`name')
	gen zero_sharpe_`name' = (delta_`name' == 0) if !missing(delta_`name')

	rename sharpe_fiveyear`date' sharpe_fiveyear_`name'
	rename adjust`date' adjust_`name'
}
cap drop adjust_stream
rename adjust672 adjust_stream

{ // set up table
putexcel set "$output/62.1 - 5 Previous Years Delta Sharpe Ratio Table.xlsx", modify sheet("5 Year Returns")

putexcel A2 = "Streamlined"
putexcel A4 = "Any Guardrail"
putexcel A5 = "Any Non-International Guardrail"
putexcel A6 = "Sector Fund Guardrail"
putexcel A7 = "Expense Ratio Guardrail"
putexcel A8 = "Minimum Equity Exposure Guardrail"
putexcel A9 = "Maximum Equity Exposure Guardrail"
putexcel A10 = "International Equities As Share of Equities Guardrail"

putexcel A20 = "Note: Changes in Sharpe ratios are top-homed at 1 and bottom-homed at -1."
putexcel A21 = "Sharpe ratios are top-homed at 10 and bottom-homed at -1."
putexcel A22 = "Values are not weighted by assets."
putexcel A23 = "* Values in terms of standard deviations included in parentheses."
putexcel A24 = "* Standard deviations are calculated as the pre-reform standard deviation for the affected group."

putexcel B1 = "% of Investors Affected"
putexcel C1 = "% of Assets Affected in Affected Portfolios"
putexcel D1 = "% of Affected with Increased Sharpe Ratio"
putexcel E1 = "% of Affected with Decreased Sharpe Ratio"
putexcel F1 = "% of Affected with Same Sharpe Ratio"
putexcel G1 = "Mean Change for Affected"
putexcel H1 = "5th Percentile of Change for Affected*"
putexcel I1 = "Median Change for Affected"
putexcel J1 = "95th Percentile of Change for Affected*"
putexcel N1 = "Mean Change for Affected with Negative Change"
putexcel O1 = "Mean Change for Affected with Positive Change"
putexcel P1 = "Number with Positive Change in Sharpe Greater of Equal to Magnitude of Fifth Percentile Per Number at or Under Fifth Percentile"
putexcel B1:Z20, hcenter
putexcel B1:P1, border(bottom)
}

{ // fill in table with data
local names "stream g_tdf_all g_tdf_nointl g_tdf_sec g_tdf_exp g_tdf_equnder g_tdf_eqover g_tdf_intl"
local summary_vars = "not_steady any_guardrail guardrail_not_intl one_sector_overweight total_exp_over total_eq_under total_eq_over total_intl_share_under"
local count2 = `count' + 1

forvalues i = 1/`count' {

	if `i' == 1 {
		local row = `i' + 1
	}
	else {
		local row = `i' + 2
	}

	di "Row `row'"
	local name : word `i' of `names'
	local summary_var : word `i' of `summary_vars'

	summ `summary_var'
	local mean = r(mean)
	putexcel B`row' = formula(=`mean'), nformat("0.0%")

	summ delta_`name' if `summary_var' == 1, d
	local mean = r(mean)
	local fifth_num = r(p5)
	local median = r(p50)
	local ninetyfifth = r(p95)
	summ sharpe_fiveyear672 if `summary_var' == 1, d
	local sd = r(sd)
	local sd_fifth = `fifth_num' / `sd'
	local sd_median =`median' / `sd'
	local sd_mean = `mean' / `sd'
	local sd_ninetyfifth = `ninetyfifth' / `sd'
	local mean = string(`mean', "%9.2f")
	local fifth = string(`fifth_num', "%9.2f")
	local median = string(`median', "%9.2f")
	local ninetyfifth = string(`ninetyfifth', "%9.2f")
	local sd_fifth = string(`sd_fifth', "%9.3f")
	local sd_ninetyfifth = string(`sd_ninetyfifth', "%9.3f")
	local sd_median = string(`sd_median', "%9.3f")
	local sd_mean = string(`sd_mean', "%9.3f")
	local sd = string(`sd', "%9.3f")

	putexcel G`row' = ("`mean' (`sd_mean')")
	putexcel H`row' = ("`fifth' (`sd_fifth')")
	putexcel I`row' = ("`median' (`sd_median')")
	putexcel J`row' = ("`ninetyfifth' (`sd_ninetyfifth')")

	summ pos_sharpe_`name' if `summary_var' == 1
	local mean = r(mean)
	putexcel D`row' = formula(=`mean'), nformat("0.0%")

	summ neg_sharpe_`name' if `summary_var'== 1
	local mean = r(mean)
	putexcel E`row' = formula(=`mean'), nformat("0.0%")

	summ zero_sharpe_`name' if `summary_var' == 1
	local mean = r(mean)
	putexcel F`row' = formula(=`mean'), nformat("0.0%")

	summ adjust_`name' if `summary_var' == 1, d
	local mean = r(mean)
	putexcel C`row' = formula(=`mean'), nformat("0.0%")

	summ delta_`name' if `summary_var' == 1 & neg_sharpe_`name' == 1, d
	if r(N) == 0 {
		local mean = 0
	}
	else {
		local mean = r(mean)
		local mean = string(`mean', "%9.2f")
	}
	putexcel N`row' = (`mean')

	summ delta_`name' if `summary_var' == 1 & pos_sharpe_`name' == 1, d
	if r(N) == 0 {
		local mean = 0
	}
	else {
		local mean = r(mean)
		local mean = string(`mean', "%9.2f")
	}
	putexcel O`row' = (`mean')

	count if delta_`name' >= abs(`fifth_num') & `summary_var' == 1
	local count_over = r(N)
	count if delta_`name' <= `fifth_num' & `summary_var' == 1
	local count_under = r(N)
	local proportion = `count_over'/`count_under'
	di `proportion'
	putexcel P`row' = (`proportion')

}

}

putexcel close


}

{ // ex ante sharpe ratio delta table
use "$temp/collapse2_combined.dta", clear
gen graph_helper = .

// fill in variables that are constant at ScrubbedID level but missing for guardrails
bys ScrubbedID: egen steady = max(steady_pre)
gen not_steady = (steady == 0)
foreach var in any_guardrail guardrail_not_intl total_intl_share_under total_eq_under total_eq_over total_exp_over one_sector_overweight {
	replace `var' = 0 if !(inlist(date, 672, 684) | date > 900 & !missing(date))
	bys ScrubbedID: egen `var'x = max(`var')
	replace `var' = `var'x
}

gen ante_sharpe = ante_ret / ante_sd

keep ScrubbedID date ante_sharpe not_steady any_guardrail guardrail_not_intl total_intl_share_under total_eq_under total_eq_over total_exp_over one_sector_overweight
keep if inlist(date, 672, 684) | (date > 900 & !missing(date))

// merge in asset adjustments
merge 1:1 ScrubbedID date using "$temp/change asset effects"
drop if _m == 2
// assert _m == 3 if date != 684
drop _m

reshape wide ante_sharpe adjust, i(ScrubbedID) j(date)


// determine how streamlining and guardrails affected sharpe ratios
// abbreviations for guardrails are g (guardrail), tdf (for guardrails pushing to tdf rather than idiosyncratic guardrail), and guardrail name abbreviation
local dates = "684 990 991 995 996 994 993 992"
local names "stream g_tdf_all g_tdf_nointl g_tdf_sec g_tdf_exp g_tdf_equnder g_tdf_eqover g_tdf_intl"
local count : word count `dates'

replace ante_sharpe672 = 10 if ante_sharpe672 > 10 & !missing(ante_sharpe672)
replace ante_sharpe672 = -1 if ante_sharpe672 < -1

gen top_pre = ante_sharpe672 == 10
gen bottom_pre = ante_sharpe672 == -1

forvalues i = 1/`count' {
	local date : word `i' of `dates'
	local name : word `i' of `names'

	replace ante_sharpe`date' = 10 if ante_sharpe`date' > 10 & !missing(ante_sharpe`date')
	replace ante_sharpe`date' = -1 if ante_sharpe`date' < -1

	gen delta_`name' = ante_sharpe`date' - ante_sharpe672
	replace delta_`name' = -1 if delta_`name' < -1
	replace delta_`name' = 1 if delta_`name' > 1 & !missing(delta_`name')

	gen pos_sharpe_`name' = (delta_`name' > 0) if !missing(delta_`name')
	gen neg_sharpe_`name' = (delta_`name' < 0) if !missing(delta_`name')
	gen zero_sharpe_`name' = (delta_`name' == 0) if !missing(delta_`name')

	rename ante_sharpe`date' ante_sharpe_`name'
	rename adjust`date' adjust_`name'
}
cap drop adjust_stream
rename adjust672 adjust_stream

{ // set up table
putexcel set "$output/71 - Ex Ante Delta Sharpe Ratio Table.xlsx", modify sheet("Ex Ante")

putexcel A2 = "Streamlined"
putexcel A4 = "Any Guardrail"
putexcel A5 = "Any Non-International Guardrail"
putexcel A6 = "Sector Fund Guardrail"
putexcel A7 = "Expense Ratio Guardrail"
putexcel A8 = "Minimum Equity Exposure Guardrail"
putexcel A9 = "Maximum Equity Exposure Guardrail"
putexcel A10 = "International Equities As Share of Equities Guardrail"

putexcel A13 = "Note: Changes in Sharpe ratios are top-homed at 1 and bottom-homed at -1."
putexcel A14 = "Sharpe ratios are top-homed at 10 and bottom-homed at -1."
putexcel A15 = "Values are not weighted by assets."
putexcel A16 = "* Values in terms of standard deviations included in parentheses."
putexcel A17 = "* Standard deviations are calculated as the pre-reform standard deviation for the affected group."

putexcel B1 = "% of Investors Affected"
putexcel C1 = "% of Assets Affected in Affected Portfolios"
putexcel D1 = "% of Affected with Increased Sharpe Ratio"
putexcel E1 = "% of Affected with Decreased Sharpe Ratio"
putexcel F1 = "% of Affected with Same Sharpe Ratio"
putexcel G1 = "Mean Change for Affected"
putexcel H1 = "5th Percentile of Change for Affected*"
putexcel I1 = "Median Change for Affected"
putexcel J1 = "95th Percentile of Change for Affected*"
putexcel K1 = "Mean Change for Affected with Negative Change"
putexcel L1 = "Mean Change for Affected with Positive Change"
putexcel M1 = "Number with Positive Change in Sharpe Greater of Equal to Magnitude of Fifth Percentile Per Number at or Under Fifth Percentile"
putexcel B1:Z20, hcenter
putexcel B1:P1, border(bottom)
}

{ // fill in table with data
local names "stream g_tdf_all g_tdf_nointl g_tdf_sec g_tdf_exp g_tdf_equnder g_tdf_eqover g_tdf_intl"
local summary_vars = "not_steady any_guardrail guardrail_not_intl one_sector_overweight total_exp_over total_eq_under total_eq_over total_intl_share_under"

forvalues i = 1/`count' {
	if `i' == 1 {
		local row = `i' + 1
	}
	else {
		local row = `i' + 2
	}

	di "Row `row'"
	local name : word `i' of `names'
	local summary_var : word `i' of `summary_vars'

	summ `summary_var'
	local mean = r(mean)
	putexcel B`row' = formula(=`mean'), nformat("0.0%")

	summ delta_`name' if `summary_var' == 1, d
	local mean = r(mean)
	local fifth_num = r(p5)
	local median = r(p50)
	local ninetyfifth = r(p95)
	summ ante_sharpe672 if `summary_var' == 1, d
	local sd = r(sd)
	local sd_fifth = `fifth_num' / `sd'
	local sd_median =`median' / `sd'
	local sd_mean = `mean' / `sd'
	local sd_ninetyfifth = `ninetyfifth' / `sd'
	local mean = string(`mean', "%9.2f")
	local fifth = string(`fifth_num', "%9.2f")
	local median = string(`median', "%9.2f")
	local ninetyfifth = string(`ninetyfifth', "%9.2f")
	local sd_fifth = string(`sd_fifth', "%9.3f")
	local sd_ninetyfifth = string(`sd_ninetyfifth', "%9.3f")
	local sd_median = string(`sd_median', "%9.3f")
	local sd_mean = string(`sd_mean', "%9.3f")
	local sd = string(`sd', "%9.3f")

	putexcel G`row' = ("`mean' (`sd_mean')")
	putexcel H`row' = ("`fifth' (`sd_fifth')")
	putexcel I`row' = ("`median' (`sd_median')")
	putexcel J`row' = ("`ninetyfifth' (`sd_ninetyfifth')")

	summ pos_sharpe_`name' if `summary_var' == 1
	local mean = r(mean)
	putexcel D`row' = formula(=`mean'), nformat("0.0%")

	summ neg_sharpe_`name' if `summary_var'== 1
	local mean = r(mean)
	putexcel E`row' = formula(=`mean'), nformat("0.0%")

	summ zero_sharpe_`name' if `summary_var' == 1
	local mean = r(mean)
	putexcel F`row' = formula(=`mean'), nformat("0.0%")

	summ adjust_`name' if `summary_var' == 1, d
	local mean = r(mean)
	putexcel C`row' = formula(=`mean'), nformat("0.0%")

	summ delta_`name' if `summary_var' == 1 & neg_sharpe_`name' == 1, d
	if r(N) == 0 {
		local mean = 0
	}
	else {
		local mean = r(mean)
		local mean = string(`mean', "%9.2f")
	}
	putexcel K`row' = (`mean')

	summ delta_`name' if `summary_var' == 1 & pos_sharpe_`name' == 1, d
	if r(N) == 0 {
		local mean = 0
	}
	else {
		local mean = r(mean)
		local mean = string(`mean', "%9.2f")
	}
	putexcel L`row' = (`mean')

	count if delta_`name' >= abs(`fifth_num') & `summary_var' == 1
	local count_over = r(N)
	count if delta_`name' <= `fifth_num' & `summary_var' == 1
	local count_under = r(N)
	local proportion = `count_over'/`count_under'
	di `proportion'
	putexcel M`row' = (`proportion')

}

}

putexcel close


}

{ // income category sharpe ratio delta table -- bounded
use "$temp/collapse2_combined.dta", clear
gen graph_helper = .

// fill in variables that are constant at ScrubbedID level but missing for guardrails
bys ScrubbedID: egen steady = max(steady_pre)
gen not_steady = (steady == 0)
foreach var in any_guardrail guardrail_not_intl total_intl_share_under total_eq_under total_eq_over total_exp_over one_sector_overweight {
	bys ScrubbedID: egen `var'x = max(`var')
	replace `var' = `var'x
}

// fill in missing salaries
bys ScrubbedID: egen salary = max(RoundedSalary)

keep ScrubbedID date sharpe not_steady any_guardrail guardrail_not_intl total_intl_share_under total_eq_under total_eq_over total_exp_over one_sector_overweight salary


gen sal_group = 1 if (salary > 0 & salary <= 30000)
replace sal_group = 2 if (salary > 30000 & salary <= 60000)
replace sal_group = 3 if (salary > 60000 & salary <= 100000)
replace sal_group = 4 if (salary > 100000 & salary <= 200000)
replace sal_group = 5 if (salary > 200000 & salary < .)
replace sal_group = 6 if missing(salary) | salary == 0
// assert !missing(sal_group)

la define sal_group 1 "Salary 30,000 or under" ///
2 "30,000-60,000" ///
3 "60,000-100,000" ///
4 "100,000-200,000" ///
5 "200,000+" ///
6 "Salary data missing"
la val sal_group sal_group


keep if inlist(date, 672, 684, 991)

reshape wide sharpe, i(ScrubbedID) j(date)


// determine how streamlining and guardrails affected sharpe ratios
// abbreviations for guardrails are g (guardrail), tdf (for guardrails pushing to tdf rather than idiosyncratic guardrail), and guardrail name abbreviation
local dates = "684 991"
local names "stream g_tdf_nointl"
local count : word count `dates'

replace sharpe672 = 10 if sharpe672 > 10 & !missing(sharpe672)
replace sharpe672 = -1 if sharpe672 < -1


forvalues i = 1/`count' {
	local date : word `i' of `dates'
	local name : word `i' of `names'

	replace sharpe`date' = 10 if sharpe`date' > 10 & !missing(sharpe`date')
	replace sharpe`date' = -1 if sharpe`date' < -1

	gen delta_`name' = sharpe`date' - sharpe672
	replace delta_`name' = -1 if delta_`name' < -1
	replace delta_`name' = 1 if delta_`name' > 1 & !missing(delta_`name')

	gen pos_sharpe_`name' = (delta_`name' > 0) if !missing(delta_`name')
	gen neg_sharpe_`name' = (delta_`name' < 0) if !missing(delta_`name')
	gen zero_sharpe_`name' = (delta_`name' == 0) if !missing(delta_`name')

	rename sharpe`date' sharpe_`name'
}

preserve
	keep if not_steady == 1
	collapse (mean) delta_stream (p5) stream_p5 = delta_stream, by(sal_group)
	save "$temp/not_steady_income", replace
restore

preserve
	keep if guardrail_not_intl == 1
	collapse (mean) delta_g_tdf_nointl (p5) nonintl_p5 = delta_g_tdf_nointl, by(sal_group)
	save "$temp/nonintl_guardrail_income", replace
restore

gen counter = 1
collapse (sum) counter (mean) not_steady guardrail_not_intl, by(sal_group)

merge 1:1 sal_group using "$temp/not_steady_income"
// assert _m == 3
drop _m

merge 1:1 sal_group using "$temp/nonintl_guardrail_income"
// assert _m == 3
drop _m


la var sal_group "Salary"
la var counter "N"
la var not_steady "% Affected By Streamlining"
la var guardrail_not_intl "% Affected By Non Intl Guardrails"
la var delta_stream "Mean Change in Sharpe for Those Affected By Streamlining"
la var delta_g_tdf_nointl "Mean Change in Sharpe for Those Affected By Non Intl Guardrail"
la var stream_p5 "5th Percent of Change in Sharpe for Those Affected By Streamlining"
la var nonintl_p5 "5th Percent of Change in Sharpe for Those Affected By Non Intl Guardrail"

order sal_group counter not_steady delta_stream stream_p5 guardrail_not_intl delta_g_tdf_nointl nonintl_p5

// export excel using "$output/69 - Income Delta Sharpe Ratio Table.xlsx", ///
// firstrow(varlabels) keepcellfmt replace


}

}

if `chapter5'==1 {
	use "$temp/collapse2_combined", clear

	keep if inlist(date, 672)

	merge 1:m Scr using "$temp/fid_tdf"
	replace fid_right_tdf = 0 if fid_right_tdf == .
	drop if _m == 2

	gen age = AgeasofNov2018 - 2

	gen risk = var_used
	gen ret = return_used

	gen age30 = cond(age < 35, 1, 0)
	gen age40 = cond(age > 34 & age < 45, 1, 0)
	gen age50 = cond(age > 44 & age < 55, 1, 0)
	gen age60 = cond(age > 54 & age < 65, 1, 0)
	gen age70 = cond(age > 64, 1, 0)

	foreach i of numlist 30 40 50 60 70 {

		gen risk`i'_helper = risk if age == `i' & fid_right_tdf == 1
		egen risk`i' = max(risk`i')
		drop risk`i'_helper

		gen ret`i'_helper = ret if age == `i' & fid_right_tdf == 1
		egen ret`i' = max(ret`i')
		drop ret`i'_helper

	}

	drop if smart
	drop if fid_right_tdf == 1
	drop if van_tdf1 == 1
	drop if guardrail_not_intl == 1

	foreach i of numlist 30 40 50 60 70 {

		drop if risk == risk`i'
		drop if ret == ret`i'

	}

	foreach i of numlist 30 40 50 60 70 {

		gen lh`i' = 0 if age`i' == 1
		replace lh`i' = 1 if risk < risk`i' & ret > ret`i' & lh`i' == 0

		gen ll`i' = 0 if age`i' == 1
		replace ll`i' = 1 if risk < risk`i' & ret < ret`i' & ll`i' == 0

		gen hh`i' = 0 if age`i' == 1
		replace hh`i' = 1 if risk > risk`i' & ret > ret`i' & hh`i' == 0

		gen hl`i' = 0 if age`i' == 1
		replace hl`i' = 1 if risk > risk`i' & ret < ret`i' & hl`i' == 0

	}

	gen check30 = 1 if lh30 | ll30 | hl30 | hh30

	/*
	foreach i of numlist 30 40 50 60 70 {

		gen lh`i' = .
		replace lh`i' = 1 if risk < risk`i' & ret > ret`i' & age`i' == 1
		replace lh`i' = 0 if age`i' == 1 & lh`i' == .

		gen ll`i' = .
		replace ll`i' = 1 if risk < risk`i' & ret < ret`i' & age`i' == 1
		replace ll`i' = 0 if age`i' == 1 & ll`i' == .

		gen hh`i' = .
		replace hh`i' = 1 if risk > risk`i' & ret > ret`i' & age`i' == 1
		replace hh`i' = 0 if age`i' == 1 & hh`i' == .

		gen hl`i' = .
		replace hl`i' = 1 if risk > risk`i' & ret < ret`i' & age`i' == 1
		replace hl`i' = 0 if age`i' == 1 & hl`i' == .

	}
	*/
	gen lh = .
	foreach i of numlist 30 40 50 60 70 {

		replace lh = 1 if risk < risk`i' & ret > ret`i' & age`i' == 1
		replace lh = 0 if age`i' == 1 & lh == .

	}

	gen ll = .
	foreach i of numlist 30 40 50 60 70 {

		replace ll = 1 if risk < risk`i' & ret < ret`i' & age`i' == 1
		replace ll = 0 if age`i' == 1 & ll == .

	}

	gen hh = .
	foreach i of numlist 30 40 50 60 70 {

		replace hh = 1 if risk > risk`i' & ret > ret`i' & age`i' == 1
		replace hh = 0 if age`i' == 1 & hh == .

	}

	gen hl = .
	foreach i of numlist 30 40 50 60 70 {

		replace hl = 1 if risk > risk`i' & ret < ret`i' & age`i' == 1
		replace hl = 0 if age`i' == 1 & hl == .

	}

// Table 5.9
	putexcel set "$output/chapter5.xlsx", replace firstrow(varlabels) sheet("5.9")

	putexcel C1:D1, hcenter merge
	putexcel C2:G2, hcenter merge
	putexcel A2:B2, hcenter merge

	putexcel C1 = "Risk Return Table (Only Non-Violators)"
	putexcel A2 = "Category"

	putexcel A3 = "Risk"
	putexcel A4 = "Lower"
	putexcel A5 = "Lower"
	putexcel A6 = "Higher"
	putexcel A7 = "Higher"

	putexcel B3 = "Return"
	putexcel B4 = "Higher"
	putexcel B5 = "Lower"
	putexcel B6 = "Higher"
	putexcel B7 = "Lower"

	putexcel C2 = "Participants in each Category, by Age and Overall"

	sum age30
	local mean = string(r(mean))
	local mean = `mean' * 100
	local mean : di %5.2f `mean'

	putexcel C3 = "25-35 (`mean'%)", hcenter

	sum age40
	local mean = string(r(mean))
	local mean = `mean' * 100
	local mean : di %5.2f `mean'

	putexcel D3 = "35-45 (`mean'%)", hcenter

	sum age50
	local mean = string(r(mean))
	local mean = `mean' * 100
	local mean : di %5.2f `mean'

	putexcel E3 = "45-55 (`mean'%)", hcenter

	sum age60
	local mean = string(r(mean))
	local mean = `mean' * 100
	local mean : di %5.2f `mean'

	putexcel F3 = "55-65 (`mean'%)", hcenter

	sum age70
	local mean = string(r(mean))
	local mean = `mean' * 100
	local mean : di %5.2f `mean'

	putexcel G3 = "65-75 (`mean'%)", hcenter

	putexcel H3 = "Overall"

	local i = 4

	foreach x in "lh30" "ll30" "hh30" "hl30" {

		sum `x'
		local mean = string(r(mean))
		di `mean'
		putexcel C`i' = `mean'
		local i=`i'+1

	}

	local i = 4

	foreach x in "lh40" "ll40" "hh40" "hl40" {

		sum `x'
		local mean = string(r(mean))
		putexcel D`i' = `mean'
		local i=`i'+1

	}

	local i = 4

	foreach x in "lh50" "ll50" "hh50" "hl50" {

		sum `x'
		local mean = string(r(mean))
		putexcel E`i' = `mean'
		local i=`i'+1

	}

	local i = 4

	foreach x in "lh60" "ll60" "hh60" "hl60" {

		sum `x'
		local mean = string(r(mean))
		putexcel F`i' = `mean'
		local i=`i'+1

	}

	local i = 4

	foreach x in "lh70" "ll70" "hh70" "hl70" {

		sum `x'
		local mean = string(r(mean))
		putexcel G`i' = `mean'
		local i=`i'+1

	}

	local i = 4

	foreach x in "lh" "ll" "hh" "hl" {

		sum `x'
		local mean = string(r(mean))
		putexcel H`i' = `mean'
		local i=`i'+1

	}

	putexcel close


	// Table 5.11

	use "$temp/collapse2_combined.dta", clear

	keep if inlist(date,672)

	putexcel set "$output/81 - Guardrails Sharpe Means.xlsx", replace
	putexcel A4 = "Expense Error: Average Expense Ratio Over 75 Basis Points"
	putexcel A5 = "Exposure Error: Equities Share Less Than Half or More Than Double Benchmark TDF"
	putexcel A6 = "Minimum Equity Exposure Guardrail"
	putexcel A7 = "Maximum Equity Exposure Guardrail"
	putexcel A8 = "Diversification Error: International Equities Underweighted (Less Than 20% Equities)"
	putexcel A9 = "Diversification Error: Single Sector Fund Overweighted"
	putexcel A10 = "Goldbugs"
	putexcel A11 = "Any Diversification Error"
	putexcel A12 = "Any Non-International Error"
	putexcel A13 = "Any Error"

	putexcel B1 = "Idiosyncratic Risk Delta"
	putexcel B2 = "Violating Guardrail"
	putexcel C2 = "Not Violating Guardrail"
	putexcel B3 = "Mean", hcenter
	putexcel C3 = "Mean", hcenter
	putexcel D3 = "Delta (t-test)", hcenter

	summ sharpe if total_exp_over == 1
	local base_mean_0 = string(r(mean))

	summ sharpe if total_exp_over == 0
	local base_mean_1 = string(r(mean))

	putexcel B4 = `base_mean_0'
	putexcel C4 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest sharpe, by(total_exp_over)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D4 = "`delta'`stars'"

	summ sharpe if total_eq_violation == 1
	local base_mean_0 = string(r(mean))

	summ sharpe if total_eq_violation == 0
	local base_mean_1 = string(r(mean))

	putexcel B5 = `base_mean_0'
	putexcel C5 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest sharpe, by(total_eq_violation)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D5 = "`delta'`stars'"

	summ sharpe if total_eq_under == 1
	local base_mean_0 = string(r(mean))

	summ sharpe if total_eq_under == 0
	local base_mean_1 = string(r(mean))

	putexcel B6 = `base_mean_0'
	putexcel C6 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest sharpe, by(total_eq_under)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D6 = "`delta'`stars'"

	summ sharpe if total_eq_over == 1
	local base_mean_0 = string(r(mean))

	summ sharpe if total_eq_over == 0
	local base_mean_1 = string(r(mean))

	putexcel B7 = `base_mean_0'
	putexcel C7 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest sharpe, by(total_eq_over)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D7 = "`delta'`stars'"

	summ sharpe if total_intl_share_under == 1
	local base_mean_0 = string(r(mean))

	summ sharpe if total_intl_share_under == 0
	local base_mean_1 = string(r(mean))

	putexcel B8 = `base_mean_0'
	putexcel C8 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest sharpe, by(total_intl_share_under)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D8 = "`delta'`stars'"

	summ sharpe if one_sector_overweight == 1
	local base_mean_0 = string(r(mean))

	summ sharpe if one_sector_overweight == 0
	local base_mean_1 = string(r(mean))

	putexcel B9 = `base_mean_0'
	putexcel C9 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest sharpe, by(one_sector_overweight)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D9 = "`delta'`stars'"

	summ sharpe if goldbug16 == 1
	local base_mean_0 = string(r(mean))

	summ sharpe if goldbug16 == 0
	local base_mean_1 = string(r(mean))

	putexcel B10 = `base_mean_0'
	putexcel C10 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest sharpe, by(goldbug16)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D10 = "`delta'`stars'"


	summ sharpe if guardrail_div == 1
	local base_mean_0 = string(r(mean))

	summ sharpe if guardrail_div == 0
	local base_mean_1 = string(r(mean))

	putexcel B11 = `base_mean_0'
	putexcel C11 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest sharpe, by(guardrail_div)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D11 = "`delta'`stars'"

	summ sharpe if guardrail_not_intl == 1
	local base_mean_0 = string(r(mean))

	summ sharpe if guardrail_not_intl == 0
	local base_mean_1 = string(r(mean))

	putexcel B12 = `base_mean_0'
	putexcel C12 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest sharpe, by(guardrail_not_intl)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D12 = "`delta'`stars'"

	summ sharpe if any_guardrail == 1
	local base_mean_0 = string(r(mean))

	summ sharpe if any_guardrail == 0
	local base_mean_1 = string(r(mean))

	putexcel B13 = `base_mean_0'
	putexcel C13 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest sharpe, by(any_guardrail)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D13 = "`delta'`stars'"

	putexcel close

	putexcel close // try commenting out - do I need this?

	// Table 5.13
	{ // RMSE for guardrails
	use "$temp/collapse2_combined.dta", clear

	keep if inlist(date,672)

	putexcel set "$output/chapter5", replace sheet("5.13") firstrow(varlabels)
	putexcel A4 = "Expense Error: Average Expense Ratio Over 75 Basis Points"
	putexcel A5 = "Exposure Error: Equities Share Less Than Half or More Than Double Benchmark TDF"
	putexcel A6 = "Minimum Equity Exposure Guardrail"
	putexcel A7 = "Maximum Equity Exposure Guardrail"
	putexcel A8 = "Diversification Error: International Equities Underweighted (Less Than 20% Equities)"
	putexcel A9 = "Diversification Error: Single Sector Fund Overweighted"
	putexcel A10 = "Goldbugs"
	putexcel A11 = "Any Diversification Error"
	putexcel A12 = "Any Non-International Error"
	putexcel A13 = "Any Error"

	putexcel B1 = "Idiosyncratic Risk Delta"
	putexcel B2 = "Violating Guardrail"
	putexcel C2 = "Not Violating Guardrail"
	putexcel B3 = "Mean", hcenter
	putexcel C3 = "Mean", hcenter
	putexcel D3 = "Delta (t-test)", hcenter

	summ _rmse if total_exp_over == 1
	local base_mean_0 = string(r(mean))

	summ _rmse if total_exp_over == 0
	local base_mean_1 = string(r(mean))

	putexcel B4 = `base_mean_0'
	putexcel C4 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest _rmse, by(total_exp_over)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D4 = "`delta'`stars'"

	summ _rmse if total_eq_violation == 1
	local base_mean_0 = string(r(mean))

	summ _rmse if total_eq_violation == 0
	local base_mean_1 = string(r(mean))

	putexcel B5 = `base_mean_0'
	putexcel C5 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest _rmse, by(total_eq_violation)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D5 = "`delta'`stars'"

	summ _rmse if total_eq_under == 1
	local base_mean_0 = string(r(mean))

	summ _rmse if total_eq_under == 0
	local base_mean_1 = string(r(mean))

	putexcel B6 = `base_mean_0'
	putexcel C6 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest _rmse, by(total_eq_under)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D6 = "`delta'`stars'"

	summ _rmse if total_eq_over == 1
	local base_mean_0 = string(r(mean))

	summ _rmse if total_eq_over == 0
	local base_mean_1 = string(r(mean))

	putexcel B7 = `base_mean_0'
	putexcel C7 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest _rmse, by(total_eq_over)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D7 = "`delta'`stars'"

	summ _rmse if total_intl_share_under == 1
	local base_mean_0 = string(r(mean))

	summ _rmse if total_intl_share_under == 0
	local base_mean_1 = string(r(mean))

	putexcel B8 = `base_mean_0'
	putexcel C8 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest _rmse, by(total_intl_share_under)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D8 = "`delta'`stars'"

	summ _rmse if one_sector_overweight == 1
	local base_mean_0 = string(r(mean))

	summ _rmse if one_sector_overweight == 0
	local base_mean_1 = string(r(mean))

	putexcel B9 = `base_mean_0'
	putexcel C9 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest _rmse, by(one_sector_overweight)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D9 = "`delta'`stars'"

	summ _rmse if goldbug16 == 1
	local base_mean_0 = string(r(mean))

	summ _rmse if goldbug16 == 0
	local base_mean_1 = string(r(mean))

	putexcel B10 = `base_mean_0'
	putexcel C10 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest _rmse, by(goldbug16)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D10 = "`delta'`stars'"

	summ _rmse if guardrail_div == 1
	local base_mean_0 = string(r(mean))

	summ _rmse if guardrail_div == 0
	local base_mean_1 = string(r(mean))

	putexcel B11 = `base_mean_0'
	putexcel C11 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest _rmse, by(guardrail_div)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D11 = "`delta'`stars'"

	summ _rmse if guardrail_not_intl == 1
	local base_mean_0 = string(r(mean))

	summ _rmse if guardrail_not_intl == 0
	local base_mean_1 = string(r(mean))

	putexcel B12 = `base_mean_0'
	putexcel C12 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest _rmse, by(guardrail_not_intl)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D12 = "`delta'`stars'"

	summ _rmse if any_guardrail == 1
	local base_mean_0 = string(r(mean))

	summ _rmse if any_guardrail == 0
	local base_mean_1 = string(r(mean))

	putexcel B13 = `base_mean_0'
	putexcel C13 = `base_mean_1'

	local delta = `base_mean_0' - `base_mean_1'
	local delta : di %8.4f `delta'

	ttest _rmse, by(any_guardrail)
	return list
	local p_val = `r(p)'

	local stars = ""
	di `p_val'

		if (`p_val' < .1) {
			local stars = "*"
		}
		if (`p_val' < .05) {
			local stars = "**"
		}
		if (`p_val' < .01) {
			local stars = "***"
		}

	putexcel D13 = "`delta'`stars'"

	putexcel close

	}


}


if `chapter8'==1 {
use "$temp/fund_types_summary", clear

preserve
	gen counter = 1
	collapse (count) count = counter , by(fund_type date)

	reshape wide count, i(fund_type) j(date)
	replace count684 = 0 if missing(count684)


	la var count672 "Pre-Reform"
	la var count684 "Post-Reform"
	la var fund_type "Fund Type"
	export excel using "$output/chapter8.xlsx", replace firstrow(varlabels) sheet("8.1")
restore
}
