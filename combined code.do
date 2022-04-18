// all the dos up until 16 
* To do: add the R dos

/*
Guardrails Master File
ZRS + PD 
*/


{ // setup
clear all

cap log close

global home "C:/Users/ylsta/Dropbox/Retirement Menu Design"

global input "$home/code/STATA -- ZS/Input"
global temp "$home/code/STATA -- ZS/Temp_ORP"
global code "$home/code/STATA -- ZS/Code PD"
global output "$home/code/STATA -- ZS/Output_ORP"
global log "$home/code/STATA -- ZS/Log"

sysdir set PERSONAL "$code/ado"
//set scheme zrs, perm
set more off, perm		

global color_p2 = "86 180 233"
global color_p3 = "230 159 0"
global color_p4 = "0 205 150"


graph set window fontface "Times New Roman"

log using "$log/Analysis", replace

set maxvar 20000

}


{ // set levels that flag overweighting
global tot_mm_lev = .2
global ind_sec_lev = .1
global ind_gold_lev = .1
global tot_sec_lev = .5	
global intl_eq_perc = .2
global exp_ratio_cap = .0075

}


qui do "$code/01 setup.do" // done 

qui do "$code/02 Cleaning Step One.do" // done 

qui do "$code/03a Counterfactual Setup -- Joint -- All TDFs.do"
qui do "$code/03b Counterfactual Setup -- Sector -- All TDFs.do"
qui do "$code/03c Counterfactual Setup -- Expense Ratio -- All TDFs.do"
qui do "$code/03d Counterfactual Setup -- Equities Under -- All TDFs.do"
qui do "$code/03e Counterfactual Setup -- Equities Over -- All TDFs.do"
qui do "$code/03f Counterfactual Setup -- Intl Share of Equities -- All TDFs.do"
qui do "$code/03g Counterfactual Setup -- Summarize Share Affected -- All TDFs.do"

qui do "$code/04 Individual Portfolio Moments.do"

qui do "$code/05 Cleaning Step Two.do"

qui do "$code/06 Cleaning Step Three.do"

qui do "$code/07 Baseline Graphs.do"

qui do "$code/08 Reallocation Summary.do"

qui do "$code/09 Overweighting Tables.do"

qui do "$code/10 Fund Types Summary.do"

qui do "$code/11 Guardrails CRRA Analysis.do"

qui do "$code/12 Baseline CRRA Analysis.do"

qui do "$code/13 Testing Factors.do"

qui do "$code/14 Miscellaneous.do"

qui do "$code/15 Participation.do"


cap log close

/** Go to streamlined data --> just look at those funds that are not the affirmative choice participants (look at unaffected portfolios). **/ 

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

keep Fund date crsp_fundno crsp_fundno_orig hand_match series_length longest_series_length lipper_obj_cd

save "$temp/fund_returns_series_crosswalk_post.dta", replace
}

{ //There are three methods used to get betas:
//   * if we have 48 months of trailing data, whe just estimate it.
//   * if there is not enough, then if we have 60 months of data, we drop current year
//     and estimate beta with forward data
//   * if the fund is too new altogether, then we use average of lipper objective code.  


//We need to generate two list of crsp_fundnos for returns data
	//easy cases  (1) and (2)
keep if  series_length >= 48 | longest_series_length >= 60
keep  crsp_fundno 
duplicates drop

//This is the list we use to find fund betas
export delimited using "$temp/conventional_beta_fundos.txt", replace 

/*
use "$temp/fund_returns_series_crosswalk_post.dta", replace

//harder cases
//  there are only a handful of funds here and some of them are target date funds
drop if  series_length >= 48 | longest_series_length >= 60
keep  Fund date crsp_fundno lipper_obj_cd 
rename crsp_fundno crsp_fundno_root
joinby lipper_obj_cd date using "$temp\fund_summary.dta"

egen size_rank = rank(tna_latest), by(crsp_fundno_root)
keep if size_rank <10
save "$temp/conventional_beta_fundos.dta", replace


use "$temp/conventional_beta_fundos.dta", replace //This is the download list for returns


joinby crsp_portno using "$temp\portno_crosswalk.dta", unm(master) 



replace matchno = early_fundno if missing(matchno)
replace crsp_fundno = matchno
gen exact_match = 1 if crsp_fundno == crsp_fundno_orig 
gen portfolio_match = 1 if crsp_fundno != crsp_fundno_orig 

keep Fund date crsp_fundno crsp_fundno_orig   *match
joinby crsp_fundno date using "$temp\fund_summary.dta", unm(master)

gen series_length =  date -  mofd(first_offer_dt)  

gen hand_match = 1 if series_length < 36
replace portfolio_match = . if series_length < 36
replace exact_match = . if series_length < 36

keep  Fund date crsp_fundno_orig crsp_fundno fund_name first_offer *match

export excel using "$input\fund_returns_series_crosswalk_pre-edit.xls", firstrow(var) replace



drop first_offer_dt  // this is not reliable after the hand match
replace date = mofd(date)
format date %tm
joinby crsp_fundno date using "$temp\fund_summary.dta", unm(master)


use "$temp/plan_data.dta", replace
gen date = mofd(CalendarDay)
format date %tm
gen month = date
joinby Fund using "$input/crosswalk_clean"


joinby crsp_fundno using "$temp\return_match_crosswalk.dta", unm(master)

gen date_diff = caldt - CalendarDay
egen closest_date = min(abs(date_diff)), by(crsp_fundno CalendarDay)

keep if -50 < date_diff & date_diff  < 50
keep CalendarDay caldt crsp_fundno crsp_portno
save  "$temp\fund_port_crosswalk.dta", replace


use "$temp/plan_data.dta", replace
gen date = mofd(CalendarDay)
format date %tm
gen month = date
joinby Fund using "$input/crosswalk_clean"

joinby  crsp_fundno  using "$input\fund_summary.dta", unm(master)
*/

//////////////////////////////////////////////////
//
//  Compute Fund Betas  (Conventional Method) (1) 
//
/////////////////////////////////////////////////////

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
}

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

//we don't have enough data for 13 out of 1460 matches using conventional method  
//TODO: at least fix up the target date funds.  


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


/*
keep Fund crsp_fundno date ret var _rmse target_date is_target_date
save "$temp/risk_ret_tdf", replace

*/

preserve 

keep if date == 696
twoway 	(scatter ret var if is_target_date == 0,  mcolor(blue) msymbol(circle) mlabel(Fund) mlabangle(280) mlabsize(tiny)) ///
	(scatter ret var if is_target_date == 1, mcolor(green)  msymbol(circle) mlabel(target_date) mlabangle(280) mlabsize(tiny)), legend( label(1 "All Funds") label(2 "Target Date Funds"))
graph export "$output\plan m-4 new", as(png) replace
restore 
preserve 

keep if date == 648
twoway 	(scatter ret var if is_target_date == 0,  mcolor(blue) msymbol(circle) mlabel(Fund) mlabangle(280) mlabsize(tiny)) ///
	(scatter ret var if is_target_date == 1, mcolor(green)  msymbol(circle) mlabel(target_date) mlabangle(280) mlabsize(tiny)), legend( label(1 "All Funds") label(2 "Target Date Funds"))
graph export "$output\plan m-v old.png", as(png) replace
restore 

preserve
keep if is_target_date == 1
collapse ret var, by(target_date)
scatter ret var, mlabel(target_date)
restore 

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

{ // drop 2019 data
drop if date >= 708
}

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

export excel "$output/51 - 2016 Glidepath.xlsx", replace firstrow(varlabels)


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

{ // save data
save "$temp/cleaning_step_one.dta", replace
}


use "$temp/cleaning_step_one.dta", replace

sort Scr date

collapse (mean) crsp_fundno exp_ratio, by(Scr) // 12442 in ORP data 

use "C:\Users\ylsta\Dropbox\Retirement Menu Design\code\STATA -- ZS\Temp\cleaning_step_one.dta", clear

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
//** assert Fund != ""
//** assert crsp_fundno != .
tempfile filler
save "`filler'"
restore

append using "`filler'"

bys ScrubbedID date: egen temp = total(port_weight2)
////** assert round(temp, .00001) == 1
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
//** assert total_exp_temp <= $exp_ratio_cap | missing(total_exp_temp) if missing(total_adjust2)
replace total_adjust2 = 0 if missing(total_adjust2) | total_adjust2 < 0

// adjust down the port_weight of those that are over cutoff (proportionate to their port_weight among those that are over cutoff)
gen share_total_over = port_weight / port_weight_over2
replace port_weight = port_weight - (share_total_over * total_adjust2) if exp_ratio > .0075 & !missing(exp_ratio)

// make sure port_weight sums correctly
bys ScrubbedID date: egen temp2 = total(port_weight)
// //** assert round(temp2 + total_adjust2, .0001) == round(temp,.0001)

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
//** assert Fund != ""
//** assert crsp_fundno != .
tempfile filler2
save "`filler2'"
restore

append using "`filler2'"

// make sure port_weight sums correctly
cap drop temp2
bys ScrubbedID date: egen temp2 = total(port_weight)
//** //** assert round(temp2,.000001) == 1

// calculate portfolio expense ratio (and fix rounding errors)
cap drop total_exp_temp
bys ScrubbedID date: egen total_exp_temp = wtmean(exp_ratio), weight(port_weight)
gen temp3 = round(total_exp_temp,.0001)
//** assert round(total_exp_temp,.0001) <= round($exp_ratio_cap,.0001) | missing(total_exp_temp)
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
//** assert r(N) == 0

// tdf_equities / 2 = tot_eq * (1 - x) + x * tdf_equities
// tdf_equities / 2 - tot_eq = x * tdf_equities - x * tot_eq
gen total_adjust3 = (tdf_equities / 2 - tot_eq ) / (tdf_equities - tot_eq)
replace total_adjust3 = 0 if total_eq_under2 == 0
//** assert !missing(total_adjust3)

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
//** assert Fund != ""
//** assert crsp_fundno != .
tempfile filler3
save "`filler3'"
restore

append using "`filler3'"

// make sure port_weight sums correctly
cap drop temp2
bys ScrubbedID date: egen temp2 = total(port_weight)
//** //** assert round(temp2,.0001) == 1

// calculate portfolio equities
cap drop tot_eq
gen flag_eq = equities * port_weight
bys ScrubbedID date: egen tot_eq = wtmean(equities), weight(port_weight)
//** //** assert round(tot_eq,.00001) >= (round(tdf_equities / 2, .00001)) | missing(tot_eq)

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
//** assert r(N) == 0

// 2 * tdf_equities = tot_eq * (1 - x) + x * tdf_equities
// 2 * tdf_equities - tot_eq = x * tdf_equities - x * tot_eq
gen total_adjust4 = (2 * tdf_equities - tot_eq) / (tdf_equities - tot_eq)
replace total_adjust4 = 0 if total_eq_over2 == 0
//** assert !missing(total_adjust4)

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
//** assert Fund != ""
//** assert crsp_fundno != .
tempfile filler4
save "`filler4'"
restore

append using "`filler4'"

// make sure port_weight sums correctly
cap drop temp2
bys ScrubbedID date: egen temp2 = total(port_weight)
//** assert round(temp2,.0001) == 1

// calculate portfolio equities
cap drop tot_eq
cap drop flag_eq
gen flag_eq = equities * port_weight
bys ScrubbedID date: egen tot_eq = wtmean(equities), weight(port_weight)
//** assert round(tot_eq, .00001) <= round((tdf_equities * 2),.00001) | missing(tot_eq)

}

{ // save non-intl set of guardrails
save "$temp/guard_intrm_onlytdf_joint_nonintl_temp", replace
}

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
//** assert _m == 3 if inlist(date, 672,684,696)
drop _m

// calculate total international share of equities minimum
cap drop intl_share_of_equities
merge m:1 Fund using "$temp/sectorfunds"
//** assert _m != 1
drop if _m != 3
drop _m
replace intl_share_of_equities = .3 if date < 672 & (inlist(Fund, "OV6M-VANG INST TR INCOME", "OV6N-VANG INST TR 2010", "OV6O-VANG INST TR 2015","OV6P-VANG INST TR 2020","OV6Q-VANG INST TR 2025") ///
| inlist(Fund, "OV6R-VANG INST TR 2030","OV6S-VANG INST TR 2035", "OV6T-VANG INST TR 2040", "OV6U-VANG INST TR 2045","OV6V-VANG INST TR 2050","OV6W-VANG INST TR 2055","OV6X-VANG INST TR 2060") ///
| inlist(Fund, "OSHO-VANG TARGET RET INC", "OKKK-VANG TARGET RET 2010",  "OSHQ-VANG TARGET RET 2015", "OKKL-VANG TARGET RET 2020", "OSHR-VANG TARGET RET 2025") ///
| inlist(Fund, "OKKM-VANG TARGET RET 2030", "OSHS-VANG TARGET RET 2035", "OKKN-VANG TARGET RET 2040", "OSHT-VANG TARGET RET 2045", "OKKO-VANG TARGET RET 2050", "OEKG-VANG TARGET RET 2055"))
replace equities = . if equities == 0
replace intl_share_of_equities = . if equities == .
replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0 & !missing(equities)
//** assert equities ==. if intl_share_of_equities == .

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

// x is share of equities from portfolios without missing data that must be in tdf to get correct proportion of equities in intl
// $intl_eq_perc = (original_share_of_eq_intl * original_share_equities * (1 - x) + tdf_intl_share * tdf_equities * x)/ (tdf_equities * x + (1 - x) * original_share_equities)
// y = (a * b * (1 - x) + c * d * x)/ (d * x + (1 - x) * b)
// y * (d * x + (1 - x) * b) = (a * b * (1 - x) + c * d * x)
// y*d*x + yb - y*b*x =  a*b - a*b*x + c*d*x
// y*b - a*b = c*d*x + y*b*x - y*d*x - a*b*x 
// y*b - a*b = x * (c*d - y*d + y*b - a*b) 
// x = (y*b - a*b) / (c*d - y*d + y*b - a*b) 
// x = ($intl_eq_perc * original_share_equities - original_share_of_eq_intl * original_share_equities) / (tdf_intl_share * tdf_equities - $intl_eq_perc * tdf_equities + $intl_eq_perc * original_share_equities - original_share_of_eq_intl * original_share_equities) 
gen total_adjust5 = ($intl_eq_perc * tot_eq - total_intl_share_temp2 * tot_eq) / (tdf_intl_share * tdf_equities - $intl_eq_perc * tdf_equities + $intl_eq_perc * tot_eq - total_intl_share_temp2 * tot_eq) 
replace total_adjust5 = 0 if total_adjust5 < 0
replace total_adjust5 = 0 if total_intl_share_temp2 >= $intl_eq_perc & !missing(total_intl_share_temp2)
replace total_adjust5 = 0 if missing(equities) & missing(total_adjust5)

/* xxx old -- not relevant (so delete when I prep production code
// convert to port_weight
// total_adjust5_1 = (tdf_equities * y) / (tdf_equities * y + tot_eq * (1-y)) 
// total_adjust5_1 * (tdf_equities * y + tot_eq * (1-y)) = tdf_equities * y  
// total_adjust5_1 * tdf_equities * y + total_adjust5_1 *  tot_eq * (1-y)) = tdf_equities * y
// total_adjust5_1 *  tot_eq = tdf_equities * y - total_adjust5_1 * tdf_equities * y + y * total_adjust5_1 *  tot_eq 
// y = (total_adjust5_1 *  tot_eq) / (tdf_equities - total_adjust5_1 * tdf_equities + total_adjust5_1 *  tot_eq)
gen total_adjust5 = (total_adjust5_1 *  tot_eq) / (tdf_equities - total_adjust5_1 * tdf_equities + total_adjust5_1 *  tot_eq)
*/



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
//** assert Fund != ""
//** assert crsp_fundno != .
tempfile filler5
save "`filler5'"
restore

append using "`filler5'"

// make sure port_weight sums correctly
cap drop temp2
bys ScrubbedID date: egen temp2 = total(port_weight)
//** assert round(temp2,.0001) == 1

// update weighting
replace intl_weight = port_weight * equities

// calculate portfolio equities
cap drop total_intl_share_temp2
bys ScrubbedID date: egen total_intl_share_temp2 = wtmean(intl_share_of_equities), weight(intl_weight)
//** assert round(total_intl_share_temp2, .0001) >= round($intl_eq_perc, .0001)


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
//** assert _m == 3 if inlist(date, 672,684,696)
drop _m

// calculate portfolio equities
cap drop tot_eq
cap drop flag_eq
gen flag_eq = equities * port_weight
bys ScrubbedID date: egen tot_eq = wtmean(equities), weight(port_weight)
//** assert round(tot_eq, .00001) <= round((tdf_equities * 2),.00001) | missing(tot_eq)
//** assert round(tot_eq,.00001) >= (round(tdf_equities / 2, .00001)) | missing(tot_eq)


// calculate portfolio expense ratio (and fix rounding errors)
cap drop total_exp_temp temp3
bys ScrubbedID date: egen total_exp_temp = wtmean(exp_ratio), weight(port_weight)
gen temp3 = round(total_exp_temp,.0001)
//** assert round(total_exp_temp,.0001) <= round($exp_ratio_cap,.0001) | missing(total_exp_temp)

// check sector funds
//** assert !missing(sector)
replace sector = port_weight if sector != 0
//** assert round(sector, .00001) <= round($ind_sec_lev, .00001)

}

{ // collapse in case repeatedly placed in same TDF and make sure we have all necessary variables
collapse (sum) port_weight, by(ScrubbedID Fund crsp_fundno crsp_fundno_orig date)

// merge in additional fund data
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m 
merge m:1 Fund using "$temp/sectorfunds"
//** assert _m != 1
drop if _m != 3
drop _m

replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0
gen intl_equity_share = intl_share_of_equities*equities
// define international equities as equity funds that are > 50% international
gen intl_equity_fund = (equity == 1 & intl_share_of_equities > .5)

// merge in guardrails flags
merge m:1 ScrubbedID using "$temp/guardrails flags"
//** assert _m == 3 if date == 672
drop _m
}

{ // save file
save "$temp/guard_intrm_onlytdf_joint_all", replace
}

{ // re-save non-intl set of guardrails with correct variables
use "$temp/guard_intrm_onlytdf_joint_nonintl_temp", clear

collapse (sum) port_weight, by(ScrubbedID Fund crsp_fundno crsp_fundno_orig date)

// merge in additional fund data
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m 
merge m:1 Fund using "$temp/sectorfunds"
//** assert _m != 1
drop if _m != 3
drop _m

replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0
gen intl_equity_share = intl_share_of_equities*equities
// define international equities as equity funds that are > 50% international
gen intl_equity_fund = (equity == 1 & intl_share_of_equities > .5)

// merge in guardrails flags
merge m:1 ScrubbedID using "$temp/guardrails flags"
//** //** assert _m == 3 if date == 672
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

// solve for necessary port_weight in tdf to reduce expense ratio to cutoff -- only reducing holdings in funds that exceed the cutoff
//  $exp_ratio_cap = port_weight_under2/non_missing_weight * exp_under2 + (port_weight_over2/non_missing_weight - x) * exp_over2 + x * tdf_exp_ratio
//  $exp_ratio_cap - port_weight_under2/non_missing_weight * exp_under2 - port_weight_over2/non_missing_weight * exp_over2 = x * tdf_exp_ratio - x * exp_over2 
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

// x is share of equities from portfolios without missing data that must be in tdf to get correct proportion of equities in intl
// $intl_eq_perc = (original_share_of_eq_intl * original_share_equities * (1 - x) + tdf_intl_share * tdf_equities * x)/ (tdf_equities * x + (1 - x) * original_share_equities)
// y = (a * b * (1 - x) + c * d * x)/ (d * x + (1 - x) * b)
// y * (d * x + (1 - x) * b) = (a * b * (1 - x) + c * d * x)
// y*d*x + yb - y*b*x =  a*b - a*b*x + c*d*x
// y*b - a*b = c*d*x + y*b*x - y*d*x - a*b*x 
// y*b - a*b = x * (c*d - y*d + y*b - a*b) 
// x = (y*b - a*b) / (c*d - y*d + y*b - a*b) 
// x = ($intl_eq_perc * original_share_equities - original_share_of_eq_intl * original_share_equities) / (tdf_intl_share * tdf_equities - $intl_eq_perc * tdf_equities + $intl_eq_perc * original_share_equities - original_share_of_eq_intl * original_share_equities) 
gen total_adjust5 = ($intl_eq_perc * tot_eq - total_intl_share_temp2 * tot_eq) / (tdf_intl_share * tdf_equities - $intl_eq_perc * tdf_equities + $intl_eq_perc * tot_eq - total_intl_share_temp2 * tot_eq) 
replace total_adjust5 = 0 if total_adjust5 < 0
replace total_adjust5 = 0 if total_intl_share_temp2 >= $intl_eq_perc & !missing(total_intl_share_temp2)
replace total_adjust5 = 0 if missing(equities) & missing(total_adjust5)

/* xxx old -- not relevant (so delete when I prep production code
// convert to port_weight
// total_adjust5_1 = (tdf_equities * y) / (tdf_equities * y + tot_eq * (1-y)) 
// total_adjust5_1 * (tdf_equities * y + tot_eq * (1-y)) = tdf_equities * y  
// total_adjust5_1 * tdf_equities * y + total_adjust5_1 *  tot_eq * (1-y)) = tdf_equities * y
// total_adjust5_1 *  tot_eq = tdf_equities * y - total_adjust5_1 * tdf_equities * y + y * total_adjust5_1 *  tot_eq 
// y = (total_adjust5_1 *  tot_eq) / (tdf_equities - total_adjust5_1 * tdf_equities + total_adjust5_1 *  tot_eq)
gen total_adjust5 = (total_adjust5_1 *  tot_eq) / (tdf_equities - total_adjust5_1 * tdf_equities + total_adjust5_1 *  tot_eq)
*/

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

export excel "$output/66 - Share of Portfolio Affected By Guardrails.xlsx", replace firstrow(varlabels)


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


}


use "C:\Users\ylsta\Dropbox\Retirement Menu Design\code\STATA -- ZS\Temp\investor_mean_var_cleaning_step_one.dta", clear

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

{ // prepare portfolio factors
do "$code/portfolio_factor.do"
}

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
// NOTE: using arithmetic returns for risk-free because we do not want to distort the sharpe ratio

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

{ // save intermediate dataset
save "$temp/collapse_nosmart_1.dta", replace
//use "$temp/collapse_nosmart_1.dta", replace

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





/*
Guardrails Baseline Graphs
ZRS 
10/01/2019

Goal:
-- 

Notes:
--

Updates:
-- 
	
*/


use "$temp/collapse2_combined", clear

sum if date == 672 | date == 684

gen ian_flag = (ScrubbedID == 43315)

gen graph_helper = .

{ // original graphs 
// date 672 is Jan 2016 (last available data before reforms went into effect. Dates are in months.)
twoway (scatter return_used var_used if date == 672, msize(vtiny) msymbol(o) mcolor("$color_p2")) ///
(scatter return_used var_used if date == 684, mcolor("$color_p3") msize(vtiny) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(medium)   msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p3") msize(medium)   msymbol(o)), ///
legend(label(3 "Pre-Redesign") label(4 "Post-Redesign") order(3 4)) ylabel(,nogrid) ytitle(Return) xtitle(Variance)
graph export "$output/1 - Return Variance Comparison.png", replace

// basic returns-variance for pre-post comparison
// Eni edited
twoway (scatter return_used var_used if date == 672 & var_used < .03, msize(tiny) msymbol(o) mcolor(gs11)) ///
(scatter return_used var_used if date == 684 & var_used < .03, mcolor(gs5) msize(tiny) msymbol(d)) ///
(scatter graph_helper graph_helper, mcolor(gs11) msize(medium) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor(5) msize(medium) msymbol(d)), ///
legend(label(3 "Pre-Redesign") label(4 "Post-Redesign") order(3 4)) note("Limited to observations with variance < 0.03", size(tiny)) ylabel(,nogrid) ytitle(Return) xtitle(Variance)
graph export "$output/2 - Return Variance Pre-Post Comparison Rescale.png", replace

// basic returns-variance for post only
twoway (scatter return_used var_used if date == 684 & var_used < .03, mcolor("$color_p2") msize(tiny) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(medium) msymbol(o)), ///
legend(label(2 "Post-Redesign") order(2)) note("Limited to observations with variance < 0.03", size(tiny)) ylabel(,nogrid) ytitle(Return) xtitle(Variance)
graph export "$output/2.0 - Return Variance Only Post Rescale.png", replace

// basic returns-variance for pre vs non-intl guardrails comparison
// Eni edited
twoway (scatter return_used var_used if date == 672 & var_used < .04, msize(tiny) msymbol(o) mcolor(gs11)) ///
(scatter return_used var_used if date == 991 & var_used < .04, mcolor(gs5) msize(tiny) msymbol(d)) ///
(scatter graph_helper graph_helper, mcolor(gs11) msize(medium) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor(gs5) msize(medium) msymbol(d)), ///
legend(label(3 "Pre-Redesign") label(4 "Joint Non-International Guardrails to TDF") order(3 4)) note("Limited to observations with variance < .04", size(tiny)) ylabel(,nogrid) ytitle(Return) xtitle(Variance)
graph export "$output/2.1 - Return Variance Pre-Guardrails Comparison Rescale.png", replace

// basic returns-variance for post-guardrails comparison
twoway (scatter return_used var_used if date == 990 & var_used < .03, mcolor("$color_p4"*1.2%50) msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & var_used < .03, msize(tiny) msymbol(o) mcolor("$color_p3%40")) ///
(scatter graph_helper graph_helper, mcolor("$color_p3") msize(medium) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p4"*1.2) msize(medium) msymbol(o)), ///
legend(label(3 "Post-Redesign") label(4 "Joint Guardrails to TDF, All") order(3 4)) note("Limited to observations with variance < 0.03", size(tiny)) ylabel(,nogrid) ytitle(Return) xtitle(Variance)
graph export "$output/2.2 - Return Variance Post-Guardrails Comparison Rescale.png", replace

// basic returns-variance for pre-post-guardrails comparison
twoway (scatter return_used var_used if date == 672 & var_used < .04, msize(tiny) msymbol(o) mcolor("$color_p2")) ///
(scatter return_used var_used if date == 684 & var_used < .04, mcolor("$color_p3%30") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 990 & var_used < .04, mcolor("$color_p4"%15) msize(tiny) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(medium) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p3") msize(medium) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p4") msize(medium) msymbol(o)), ///
legend(label(4 "Pre-Redesign") label(5 "Post-Redesign") label(6 "Joint Guardrails to TDF, All") order(4 5 6)) note("Limited to observations with variance < 0.03", size(tiny)) ylabel(,nogrid) ytitle(Return) xtitle(Variance)
graph export "$output/2.3 - Return Variance Pre-Post-Guardrails Comparison Rescale With Guardrails.png", replace

twoway (scatter return_used var_used if date == 672 & steady_pre != 1 & var_used < .03, color("$color_p2") msize(vtiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & steady_pre != 1 & var_used < .03, mcolor("$color_p3") msize(vtiny) msymbol(o)) ///
(scatter return_used var_used if date == 672 & steady_pre == 1 & var_used < .03, mcolor("$color_p2") msize(small) msymbol(o)) ///
(scatter return_used var_used if date == 684 & steady_pre == 1 & var_used < .03, mcolor("$color_p3") msize(small) msymbol(o)), ///
legend(label(1 "Pre-Redesign Forced to Switch") label(2 "Post-Redesign Forced to Switch") ///
label(3 "Pre-Redesign Not Forced to Switch") label(4 "Post-Redesign Not Forced to Switch")) ylabel(,nogrid) ytitle(Return) xtitle(Variance)


use "$temp/collapse2_combined", clear
gen graph_helper = .
// Eni edited
// basic returns-variance for pre only
twoway (scatter return_used var_used if date == 672 & var_used < .04 & smart == 0, mcolor("$color_p2") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 672 & var_used < .04 & smart == 1, mcolor("$color_p3") msize(small) msymbol(X)) ///
(scatter graph_helper graph_helper, mcolor("$color_p3") msize(medium) msymbol(X)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(medium) msymbol(o)), /// 
legend(label(3 "TDFs") label(4 "Other Portfolios") order(3 4)) ///
note("Limited to observations with variance < 0.04", size(tiny)) ylabel(,nogrid) ytitle(Return) xtitle(Variance)
graph export "$output/2.4 - Return Variance Only Pre Rescale.png", replace
graph save "$temp/2.4 - Return Variance Only Pre Rescale.gph", replace

// basic returns-variance for pre only
twoway (scatter ante_ret ante_var if date == 672 & ante_var < .04 & smart == 0, mcolor("$color_p2") msize(tiny) msymbol(o)) ///
(scatter ante_ret ante_var if date == 672 & ante_var < .04 & smart == 1, mcolor("$color_p3") msize(small) msymbol(X)) ///
(scatter graph_helper graph_helper, mcolor("$color_p3") msize(medium) msymbol(X)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(medium) msymbol(o)), ///
legend(label(3 "TDFs") label(4 "Other Portfolios") order(3 4)) ///
note("Limited to observations with variance < 0.04", size(tiny)) ylabel(,nogrid) ytitle(Ex-Ante Return) xtitle(Ex-Ante Variance) 
graph export "$output/2.5 - Return Variance Ex Ante Rescale.png", replace
graph save "$temp/2.5 - Return Variance Ex Ante Rescale.gph", replace

// combined ex ante & ex post returns
graph combine "$temp/2.5 - Return Variance Ex Ante Rescale.gph" "$temp/2.4 - Return Variance Only Pre Rescale.gph", ///
ycomm xcomm
graph export "$output/2.6 - Return Variance Ex-Ante_Ex-Post Rescale.png", replace

}

{ // first linearity 
twoway (scatter return_used var_used if date == 684 & share_comb1 >= .99, mcolor("$color_p2") msize(small) msymbol(smx)) ///
(scatter return_used var_used if date == 684 & share_comb1 < .99, mcolor("$color_p3") msize(tiny) msymbol(smx)), ///
legend(size(vsmall) label(1 "99% in Fidelity Contrafund" "and Vanguard Total Index Combined") label(2 "At least 1% in other funds")) ///
ylabel(,nogrid) ytitle(Return) xtitle(Variance) ///
title("Highlighting Linearities in Post-Reform Portfolios", size(medsmall) pos(12))

graph export "$output/3 - Vanguard Total and Fidelity Contrafund Jan2017 v1.png", replace

twoway (scatter return_used var_used if date == 684 & share_comb1 >= .99 & share_2080fidck >= .50, mcolor("$color_p2") msize(small) msymbol(smx)) ///
(scatter return_used var_used if date == 684 & share_comb1 >= .99 & share_ovf7 >= .50, mcolor("$color_p4") msize(small) msymbol(smx)) /// 
(scatter return_used var_used if date == 684 & share_comb1 < .99, mcolor("$color_p3") msize(tiny) msymbol(smx)), ///
legend(size(vsmall) label(1 "99% in Fidelity Contrafund" "and Vanguard Total Index Combined" "with at least 50% in Fidelity Contrafund") ///
label(2 "99% in Fidelity Contrafund" "and Vanguard Total Index Combined" "with at least 50% in Vanguard Total Index") label(3 "At least 1% in other funds")) ///
ylabel(,nogrid) ytitle(Return) xtitle(Variance)
graph export "$output/4 - Vanguard Total and Fidelity Contrafund v2.png", replace 
}

{ // second linearity
twoway (scatter return_used var_used if date == 684 & share_comb2 < .99, mcolor("$color_p3") msize(tiny) msymbol(smx)) ///
(scatter return_used var_used if date == 684 & share_comb2 >= .99, mcolor("$color_p2") msize(small) msymbol(smx)), ///
legend(size(vsmall) label(1 "At least 1% in other funds") label(2 "99%+ in Vanguard Small Cap Index" "and Vanguard Total Index")) ///
ylabel(,nogrid) ytitle(Return) xtitle(Variance) ///
title("Highlighting Linearities in Post-Reform Portfolios", size(medsmall) pos(12))
graph export "$output/5 - Vanguard Total and Small Cap.png", replace
}

{ // third linearity
twoway (scatter return_used var_used if date == 684 & share_comb3 < .99, mcolor("$color_p3") msize(tiny) msymbol(smx)) ///
(scatter return_used var_used if date == 684 & share_comb3 >= .99, mcolor("$color_p2") msize(small) msymbol(smx)), ///
legend(size(vsmall) label(1 "At least 1% in other funds") label(2 "99%+ in Vanguard Prime Cap Index" "and Vanguard Total Index")) ///
ylabel(,nogrid) ytitle(Return) xtitle(Variance) ///
title("Highlighting Linearities in Post-Reform Portfolios", size(medsmall) pos(12)) 
graph export "$output/6 - Vanguard Total and Prime Cap.png", replace
}

{ // fourth linearity
twoway (scatter return_used var_used if date == 684 & share_comb4 < .99, mcolor("$color_p3") msize(tiny) msymbol(smx)) ///
(scatter return_used var_used if date == 684 & share_comb4 >= .99, mcolor("$color_p2") msize(small) msymbol(smx)), ///
legend(size(vsmall) label(1 "At least 1% in other funds") label(2 "99%+ in Vanguard Mid Cap Index" "and Vanguard Total Index")) ///
ylabel(,nogrid) ytitle(Return) xtitle(Variance) ///
title("Highlighting Linearities in Post-Reform Portfolios", size(medsmall) pos(12))

graph export "$output/7 - Vanguard Total and Mid Cap.png", replace
}

{ // each linearity in one graph
twoway (scatter return_used var_used if date == 684 & share_comb1 < .99 & share_comb2 < .99 & share_comb3 < .99 & share_comb4 < .99, mcolor("$color_p3") msize(tiny) msymbol(smx)) ///
(scatter return_used var_used if date == 684 & share_comb1 >= .99, mcolor("$color_p2") msize(small) msymbol(smx)) ///
(scatter return_used var_used if date == 684 & share_comb2 >= .99, mcolor("$color_p4") msize(small) msymbol(smx)) ///
(scatter return_used var_used if date == 684 & share_comb3 >= .99, mcolor(lavender) msize(small) msymbol(smx)) ///
(scatter return_used var_used if date == 684 & share_comb4 >= .99, mcolor(gs6) msize(small) msymbol(smx)), ///
legend(size(vsmall) label(1 "Other Portfolios") ///
label(2 "99%+ in Fidelity Contrafund" "and Vanguard Total Index") ///
label(3 "99%+ in Vanguard Small Cap Index" "and Vanguard Total Index") ///
label(4 "99%+ in Vanguard Prime Cap Index" "and Vanguard Total Index") ///
label(5 "99%+ in Vanguard Mid Cap Index" "and Vanguard Total Index")) ///
ylabel(,nogrid) ytitle(Return) xtitle(Variance) ///
title("Highlighting Linearities in Post-Reform Portfolios", size(medsmall) pos(12))
graph export "$output/8 - All Linearities.png", replace
}

{ // vanguard index origin (OVF7-VANG TOT STK MKT IP)
twoway (scatter return_used var_used if date == 684 & share_ovf7 == 0, mcolor("$color_p2") msize(tiny) msymbol(smx)) ///
(scatter return_used var_used if date == 684 & share_ovf7 > 0 & share_ovf7 < .1, mcolor("$color_p3*.1") msize(tiny) msymbol(smx)) /// 
(scatter return_used var_used if date == 684 & share_ovf7 >= .1 & share_ovf7 < .2, mcolor("$color_p3*.2") msize(tiny) msymbol(smx)) /// 
(scatter return_used var_used if date == 684 & share_ovf7 >= .2 & share_ovf7 < .3, mcolor("$color_p3*.3") msize(tiny) msymbol(smx)) /// 
(scatter return_used var_used if date == 684 & share_ovf7 >= .3 & share_ovf7 < .4, mcolor("$color_p3*.4") msize(tiny) msymbol(smx)) /// 
(scatter return_used var_used if date == 684 & share_ovf7 >= .4 & share_ovf7 < .5, mcolor("$color_p3*.5") msize(tiny) msymbol(smx)) /// 
(scatter return_used var_used if date == 684 & share_ovf7 >= .5 & share_ovf7 < .6, mcolor("$color_p3*.6") msize(tiny) msymbol(smx)) /// 
(scatter return_used var_used if date == 684 & share_ovf7 >= .6 & share_ovf7 < .7, mcolor("$color_p3") msize(tiny) msymbol(smx)) /// 
(scatter return_used var_used if date == 684 & share_ovf7 >= .7 & share_ovf7 < .8, mcolor("$color_p3*1.1") msize(tiny) msymbol(smx)) /// 
(scatter return_used var_used if date == 684 & share_ovf7 >= .8 & share_ovf7 < .9, mcolor("$color_p3*1.2") msize(tiny) msymbol(smx)) /// 
(scatter return_used var_used if date == 684 & share_ovf7 >= .9 & share_ovf7 < 1, mcolor("$color_p3*1.3") msize(tiny) msymbol(smx)) /// 
(scatter return_used var_used if date == 684 & share_ovf7 == 1, mcolor(black) msize(large) msymbol(smx)), ///
legend(size(vsmall) order(1 11 12) ///
label(1 "No Holidings in Vanguard" "Total Stock Market Index") ///
label(11 "Portfolios Containing Vanguard" "Total Stock Market Index") /// 
label(12 "100% Vanguard" "Total Stock Market Index")) ///
ylabel(,nogrid) ytitle(Return) xtitle(Variance) ///
note("Portfolios with holdings in Vanguard Total Stock Market Index are shaded by the share of the Vanguard Total Stock Market Index Fund within the portfolio.", size(tiny)) ///
title("Highlighting Vanguard Total Stock Market Index Prevalence" "For Post-Reform Portfolios", size(medsmall) pos(12))
graph export "$output/9 - All Vanguard Total Holdings.png", replace 
}

{ // individuals that increased share of TDFs post-reform
 
twoway (scatter return_used var_used if date == 672 & delta_tdfshare > 0 & var_used < .03, mcolor("$color_p2%30") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & delta_tdfshare > 0 & delta_tdfshare <= .1 & var_used < .03, mcolor("$color_p3*.05") msize(tiny) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & delta_tdfshare > .1 & delta_tdfshare <= .2 & var_used < .03, mcolor("$color_p3*.1") msize(tiny) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & delta_tdfshare > .2 & delta_tdfshare <= .3 & var_used < .03, mcolor("$color_p3*.2") msize(tiny) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & delta_tdfshare > .3 & delta_tdfshare <= .4 & var_used < .03, mcolor("$color_p3*.3") msize(tiny) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & delta_tdfshare > .4 & delta_tdfshare <= .5 & var_used < .03, mcolor("$color_p3*.4") msize(tiny) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & delta_tdfshare > .5 & delta_tdfshare <= .6 & var_used < .03, mcolor("$color_p3*.5") msize(tiny) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & delta_tdfshare > .6 & delta_tdfshare <= .7 & var_used < .03, mcolor("$color_p3*.6") msize(tiny) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & delta_tdfshare > .7 & delta_tdfshare <= .8 & var_used < .03, mcolor("$color_p3*.8") msize(tiny) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & delta_tdfshare > .8 & delta_tdfshare <= .9 & var_used < .03, mcolor("$color_p3*1") msize(tiny) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & delta_tdfshare > .9 & delta_tdfshare <= 1 & var_used < .03, mcolor("$color_p3*1.1") msize(tiny) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & delta_tdfshare == 1 & var_used < .03, mcolor("$color_p3*1.2") msize(tiny) msymbol(o)), /// 
legend(size(vsmall) order(12 1) ///
label(1 "Pre-Reform Counterfactual") ///
label(12 "Post-Reform Realized")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) ///
title("Comparison of Pre-Reform Counterfactual and Post-Reform Realized Portfolio" "Performance For Individuals That Increased TDF Share", pos(12) size(medsmall)) ///
note("Only the subset of individuals that increased portfolio TDF share between 2016 and 2017 are included." ///
"Post-Reform Portfolios are shaded based on how much of an increase in TDF share they experienced," "with darker indicating a greater increase.", size(tiny))
graph export "$output/10 - Changed TDF Share.png", replace 

}

{ // TDFs


twoway (scatter return_used var_used if date == 684 & fid_tdf_share < .5 & van_tdf_share < .5, mcolor("$color_p4%5") msize(tiny) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & van_tdf_share >= .50, mcolor("$color_p3") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & fid_tdf_share >= .50, mcolor("$color_p2") msize(tiny) msymbol(o)) /// 
, legend(size(vsmall) ///
label(1 "Portolfio Includes 50%+ Vanguard TDF") ///
label(2 "Portolfio Includes 50%+ Fidelity TDF") /// 
label(3 "Other Portfolios")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance)  ///
title("Highlighting Target Date Fund Performance, Post-Reform Realized" ,size(medsmall) pos(12))
graph export "$output/11 - Vanguard and Fidelity TDFs.png", replace 

twoway (scatter return_used var_used if date == 684 & total_tdf_share == 0, mcolor("$color_p4%10") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & total_tdf_share < .2 & total_tdf_share > 0, mcolor("$color_p3*.1") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & total_tdf_share < .4 & total_tdf_share >= .2, mcolor("$color_p3*.2") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & total_tdf_share < .6 & total_tdf_share >= .4, mcolor("$color_p3*.5") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & total_tdf_share < .8 & total_tdf_share >= .6, mcolor("$color_p3*.8") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & total_tdf_share < 1 & total_tdf_share >= .8, mcolor("$color_p3") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & total_tdf_share == 1, mcolor("$color_p3*1.2") msize(tiny) msymbol(o)), ///
legend(size(vsmall) ///
label(1 "Portfolios without TDFs") ///
label(6 "Portfolios Containing TDFs") ///
order(6 1)) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance)  ///
title("Highlighting Target Date Fund Performance, Post-Reform Realized" ,size(medsmall) pos(12)) ///
note("Portfolios with holdings in Target Date Funds are shaded by the share of the Target Date Funds within the portfolio.", size(tiny))
graph export "$output/11.1 - All TDFs Gradient.png", replace 

}

{ // Bonds

twoway (scatter return_used var_used if date == 684 & cash_bonds == 0, mcolor("$color_p4%10") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & cash_bonds < .1 & cash_bonds > 0, mcolor("$color_p3*.1") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & cash_bonds < .2 & cash_bonds >= .1, mcolor("$color_p3*.2") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & cash_bonds < .3 & cash_bonds >= .2, mcolor("$color_p3*.3") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & cash_bonds < .4 & cash_bonds >= .3, mcolor("$color_p3*.4") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & cash_bonds < .5 & cash_bonds >= .4, mcolor("$color_p3*.5") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & cash_bonds < .6 & cash_bonds >= .5, mcolor("$color_p3*.6") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & cash_bonds < .7 & cash_bonds >= .6, mcolor("$color_p3*.7") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & cash_bonds < .8 & cash_bonds >= .7, mcolor("$color_p3*.8") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & cash_bonds < .9 & cash_bonds >= .8, mcolor("$color_p3*.9") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & cash_bonds < 1 & cash_bonds >= .9, mcolor("$color_p3") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 684 & cash_bonds == 1, mcolor("$color_p3*1.2") msize(tiny) msymbol(o)), ///
legend(size(vsmall) ///
label(1 "Portfolios Without Bonds") ///
label(6 "Portfolios Containing Bonds") ///
order(6 1)) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance)  ///
title("Highlighting Bond Performance in Post-Reform Portfolios" ,size(medsmall) pos(12)) ///
note("Portfolios with holdings in bonds are shaded by the share of the bonds within the portfolio.", size(tiny))
graph export "$output/16 - Bonds Gradient.png", replace 

}

{ // Sharpe ratios
twoway (kdensity sharpe if date == 672, color("$color_p2")) (kdensity sharpe if date == 684, color("$color_p3")), ///
legend(label(1 Pre-Reform Counterfactual) label(2 Post-Reform Realized)) xtitle(Sharpe Ratio) ytitle(Density) ylabel(,nogrid)

twoway (kdensity sharpe if date == 672, color("$color_p2")) (kdensity sharpe if date == 684, color("$color_p3")) if sharpe < 10 & sharpe > 0, ///
legend(label(1 Pre-Reform Counterfactual) label(2 Post-Reform Realized)) xtitle(Sharpe Ratio) ytitle(Density) ylabel(,nogrid)
graph export "$output/17 - Sharpe Ratios.png", replace 

twoway (kdensity sharpe if date == 672, color("$color_p2")) ///
(kdensity sharpe if date == 990, color("$color_p4%50")) ///
(kdensity sharpe if date == 684, color("$color_p3")) if sharpe < 10 & sharpe > 0, ///
legend(label(1 Pre-Reform Counterfactual) label(2 All Joint Guardrails to TDF,  Counterfactual) label(3 Post-Reform Realized) order(1 3 2)) xtitle(Sharpe Ratio) ytitle(Density) ylabel(,nogrid)
graph export "$output/17.1 - Sharpe Ratios With Guardrail Counterfactual.png", replace 

// variance of the sharpe ratio is higher in 2016
// However, if we restrict to observations with sharpe >= 0, then variance of the sharpe ratio is higher in 2017
// if we remove all outliers ( <0 | >10 ) then 2017 is lower variance in sharpe ratio
la drop date
la def date 672 "Pre-Reform" ///
684 "Post-Reform"
la val date date
estpost tabstat sharpe if sharpe >= 0 & sharpe <= 10 & inlist(date,672,684), by(date) statistics(count mean sd min max)
esttab . using "$output/18 - Sharpe Ratio Table.rtf", cells("count(fmt(0)) mean(fmt(3)) sd(fmt(3)) min(fmt(3)) max(fmt(3))") not nostar unstack nomtitle nonumber nonote noobs label replace


}

{ // expense ratios
twoway (hist exp_ratio if date == 672 [fweight = total_assets], start(0) percent color("$color_p2%30") w(.1)) /// 
(hist exp_ratio if date == 684 [fweight = total_assets], start(0) percent color("$color_p3%30") w(.1)), /// 
legend(label(1 Pre-Reform Counterfactual) label(2 Post-Reform Realized) size(vsmall)) ///
ylabel(#3, angle(0) format(%3.0f) labsize(vsmall) nogrid) ///
xlabel(, labsize(vsmall)) ///
ytitle("Share Of Assets (%)", size(small)) ///
xtitle("Expense Ratio (%)", size(small)) ///
title(Share of Assets By Expense Ratio, pos(12) size(medium))
graph export "$output/33.1 - Expense Ratio By Assets Pre-Post.png", replace

twoway (hist exp_ratio if date == 990 [fweight = total_assets], start(0) percent color("$color_p3%40") w(.1)) /// 
(hist exp_ratio if date == 672 [fweight = total_assets], start(0) percent color("$color_p2%40") w(.1)), /// 
legend(label(1 Guardrails Counterfactual) label(2 All Joint Guardrails to TDF Counterfactual) size(vsmall)) ///
ylabel(#3, angle(0) format(%3.0f) labsize(vsmall) nogrid) ///
xlabel(, labsize(vsmall)) ///
ytitle("Share Of Assets (%)", size(small)) ///
xtitle("Expense Ratio (%)", size(small)) ///
title(Share of Assets By Expense Ratio, pos(12) size(medium))
graph export "$output/33.2 - Expense Ratio By Assets Pre-Guardrails.png", replace

preserve 

use "$temp/joined_fund_data", clear
keep if inlist(date,672,684)
bys Fund date: keep if _n == 1
keep if exp_ratio >= 0
replace exp_ratio = exp_ratio*100

twoway (hist exp_ratio if date == 672, percent color("$color_p2%30") w(.1) start(0)) /// 
(hist exp_ratio if date == 684, percent color("$color_p3%30") w(.1) start(0)), /// 
legend(label(1 Pre-Reform Counterfactual) label(2 Post-Reform Realized) size(vsmall)) ///
ylabel(, angle(0) format(%3.0f) labsize(vsmall) nogrid) ///
xlabel(, labsize(vsmall)) ///
ytitle("Share Of Funds(%)", size(small)) ///
xtitle("Expense Ratio (%)", size(small)) ///
title(Share of Funds By Expense Ratio, pos(12) size(medium))

graph export "$output/33.3 - Expense Ratio By Funds.png", replace

restore

twoway (hist exp_ratio if date == 684 & present_2018 == 1 [fweight = total_assets], percent color("$color_p2%30") w(.1)) /// 
(hist exp_ratio if date == 696 [fweight = total_assets], percent color("$color_p3%30") w(.1)), /// 
legend(label(1 "Post-Reform (2017)") label(2 "Post-Reform (2018)") size(vsmall)) ///
ylabel(#3, angle(0) format(%3.0f) labsize(vsmall) nogrid) ///
xlabel(, labsize(vsmall)) ///
ytitle("Share Of Assets (%)", size(small)) ///
xtitle("Expense Ratio (%)", size(small)) ///
title(Share of Assets By Expense Ratio, pos(12) size(medium))
graph export "$output/33.4 - Expense Ratio By Assets 2017-2018.png", replace



}

{ // highlight guardrail impact
use "$temp/collapse2_combined", clear

gen graph_helper = .

twoway (scatter return_used var_used if date == 672 & any_guardrail == 1, mcolor("$color_p2") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 990 & any_guardrail == 1, mcolor("$color_p4") msize(vsmall) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(medium) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p4") msize(medium) msymbol(o)), ///
legend(size(vsmall) ///
label(3 "Pre-Reform") ///
label(4 "All Joint Guardrails to TDF") order(3 4)) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) ///
title("Highlighting Guardrail Impact", size(medsmall) pos(12))
graph save "$temp/guardrails_1", replace

twoway (scatter return_used var_used if date == 684 & any_guardrail == 1, mcolor("$color_p3") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 990 & any_guardrail == 1, mcolor("$color_p4") msize(vsmall) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p3") msize(medium) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p4") msize(medium) msymbol(o)), ///
legend(size(vsmall) ///
label(3 "Post-Reform") ///
label(4 "All Joint Guardrails to TDF") order(3 4)) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) 
graph save "$temp/guardrails_2", replace

graph combine "$temp/guardrails_1" "$temp/guardrails_2", xcomm ycomm

graph export "$output/39 - Guardrail Impact.png", replace 

}

{ // dominated fund share
twoway (scatter return_used var_used if date == 672 & dominated_simple == 0 & var_used < .03, mcolor("$color_p2") msize(vsmall) msymbol(o)) ///
(scatter return_used var_used if date == 672 & dominated_simple > 0 & dominated_simple < .1 & var_used < .03, mcolor("$color_p3*.1") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 672 & dominated_simple >= .1 & dominated_simple < .2 & var_used < .03, mcolor("$color_p3*.2") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 672 & dominated_simple >= .2 & dominated_simple < .3 & var_used < .03, mcolor("$color_p3*.3") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 672 & dominated_simple >= .3 & dominated_simple < .4 & var_used < .03, mcolor("$color_p3*.4") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 672 & dominated_simple >= .4 & dominated_simple < .5 & var_used < .03, mcolor("$color_p3*.5") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 672 & dominated_simple >= .5 & dominated_simple < .6 & var_used < .03, mcolor("$color_p3*.6") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 672 & dominated_simple >= .6 & dominated_simple < .7 & var_used < .03, mcolor("$color_p3*.7") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 672 & dominated_simple >= .7 & dominated_simple < .8 & var_used < .03, mcolor("$color_p3*.8") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 672 & dominated_simple >= .8 & dominated_simple < .9 & var_used < .03, mcolor("$color_p3*.9") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 672 & dominated_simple >= .9 & dominated_simple < 1 & var_used < .03, mcolor("$color_p3") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 672 & dominated_simple == 1 & var_used < .03, mcolor("$color_p3*1.2") msize(medlarge) msymbol(X)), ///
legend(size(vsmall) order(1 11 12) ///
label(1 "No Holidings in Dominated Funds") ///
label(11 "Portfolios Containing Dominated Funds") /// 
label(12 "100% in Dominated Funds")) ///
ylabel(,nogrid) ytitle(Return) xtitle(Variance) ///
title("Highlighting Dominated Fund Prevalence" "For Pre-Reform Portfolios", size(medsmall) pos(12)) ///
note("Limited to observations with variance < 0.03")
graph save "$temp/dominated_funds_1", replace


twoway (scatter return_used var_used if date == 684 & dominated_simple == 0 & var_used < .03, mcolor("$color_p2") msize(vsmall) msymbol(o)) ///
(scatter return_used var_used if date == 684 & dominated_simple > 0 & dominated_simple < .1 & var_used < .03, mcolor("$color_p3*.1") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & dominated_simple >= .1 & dominated_simple < .2 & var_used < .03, mcolor("$color_p3*.2") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & dominated_simple >= .2 & dominated_simple < .3 & var_used < .03, mcolor("$color_p3*.3") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & dominated_simple >= .3 & dominated_simple < .4 & var_used < .03, mcolor("$color_p3*.4") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & dominated_simple >= .4 & dominated_simple < .5 & var_used < .03, mcolor("$color_p3*.5") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & dominated_simple >= .5 & dominated_simple < .6 & var_used < .03, mcolor("$color_p3*.6") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & dominated_simple >= .6 & dominated_simple < .7 & var_used < .03, mcolor("$color_p3*.7") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & dominated_simple >= .7 & dominated_simple < .8 & var_used < .03, mcolor("$color_p3*.8") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & dominated_simple >= .8 & dominated_simple < .9 & var_used < .03, mcolor("$color_p3*.9") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & dominated_simple >= .9 & dominated_simple < 1 & var_used < .03, mcolor("$color_p3") msize(vsmall) msymbol(o)) /// 
(scatter return_used var_used if date == 684 & dominated_simple == 1 & var_used < .03, mcolor("$color_p3*1.2") msize(medlarge) msymbol(X)), ///
ylabel(,nogrid) ytitle(Return) xtitle(Variance) ///
title("Highlighting Dominated Fund Prevalence" "For Post-Reform Portfolios", size(medsmall) pos(12))
graph save "$temp/dominated_funds_2", replace

grc1leg "$temp/dominated_funds_1" "$temp/dominated_funds_2", xcomm ycomm ///
note("Portfolios with holdings in dominated funds are shaded by the share of the dominated funds within the portfolio.", size(tiny)) 


graph export "$output/45 - Dominated Fund Holdings.png", replace 
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

twoway (line graph_equities age, lcolor("$color_p2")) ///
(scatter graph_equities age, msize(small) mcolor("$color_p2")) ///
(scatter graph_equities2 age, msize(small) mcolor("$color_p4")) ///
(line graph_equities2 age, lpattern(dash) lcolor("$color_p4")) ///
(scatter graph_equities3 age, msize(small) mcolor("$color_p4")) ///
(line graph_equities3 age, lpattern(dash) lcolor("$color_p4")) ///
(line total_eq_violation age, yaxis(2) lpattern(dash) lcolor("$color_p3")) ///
, ylab(#5, axis(1) nogrid) ylab(#5, axis(2) nogrid) ysc(r(0 100) axis(1)) ysc(r(0 100) axis(2)) ytitle("Percent Equities", axis(1)) ///
title("Vanguard TDF And Guardrail" "Equity Glide Path", pos(12) size(medium)) ///
legend(order(1 4 7) label(1 "TDF Glide Path") label(4 "Guardrail Bounds") label(7 "Percent Violating Guardrail"))
graph export "$output/52 - Glide Path Equities.png", replace

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
	
	export excel "$output/41 - Streamlined Reallocation.xlsx", replace firstrow(varlabels) sheet("2016 Steamlining Allocations")
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
	save("$output/42 - Differences in Streamlined Individual Characteristics.xlsx") replace
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
	
	export excel "$output/43 - Reallocation Pre-Reform Share of Assets.xlsx", firstrow(varlabels) replace

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
	
	export excel "$output/43.1 - Reallocation Pre-Reform Share of Dominated Funds.xlsx", firstrow(varlabels) replace

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
	hist port_diff if same_funds == 1, ylabel(,nogrid) color(ebblue*.7) percent
	graph export "$output/47 - Allocation Changes in Default Funds.png", replace
	
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
	hist port_diff if same_funds == 1, ylabel(,nogrid) color(ebblue*.7) percent

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
	
	export excel "$output/63 - Share of Portfolio Streamlined.xlsx", replace firstrow(varlabels) keepcellfmt

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
	
	export excel "$output/64 - Streamlined Defaults 2017-2018.xlsx", sheet("Ignoring Share Class") replace firstrow(varlabels) keepcellfmt

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
	
	putexcel set "$output/63 - Share of Portfolio Streamlined.xlsx", modify
	
	putexcel A6 = ("Streamlined, all")
	putexcel B6 = (counter[1])
	putexcel C6 = (over_50[1])
	putexcel D6 = (over_90[1])
	putexcel E6 = (per_streamlined[1])

	putexcel close
	
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
	
	export excel "$output/44 - Difference in Mean Allocation Post-Pre Reform.xlsx", firstrow(varlabels) replace
	

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
	
	export excel "$output/44.1  - Difference in Mean Allocation 2016-2018.xlsx", firstrow(varlabels) replace
	

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
	export excel "$output\48 - Reallocation Regressions.xlsx", replace
restore

// add in variable means
putexcel set "$output/48 - Reallocation Regressions.xlsx", modify sheet("Sheet1")
putexcel B1 = "Mean"
putexcel C1 = "(1)"
putexcel D1 = "(2)"
putexcel E1 = "(3)"
putexcel F1 = "(4)"
putexcel G1 = "(5)"
putexcel H1 = "(6)"
putexcel I1 = "(7)"
putexcel J1 = "(8)"

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


/*
Guardrails Overweighting Tables
ZRS 
11/13/2019

Goal:
-- 

Notes:
--

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
		
		export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(variables) sheet("`sheet'") sheetreplace keepcellfmt
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

export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Cash_Bond Age") sheetreplace keepcellfmt 

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

export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Equities Age With TDFs") sheetreplace keepcellfmt 

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


export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Equities Age No Sole TDFs") sheetreplace keepcellfmt 

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

export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Money Market Age") sheetreplace keepcellfmt 

}

{ // gold bugs graphs (note that these variables are only flagged for 2016 funds) 
// Eni edited 
use "$temp/collapse2_combined.dta", clear
gen graph_helper = . 

summ goldbug if date == 672

keep if inlist(date,672,684)

twoway (scatter return_used var_used if var_used < .03 & goldbug16 == 0, mcolor("$color_p2") msize(vtiny) msymbol(o) by(date)) ///
(scatter return_used var_used if var_used < .03 & goldbug16 == 1, mfcolor(gs11) mlcolor(gs0) msize(vsmall) msymbol(D) by(date, note("Only portfolios with variance < .03 are shown." , size(tiny)) ///
title("Goldbug Returns Pre- and Post-Reform", span size(medsmall) pos(12)))) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(small) msymbol(o)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "Other portfolios") ///
label(2 "Goldbugs (>20% of" "2016 portfolio in gold)")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
subtitle(, fcolor(white) lcol(white))
graph export "$output/26 - Goldbug Outcomes.png", replace 


twoway (scatter return_used var_used if var_used < .03 & goldbug16 == 0 & date == 672, mcolor("$color_p2") msize(vtiny) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & goldbug16 == 1 & date == 672, mfcolor(gs11) mlcolor(gs0) msize(vsmall) msymbol(D)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(small) msymbol(o)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "Other portfolios") ///
label(2 "Goldbugs (>20% of" "2016 portfolio in gold)")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
note("Only portfolios with variance < .03 are shown.", size(tiny)) ///
title("Goldbug Returns Pre-Reform", span size(medsmall) pos(12))
graph export "$output/26.1 - Goldbug Outcomes Pre-Reform.png", replace 
graph save "$temp/26.1 - Goldbug Outcomes Pre-Reform.gph", replace 

gen flag = (ScrubbedID == 43315)

twoway (scatter return_used var_used if var_used < .03 & goldbug16 == 0, mcolor("$color_p2") msize(vtiny) msymbol(o) by(date)) ///
(scatter return_used var_used if var_used < .03 & goldbug16 == 1, mfcolor(gs11) mlcolor(gs0) msize(vsmall) msymbol(D) by(date, note("Only portfolios with variance < .03 are shown." , size(tiny)) ///
title("Goldbug Returns Pre- and Post-Reform", span size(medsmall) pos(12)))) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(small) msymbol(o)) ///
(scatter return_used var_used if flag == 1, mcolor(orange) msize(medsmall) msymbol(S) by(date)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "Other portfolios") ///
label(2 "Goldbugs (>20% of" "2016 portfolio in gold)")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
subtitle(, fcolor(white) lcol(white))
graph export "$output/26.2 - Goldbug Outcomes 2.png", replace 


twoway (scatter return_used var_used if var_used < .03 & goldbug16 == 0 & date == 672, mcolor("$color_p2") msize(vtiny) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & goldbug16 == 1 & date == 672, mfcolor(gs11) mlcolor(gs0) msize(vsmall) msymbol(D)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(small) msymbol(o)) ///
(scatter return_used var_used if flag == 1 & date ==672, mcolor(orange) msize(medsmall) msymbol(S)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "Other portfolios") ///
label(2 "Goldbugs (>20% of" "2016 portfolio in gold)")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
note("Only portfolios with variance < .03 are shown.", size(tiny)) ///
title("Goldbug Returns Pre-Reform", span size(medsmall) pos(12))
graph export "$output/26.3 - Goldbug Outcomes Pre-Reform 2.png", replace 


use "$temp/collapse2_combined.dta", clear
gen graph_helper = . 

summ goldbug if date == 672

keep if inlist(date,672,684,990,991)


twoway (scatter return_used var_used if var_used < .03 & goldbug16 == 0, mcolor("$color_p2") msize(vtiny) msymbol(o) by(date, ix col(3))) ///
(scatter return_used var_used if var_used < .03 & goldbug16 == 1, mfcolor(gs11) mlcolor(gs0) msize(vsmall) msymbol(D) by(date, note("Only portfolios with variance < .03 are shown." , size(tiny)) ///
title("Goldbug Returns With And Without Reforms", span size(medsmall) pos(12)))) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(small) msymbol(o)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "Other portfolios") ///
label(2 "Goldbugs (>20% of" "2016 portfolio in gold)")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
subtitle(, fcolor(white) lcol(white))
graph export "$output/26.2 - Goldbug Outcomes With Guardrails.png", replace 


// arrow graph
keep if inlist(date, 672, 684)
keep if goldbug16 == 1
keep ScrubbedID date return_used var_used

reshape wide return_used var_used, i(ScrubbedID) j(date)

twoway (pcarrow return_used672 var_used672 return_used684 var_used684, mcolor(gs0) lcolor(gs10) lwidth(vthin) msize(small) msymbol(T)) ///
(scatter return_used672 var_used672, mcolor(gs7) msize(small) msymbol(o)) ///
, title("Goldbug Returns With And Without Reforms", span size(medsmall) pos(12)) ///
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
subtitle(, fcolor(white) lcol(white)) legend(off)


graph export "$output/26.3 - Goldbug Outcomes Arrows.png", replace 






}

{ // one sector overweighted diversification guardrail graph
// Eni edited 
use "$temp/collapse2_combined.dta", clear
gen graph_helper = . 

keep if inlist(date,672)

twoway (scatter return_used var_used if var_used < .03 & one_sector_overweight == 0 & date == 672, mcolor("$color_p2") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & one_sector_overweight == 1 & date == 672, mfcolor("$color_p4") mlcolor(gs1) msize(vsmall) msymbol(d)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(small) msymbol(o)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "At Least One Sector Fund Overweighted") ///
label(2 "No Sector Funds Overweighted")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
note("Only portfolios with variance < .03 are shown.", size(tiny)) ///
title("Highlighting Sector Fund Diversification Guardrail" "Returns Pre-Reform", span size(medsmall) pos(12))
graph export "$output/53 - sector diversification guardrail scatterplot.png", replace 
graph save "$temp/53 - sector diversification guardrail scatterplot.gph", replace 

}

{ // international share of equities diversification guardrail graph
// Eni edited
use "$temp/collapse2_combined.dta", clear
gen graph_helper = . 
set seed 758901
gen rand = runiformint(1,10)

keep if inlist(date,672)


twoway (scatter return_used var_used if var_used < .03 & total_intl_share_under == 1 & date == 672, mfcolor(gs12) mlcolor(gs12) msize(vsmall) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & total_intl_share_under == 0 & date == 672 & smart == 0, mfcolor (gs5) mcolor(gs5) msize(vsmall) msymbol(d)) ///
(scatter graph_helper graph_helper, mcolor(gs12) msize(vsmall) msymbol(o)), legend(size(vsmall) order(2 3) ///
label(3 "International Equities Not Underweighted Among Equities") ///
label(2 "International Equities Underweighted Among Equities")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
note("Only portfolios with variance < .03 are shown.", size(tiny)) ///
title("Highlighting International Equities Diversification Guardrail" "Returns Pre-Reform", span size(medsmall) pos(12))
graph export "$output/57 - international equities diversification guardrail scatterplot.png", replace 
graph save "$temp/57 - international equities diversification guardrail scatterplot.gph", replace 
//
twoway (scatter return_used var_used if var_used < .03 & total_intl_share_under == 0 & date == 672 & smart == 0, mcolor("$color_p2") msize(vtiny) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & total_intl_share_under == 1 & date == 672 & intl_equity_share < .05 & equities > .80, mfcolor("$color_p4*.5") mlcolor(gs0%20) msize(vsmall) msymbol(d)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(vsmall) msymbol(o)) ///
(scatter return_used var_used if date == 672 & var_used < .5 & smart == 1, mcolor("$color_p3") msize(vsmall) msymbol(o)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "International Equities Not Underweighted Among Equities") ///
label(2 "International Equities Underweighted Among Equities")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
note("Only portfolios with variance < .03 are shown." ///
"TDFs highlighted in orange." ///
"Only guardrail violators with over 80% of assets in equities and less than 5% of equities in international equities are shown.", size(tiny)) ///
title("Highlighting International Equities Diversification Guardrail" "Returns Pre-Reform", span size(medsmall) pos(12))
graph export "$output/57.1 - worst international equities diversification guardrail scatterplot.png", replace 
graph save "$temp/57.1 - worst international equities diversification guardrail scatterplot.gph", replace 

twoway (scatter return_used var_used if var_used < .03 & total_intl_share_under == 0 & date == 672 & smart == 0, mcolor("$color_p2") msize(vtiny) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & total_intl_share_under == 1 & date == 672 & rand == 1, mfcolor("$color_p4*.5") mlcolor(gs0%20) msize(vsmall) msymbol(d)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(vsmall) msymbol(o)) ///
(scatter return_used var_used if date == 672 & var_used < .5 & smart == 1, mcolor("$color_p3") msize(vsmall) msymbol(o)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "International Equities Not Underweighted Among Equities") ///
label(2 "International Equities Underweighted Among Equities")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
note("Only portfolios with variance < .03 are shown." ///
"TDFs highlighted in orange." ///
"A 10% sample of guardrails violators are displayed.", size(tiny)) ///
title("Highlighting International Equities Diversification Guardrail" "Returns Pre-Reform", span size(medsmall) pos(12))
graph export "$output/57.2 - sample international equities diversification guardrail scatterplot.png", replace 
graph save "$temp/57.2 - sample international equities diversification guardrail scatterplot.gph", replace 


}

{ // fee mistakes guardrail graph
//Eni edited
use "$temp/collapse2_combined.dta", clear
gen graph_helper = . 

keep if inlist(date,672)

twoway (scatter return_used var_used if var_used < .03 & total_exp_over == 0 & date == 672, mcolor("$color_p2") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & total_exp_over == 1 & date == 672, mfcolor("$color_p4") mlcolor(gs1) msize(vsmall) msymbol(d)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(small) msymbol(o)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "Not Affected By Fee Guardrail") ///
label(2 "Affected By Fee Guardrail")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
note("Only portfolios with variance < .03 are shown.", size(tiny)) ///
title("Highlighting Fee Mistakes Guardrail" "Returns Pre-Reform", span size(medsmall) pos(12))
graph export "$output/54 - fee mistakes guardrails scatterplot.png", replace 
graph save "$temp/54 - fee mistakes guardrails scatterplot.gph", replace 



}

{ // exposure guardrail graphs
// Eni edited
use "$temp/collapse2_combined.dta", clear
gen graph_helper = . 

keep if inlist(date,672)

twoway (scatter return_used var_used if var_used < .03 & total_eq_violation == 0 & date == 672, mcolor("$color_p2") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & total_eq_violation == 1 & date == 672, mfcolor(gs7) mlcolor(gs5) msize(vsmall) msymbol(d)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(vsmall) msymbol(o)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "Not Violating Equity Exposure Guardrail") ///
label(2 "Violating Equity Exposure Guardrail")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
note("Only portfolios with variance < .03 are shown.", size(tiny)) ///
title("Highlighting Exposure Guardrail" "Returns Pre-Reform", span size(medsmall) pos(12))
graph export "$output/55 - exposure guardrail scatterplot.png", replace 
graph save "$temp/55 - exposure guardrail scatterplot.gph", replace 

twoway (scatter return_used var_used if var_used < .03 & total_eq_over == 0 & date == 672, mcolor("$color_p2") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & total_eq_over == 1 & date == 672, mfcolor(gs7) mlcolor(gs5) msize(vsmall) msymbol(d)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(vsmall) msymbol(o)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "Not Violating Maximum Equity Exposure Guardrail") ///
label(2 "Violating Maximum Equity Exposure Guardrail")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
note("Only portfolios with variance < .03 are shown.", size(tiny)) ///
title("Highlighting Maximum Equity Exposure Guardrail" "Returns Pre-Reform", span size(medsmall) pos(12))
graph export "$output/55.1 - exposure upper bound guardrail scatterplot.png", replace 
graph save "$temp/55.1 - exposure upper bound guardrail scatterplot.gph", replace 

twoway (scatter return_used var_used if var_used < .03 & total_eq_under == 0 & date == 672, mcolor("$color_p2") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & total_eq_under == 1 & date == 672, mfcolor(gs7) mlcolor(gs5) msize(vsmall) msymbol(d)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(vsmall) msymbol(o)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "Not Violating Minimum Equity Exposure Guardrail") ///
label(2 "Violating Minimum Equity Exposure Guardrail")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
note("Only portfolios with variance < .03 are shown.", size(tiny)) ///
title("Highlighting Minimum Equity Exposure Guardrail" "Returns Pre-Reform", span size(medsmall) pos(12))
graph export "$output/55.2 - exposure lower bound guardrail scatterplot.png", replace 
graph save "$temp/55.2 - exposure lower bound guardrail scatterplot.gph", replace 



}

{ // combining guardrails graphs XXXXXXXXXXXXXXX
graph combine "$temp/26.1 - Goldbug Outcomes Pre-Reform" ///
"$temp/53 - sector diversification guardrail scatterplot" ///
"$temp/57 - international equities diversification guardrail scatterplot" ///
"$temp/54 - fee mistakes guardrails scatterplot" ///
"$temp/55 - exposure guardrail scatterplot" ///
"$temp/55.1 - exposure upper bound guardrail scatterplot" ///
"$temp/55.2 - exposure lower bound guardrail scatterplot"

graph export "$output/58 - Combined Guardrails Graphs.png", replace 


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

twoway (scatter return_used var_used if decrease_and_affected == 0 & guardrail_not_intl == 1, mcolor("$color_p2") msize(vsmall) msymbol(o)) ///
(scatter return_used var_used if decrease_and_affected == 1, mcolor("$color_p3") msize(vsmall) msymbol(o)) ///
, legend(size(vsmall) ///
label(2 "Affected by Non-International Joint Guardrail and Had Decrease in Sharpe Ratio") ///
label(1 "Affected by Non-International Joint Guardrail")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
title("Highlighting Joint Guardrail" "with Decrease in Sharpe Ratio", span size(medsmall) pos(12))
graph export "$output/68 - Joint Guardrail with Decrease in Sharpe Ratio.png", replace 


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

twoway (scatter return_used var_used if increase_group == 0, mcolor("0 114 178") msize(small) msymbol(o)) ///
(scatter return_used var_used if increase_group == 1, mcolor("213 94 0") msize(small) msymbol(o)) ///
(scatter return_used var_used if decrease_and_affected == 1, mcolor("240 228 66") msize(small) msymbol(o)) ///
, legend(size(vsmall) ///
label(3 "Decreased Sharpe Ratio") ///
label(1 "Increased Sharpe Group One") /// 
label(2 "Increased Sharpe Group Two")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
title("Highlighting Joint Guardrail" "with Decrease in Sharpe Ratio", span size(medsmall) pos(12))
graph export "$output/68.1 - Joint Guardrail with Sharpe Decrease Comparison.png", replace 


}

{ // overweighted total money market funds graph
use "$temp/collapse2_combined.dta", clear
gen graph_helper = . 

summ total_mm_overweight if date == 672


keep if inlist(date,672,684)

twoway (scatter return_used var_used if var_used < .03 & overmm16 == 0, mcolor("$color_p2") msize(vtiny) msymbol(o) by(date)) ///
(scatter return_used var_used if var_used < .03 & overmm16 == 1, mcolor(orange*.8) msize(tiny) msymbol(o) by(date, note("Only portfolios with variance < .03 are shown." , size(tiny)) ///
title("Total Money Market Fund Overweighting Returns Pre- and Post-Reform", span size(medsmall) pos(12)))) ///
(scatter graph_helper var_used if var_used < .03 , mcolor("$color_p2") msize(medium) msymbol(o)) ///
(scatter graph_helper var_used if var_used < .03 , mcolor(orange*.8) msize(medium) msymbol(o)) ///
, legend(size(vsmall) order(4 3) ///
label(3 "Other portfolios") ///
label(4 "Money market funds overweighted before reform" "(>20% of 2016 portfolio in money market funds combined)")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
subtitle(, fcolor(white) lcol(white))

graph export "$output/29 - Money Market Overweighted Outcomes.png", replace 

}

{ // underweighting international equities graphs/table

use "$temp/collapse2_combined.dta", clear

keep if inlist(date, 684, 672, 990)

// create variables for weight over x%
gen share_any = intl_equity_share == 0
gen share_10_under = intl_equity_share < .10
gen share_20_under = intl_equity_share < .20
gen share_30_under = intl_equity_share < .30
gen share_40_under = intl_equity_share < .40
gen share_50_under = intl_equity_share < .50
gen share_60_under = intl_equity_share < .60
gen share_70_under = intl_equity_share < .70
gen share_80_under = intl_equity_share < .80
gen share_90_under = intl_equity_share < .90
gen share_100 = intl_equity_share < 1

	// collapse to summarize share of investors over x% in each fund 
collapse (mean) share_*, by(date)

la var share_any "Share of investors with no international equities"
la var share_10_under "Share of investors with less than 10% of assets in international equities"
la var share_20_under "Share of investors with less than 20% of assets in international equities"
la var share_30_under "Share of investors with less than 30% of assets in international equities"
la var share_40_under "Share of investors with less than 40% of assets in international equities"
la var share_50_under "Share of investors with less than 50% of assets in international equities"
la var share_60_under "Share of investors with less than 60% of assets in international equities"
la var share_70_under "Share of investors with less than 70% of assets in international equities"
la var share_80_under "Share of investors with less than 80% of assets in international equities"
la var share_90_under "Share of investors with less than 90% of assets in international equities"
la var share_100 "Share of investors with less than 100% of assets in international equities"
sort date
decode date, gen(date2)
la var date2 "Date"
drop date
keep date2 share_any share_10_under share_20_under share_30_under share_40_under share_50_under
order date2 share_*

export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("International Equities") sheetreplace keepcellfmt 
	
	
use "$temp/collapse2_combined.dta", clear

twoway (hist intl_equity_share if date == 672 [fweight = total_assets], percent color("$color_p2%30") w(.05)) /// 
(hist intl_equity_share if date == 684 [fweight = total_assets], percent color("$color_p3%30") w(.05)), /// 
legend(label(1 Pre-Reform Counterfactual) label(2 Post-Reform Realized) size(vsmall)) ///
ylabel(#3, angle(0) format(%3.0f) labsize(vsmall) nogrid) ///
xlabel(, labsize(vsmall)) ///
ytitle("Share Of Assets (%)", size(small)) ///
xtitle("Share in International Equities (%)", size(small)) ///
title(Share of Assets in International Equities, pos(12) size(medium))

graph export "$output/34 - International Equities By Assets Post-Pre.png", replace


twoway (hist intl_equity_share if date == 672 [fweight = total_assets], percent color("$color_p2%30") w(.05)) /// 
(hist intl_equity_share if date == 990 [fweight = total_assets], percent color("$color_p3%30") w(.05)), /// 
legend(label(1 Pre-Reform Counterfactual) label(2 All Joint Guardrails to TDF) size(vsmall)) ///
ylabel(#3, angle(0) format(%3.0f) labsize(vsmall) nogrid) ///
xlabel(, labsize(vsmall)) ///
ytitle("Share Of Assets (%)", size(small)) ///
xtitle("Share in International Equities (%)", size(small)) ///
title(Share of Assets in International Equities, pos(12) size(medium))

graph export "$output/34.1 - International Equities By Assets Guardrails-Pre.png", replace


twoway (hist intl_equity_share if date == 684 & present_2018 == 1 [fweight = total_assets], percent color("$color_p2%30") w(.05)) /// 
(hist intl_equity_share if date == 696 [fweight = total_assets], percent color("$color_p3%30") w(.05)), /// 
legend(label(1 "Post Reform (2017)") label(2 "Post Reform (2018)") size(vsmall)) ///
ylabel(#3, angle(0) format(%3.0f) labsize(vsmall) nogrid) ///
xlabel(, labsize(vsmall)) ///
ytitle("Share Of Assets (%)", size(small)) ///
xtitle("Share in International Equities (%)", size(small)) ///
title(Share of Assets in International Equities, pos(12) size(medium))

graph export "$output/34.2 - International Equities By Assets 2017-2018.png", replace

	
	

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

export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Investment Category") sheetreplace keepcellfmt

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

export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabel) sheet("% Eq That Are Intl-Streamlined") sheetreplace keepcellfmt 

putexcel set "$output/25 - Fund Allocations.xlsx" , modify sheet("% Eq That Are Intl-Streamlined")
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

export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabel) sheet("% Eq That Are Intl - All") sheetreplace keepcellfmt 

putexcel set "$output/25 - Fund Allocations.xlsx" , modify sheet("% Eq That Are Intl - All")
putexcel A12 = "Share of all investors with less than x% of equities in international equities" 
putexcel A13 = "Includes all investors" 
putexcel close




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

	export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("All inv over x% in fund") sheetreplace keepcellfmt

	putexcel set "$output/25 - Fund Allocations.xlsx" , modify sheet("All inv over x% in fund")
	putexcel A282 = "Share of all investors with over x% in fund, pre-reform" 
	putexcel close
	
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

	export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Subset inv over x% in fund") sheetreplace keepcellfmt

	putexcel set "$output/25 - Fund Allocations.xlsx" , modify sheet("Subset inv over x% in fund")
	putexcel A282 = "Share of investors that own a given fund that hold over x% of assets in fund, pre-reform" 
	putexcel close
	
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

	export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Ex. subset over x% in fund") sheetreplace keepcellfmt

	putexcel set "$output/25 - Fund Allocations.xlsx" , modify sheet("Ex. subset over x% in fund")
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
	
	export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("All under x% in fund type") sheetreplace keepcellfmt

	putexcel set "$output/25 - Fund Allocations.xlsx" , modify sheet("All under x% in fund type")
	putexcel A13 = "Share of all investors that have under x% of assets in fund type, pre-reform"  
	putexcel close
	
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
	
	export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Subset inv over x% in fund type") sheetreplace keepcellfmt

	putexcel set "$output/25 - Fund Allocations.xlsx" , modify sheet("Subset inv over x% in fund type")
	putexcel A13 = "Share of investors that hold a given fund type that have over x% of assets in fund type, pre-reform"  
	putexcel close
	
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

	export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("All inv over x% by exp ratio") sheetreplace keepcellfmt

	putexcel set "$output/25 - Fund Allocations.xlsx" , modify sheet("All inv over x% by exp ratio")
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

	export excel using "$output/25 - Fund Allocations.xlsx" , firstrow(varlabels) sheet("Subset over x% by exp ratio") sheetreplace keepcellfmt

	putexcel set "$output/25 - Fund Allocations.xlsx" , modify sheet("Subset over x% by exp ratio")
	putexcel A10 = "Share of investors in a given expense ratio category with over x% in expense ratio category, pre-reform" 
	putexcel close
restore
}

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

twoway hist non_plan_over_savings, w(1) ylab(,nogrid) color("$color_p2") percent ///
title("Additional Non-Gold Assets Needed to Justify Gold Holdings," "As a Multiple of Observed UVA 403(b) Savings", pos(12) size(medsmall))
graph export "$output/49 - Gold Outside Savings.png", replace

// conservatively calculate reasonable outside savings as 10% of current salary since age 22 ("Diversification Across Time" mentions as a constant 10% savings rate) 
// substract half of savings in UVA account (assuming 1:1 employer matching)
// assuming compounded annually
// balance(Y) = P(1 + r)Y   +   c[ ((1 + r)Y - 1) / r ]; P = 0, c = 10% of current salary, r = 5%, Y = years since age 22
gen reasonable_outside = .1 * RoundedSalary * ((1.05 * (age2018 - 2 - 22) - 1) / 1.05) - total_assets/2
replace reasonable_outside  = 0 if reasonable_outside < 0

gen diff_savings = non_plan_non_gold_assets - reasonable_outside
replace diff_savings = 0 if port_weight <= .02
summ diff_savings
twoway hist diff_savings if port_weight >= .02, ylab(,nogrid) color("$color_p2") percent w(250000) ///
title("Difference Between Assets Needed to Justify Gold" "And Assets Held", pos(12) size(medsmall)) ///
xtitle("Difference") note("Positive values indicate estimated savings fall short of necessary savings" ///
"Only includes individuals that hold 2%+ of observed portfolio in the gold fund and for which 2016 salary data is available", size(tiny))

// create variable to flag people that should have enough outside assets to justify gold holdings
gen enough_outside = ((reasonable_outside >= non_plan_non_gold_assets & reasonable_outside < .) | port_weight <= .02)
replace enough_outside = . if missing(non_plan_non_gold_assets) & port_weight > .02

// graph share likely can justify gold holdings 
binscatter enough_outside port_weight, nq(9) ///
linetype(none) mcolor("$color_p2") ylab(,nogrid) xtitle("Share of Gold in Portfolio") ///
ytitle("Share of portfolios that can justify gold holdings") ///
title("Share of Portfolios That Can Justify Gold Holdings," "By Share of Gold in Portfolio", size(medium) pos(12))
graph export "$output/49.1 - Percent Justified Gold Holdings.png", replace
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

twoway hist non_plan_over_savings, w(1) ylab(,nogrid) color("$color_p2") percent ///
title("Additional Non-Sector Assets Needed to Justify Sector Fund Holdings," "As a Multiple of Observed UVA 403(b) Savings", pos(12) size(medsmall))
graph export "$output/56 - Sector Outside Savings.png", replace

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
binscatter enough_outside sector, nq(9) ///
linetype(none) color("$color_p2") ylab(,nogrid) xtitle("Share of Sector Funds in Portfolio") ///
ytitle("Share of portfolios that" "can justify sector fund holdings") ///
title("Share of Portfolios That Can Justify Sector Fund Holdings," "By Share of Sector Funds in Portfolio", size(medium) pos(12))
graph export "$output/56.1 - Percent Justified Sector Holdings.png", replace
save "$temp/sector_outside_holdings", replace
}

{ // sharpe ratio graphs for guardrails
use "$temp/collapse2_combined.dta", clear
gen graph_helper = . 

keep if inlist(date,672)

gen sharpe2 = sharpe
replace sharpe = -1 if sharpe < -1 
replace sharpe = 10 if sharpe > 10

putexcel set "$output/59 - Guardrails Sharpe Ratio Means.xlsx", replace
putexcel A4 = "Expense Ratio Guardrail"
putexcel A5 = "Equity Exposure Guardrail"
putexcel A6 = "Minimum Equity Exposure Guardrail"
putexcel A7 = "Maximum Equity Exposure Guardrail"
putexcel A8 = "International Equities As Share of Equities Guardrail"
putexcel A9 = "Sector Fund Guardrail"
putexcel A10 = "Goldbugs"
putexcel B1:E1, hcenter merge
putexcel F1:I1, hcenter merge
putexcel J1:M1, hcenter merge
putexcel B2:C2, hcenter merge
putexcel D2:E2, hcenter merge
putexcel F2:G2, hcenter merge
putexcel H2:I2, hcenter merge
putexcel J2:K2, hcenter merge
putexcel L2:M2, hcenter merge
putexcel B1 = "Without Top- And Bottom-Coding"
putexcel F1 = "With Top- And Bottom-Coding"
putexcel J1 = "Dropping If > 10 or < -1"
putexcel B2 = "Violating Guardrail"
putexcel D2 = "Not Violating Guardrail"
putexcel F2 = "Violating Guardrail"
putexcel H2 = "Not Violating Guardrail"
putexcel J2 = "Violating Guardrail"
putexcel L2 = "Not Violating Guardrail"
putexcel B3 = "Mean", hcenter
putexcel C3 = "SD", hcenter
putexcel D3 = "Mean", hcenter
putexcel E3 = "SD", hcenter
putexcel F3 = "Mean", hcenter
putexcel G3 = "SD", hcenter
putexcel H3 = "Mean", hcenter
putexcel I3 = "SD", hcenter
putexcel J3 = "Mean", hcenter
putexcel K3 = "SD", hcenter
putexcel L3 = "Mean", hcenter
putexcel M3 = "SD", hcenter


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

putexcel B4 = `base_mean_1'
putexcel D4 = `base_mean_0'
putexcel F4 = `bound_mean_1'
putexcel H4 = `bound_mean_0'
putexcel J4 = `drop_mean_1'
putexcel L4 = `drop_mean_0'
putexcel C4 = `base_sd_1'
putexcel E4 = `base_sd_0'
putexcel I4 = `bound_sd_0'
putexcel G4 = `bound_sd_1'
putexcel K4 = `drop_sd_1'
putexcel M4 = `drop_sd_0'
twoway (hist sharpe if date == 672 & total_exp_over == 0, start(-1) w(.1) percent color(gs6)) ///
(hist sharpe if date == 672 & total_exp_over == 1, start(-1) w(.1) percent color(gs11)), ///
legend(label(1 "Not Violating Expense Ratio Guardrail") label(2 "Violating Expense Ratio Guardrail")) ///
xtitle(Sharpe Ratio) ylabel(,nogrid) xline(0, lcolor(gs10)) ///
title("Pre-Reform Sharpe Ratio" "For Expense Ratio Guardrail", size(medium) pos(12)) ///
note("Sharpe ratios are bottom-coded at -1 and top-coded at 10." ///
"With top- and bottom-coding, the Sharpe ratio for those violating the guardrail is `bound_mean_1' and the Sharpe ratio for those not violating the guardrail is `bound_mean_0'.", size(tiny))
graph export "$output/59.1 - Sharpe Ratio - Expense Ratio Guardrail.png", replace 

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

putexcel B5 = `base_mean_1'
putexcel D5 = `base_mean_0'
putexcel F5 = `bound_mean_1'
putexcel H5 = `bound_mean_0'
putexcel J5 = `drop_mean_1'
putexcel L5 = `drop_mean_0'
putexcel C5 = `base_sd_1'
putexcel E5 = `base_sd_0'
putexcel I5 = `bound_sd_0'
putexcel G5 = `bound_sd_1'
putexcel K5 = `drop_sd_1'
putexcel M5 = `drop_sd_0'
twoway (hist sharpe if date == 672 & total_eq_violation == 0, start(-1) w(.1) percent color("$color_p2%30")) ///
(hist sharpe if date == 672 & total_eq_violation == 1, start(-1) w(.1) percent color("$color_p3%30")), ///
legend(label(1 Not Violating Guardrail) label(2 Violating Guardrail)) ///
xtitle(Sharpe Ratio) ylabel(,nogrid) xline(0, lcolor(gs10)) ///
title("Pre-Reform Sharpe Ratio" "For Equity Exposure Guardrail", size(medium) pos(12)) ///
note("Sharpe ratios are bottom-coded at -1 and top-coded at 10." ///
"With top- and bottom-coding, the Sharpe ratio for those violating the guardrail is `bound_mean_1' and the Sharpe ratio for those not violating the guardrail is `bound_mean_0'.", size(tiny))
graph export "$output/59.2 - Sharpe Ratio - Equity Exposure Guardrail.png", replace 

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

putexcel B6 = `base_mean_1'
putexcel D6 = `base_mean_0'
putexcel F6 = `bound_mean_1'
putexcel H6 = `bound_mean_0'
putexcel J6 = `drop_mean_1'
putexcel L6 = `drop_mean_0'
putexcel C6 = `base_sd_1'
putexcel E6 = `base_sd_0'
putexcel I6 = `bound_sd_0'
putexcel G6 = `bound_sd_1'
putexcel K6 = `drop_sd_1'
putexcel M6 = `drop_sd_0'
twoway (hist sharpe if date == 672 & total_eq_under == 0, start(-1) w(.1) percent color("$color_p2%30")) ///
(hist sharpe if date == 672 & total_eq_under == 1, start(-1) w(.1) percent color("$color_p3%30")), ///
legend(label(1 Not Violating Guardrail) label(2 Violating Guardrail)) ///
xtitle(Sharpe Ratio) ylabel(,nogrid) xline(0, lcolor(gs10)) ///
title("Pre-Reform Sharpe Ratio" "For Minimum Equity Exposure Guardrail", size(medium) pos(12)) ///
note("Sharpe ratios are bottom-coded at -1 and top-coded at 10." ///
"With top- and bottom-coding, the Sharpe ratio for those violating the guardrail is `bound_mean_1' and the Sharpe ratio for those not violating the guardrail is `bound_mean_0'.", size(tiny))
graph export "$output/59.3 - Sharpe Ratio - Minimum Equity Exposure Guardrail.png", replace 

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

putexcel B7 = `base_mean_1'
putexcel D7 = `base_mean_0'
putexcel F7 = `bound_mean_1'
putexcel H7 = `bound_mean_0'
putexcel J7 = `drop_mean_1'
putexcel L7 = `drop_mean_0'
putexcel C7 = `base_sd_1'
putexcel E7 = `base_sd_0'
putexcel I7 = `bound_sd_0'
putexcel G7 = `bound_sd_1'
putexcel K7 = `drop_sd_1'
putexcel M7 = `drop_sd_0'
twoway (hist sharpe if date == 672 & total_eq_over == 0, start(-1) w(.1) percent color("$color_p2%30")) ///
(hist sharpe if date == 672 & total_eq_over == 1, start(-1) w(.1) percent color("$color_p3%30")), ///
legend(label(1 Not Violating Guardrail) label(2 Violating Guardrail)) ///
xtitle(Sharpe Ratio) ylabel(,nogrid) xline(0, lcolor(gs10)) ///
title("Pre-Reform Sharpe Ratio" "For Maximum Equity Exposure Guardrail", size(medium) pos(12)) ///
note("Sharpe ratios are bottom-coded at -1 and top-coded at 10." ///
"With top- and bottom-coding, the Sharpe ratio for those violating the guardrail is `bound_mean_1' and the Sharpe ratio for those not violating the guardrail is `bound_mean_0'.", size(tiny))
graph export "$output/59.4 - Sharpe Ratio - Maximum Equity Exposure Guardrail.png", replace 

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

putexcel B8 = `base_mean_1'
putexcel D8 = `base_mean_0'
putexcel F8 = `bound_mean_1'
putexcel H8 = `bound_mean_0'
putexcel J8 = `drop_mean_1'
putexcel L8 = `drop_mean_0'
putexcel C8 = `base_sd_1'
putexcel E8 = `base_sd_0'
putexcel I8 = `bound_sd_0'
putexcel G8 = `bound_sd_1'
putexcel K8 = `drop_sd_1'
putexcel M8 = `drop_sd_0'
twoway (hist sharpe if date == 672 & total_intl_share_under == 0, start(-1) w(.1) percent color("$color_p2%30")) ///
(hist sharpe if date == 672 & total_intl_share_under == 1, start(-1) w(.1) percent color("$color_p3%30")), ///
legend(label(1 Not Violating Guardrail) label(2 Violating Guardrail)) ///
xtitle(Sharpe Ratio) ylabel(,nogrid) xline(0, lcolor(gs10)) ///
title("Pre-Reform Sharpe Ratio" "For International Equities As Share of Equities Guardrail", size(medium) pos(12)) ///
note("Sharpe ratios are bottom-coded at -1 and top-coded at 10." ///
"With top- and bottom-coding, the Sharpe ratio for those violating the guardrail is `bound_mean_1' and the Sharpe ratio for those not violating the guardrail is `bound_mean_0'.", size(tiny))
graph export "$output/59.5 - Sharpe Ratio - International Equities As Share of Equities Guardrail.png", replace 

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

putexcel B9 = `base_mean_1'
putexcel D9 = `base_mean_0'
putexcel F9 = `bound_mean_1'
putexcel H9 = `bound_mean_0'
putexcel J9 = `drop_mean_1'
putexcel L9 = `drop_mean_0'
putexcel C9 = `base_sd_1'
putexcel E9 = `base_sd_0'
putexcel I9 = `bound_sd_0'
putexcel G9 = `bound_sd_1'
putexcel K9 = `drop_sd_1'
putexcel M9 = `drop_sd_0'
twoway (hist sharpe if date == 672 & one_sector_overweight == 0, start(-1) w(.1) percent color(gs6)) ///
(hist sharpe if date == 672 & one_sector_overweight == 1, start(-1) w(.1) percent color(gs11)), ///
legend(label(1 "Not Violating Sector Fund Guardrail") label(2 "Violating Sector Fund Guardrail")) ///
xtitle(Sharpe Ratio) ylabel(,nogrid) xline(0, lcolor(gs10)) ///
title("Pre-Reform Sharpe Ratio" "For Sector Fund Guardrail", size(medium) pos(12)) ///
note("Sharpe ratios are bottom-coded at -1 and top-coded at 10." ///
"With top- and bottom-coding, the Sharpe ratio for those violating the guardrail is `bound_mean_1' and the Sharpe ratio for those not violating the guardrail is `bound_mean_0'.", size(tiny))
graph export "$output/59.6 - Sharpe Ratio - Sector Fund Guardrail.png", replace 

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

putexcel B10 = `base_mean_1'
putexcel D10 = `base_mean_0'
putexcel F10 = `bound_mean_1'
putexcel H10 = `bound_mean_0'
putexcel J10 = `drop_mean_1'
putexcel L10 = `drop_mean_0'
putexcel C10 = `base_sd_1'
putexcel E10 = `base_sd_0'
putexcel I10 = `bound_sd_0'
putexcel G10 = `bound_sd_1'
putexcel K10 = `drop_sd_1'
putexcel M10 = `drop_sd_0'
twoway (hist sharpe if date == 672 & goldbug16 == 0, start(-1) w(.1) percent color("$color_p2%30")) ///
(hist sharpe if date == 672 & goldbug16 == 1, start(-1) w(.1) percent color("$color_p3%30")), ///
legend(label(1 Other Portfolios) label(2 Goldbugs) order(2 1)) ///
xtitle(Sharpe Ratio) ylabel(,nogrid) xline(0, lcolor(gs10)) ///
title("Pre-Reform Sharpe Ratio" "For Goldbugs", size(medium) pos(12)) ///
note("Sharpe ratios are bottom-coded at -1 and top-coded at 10." ///
"With top- and bottom-coding, the Sharpe ratio for those violating the guardrail is `bound_mean_1' and the Sharpe ratio for those not violating the guardrail is `bound_mean_0'.", size(tiny))
graph export "$output/59.7 - Sharpe Ratio - Goldbugs.png", replace 

putexcel close

}

{ // streamlining and guardrails sharpe ratio comparison
use "$temp/collapse2_combined.dta", clear
gen graph_helper = . 

gen sharpe2 = sharpe
replace sharpe = -1 if sharpe < -1 
replace sharpe = 10 if sharpe > 10

summ sharpe if date == 672
local bound_mean_0 = string(r(mean),"%3.2f")
summ sharpe if date == 990
local bound_mean_1 = string(r(mean),"%3.2f")

twoway (hist sharpe if date == 672, start(-1) w(.1) percent color("$color_p3%30")) ///
(hist sharpe if date == 990, start(-1) w(.1) percent color("$color_p4%30")), ///
legend(label(1 Streamlining) label(2 All Joint Guardrails to TDF)) ///
xtitle(Sharpe Ratio) ylabel(,nogrid) xline(0, lcolor(gs10)) ///
title("Sharpe Ratio Comparison Between" "Streamlining and Guardrails", size(medium) pos(12)) ///
note("Sharpe ratios are bottom-coded at -1 and top-coded at 10." ///
"With top- and bottom-coding, the Sharpe ratio for streamlining is `bound_mean_1' and the Sharpe ratio for guardrailing is `bound_mean_0'.", size(tiny))
graph export "$output/61.1 - Sharpe Ratio - Joint Guardrail vs Streamlining.png", replace 



summ sharpe if date == 672
local bound_mean_0 = string(r(mean),"%3.2f")
summ sharpe if date == 990
local bound_mean_1 = string(r(mean),"%3.2f")

twoway (hist sharpe if date == 672, start(-1) w(.1) percent color("$color_p3%30")) ///
(hist sharpe if date == 990, start(-1) w(.1) percent color("$color_p4%30")), ///
legend(label(1 Streamlining) label(2 All Non-International Joint Guardrails to TDF)) ///
xtitle(Sharpe Ratio) ylabel(,nogrid) xline(0, lcolor(gs10)) ///
title("Sharpe Ratio Comparison Between" "Streamlining and Guardrails", size(medium) pos(12)) ///
note("Sharpe ratios are bottom-coded at -1 and top-coded at 10." ///
"With top- and bottom-coding, the Sharpe ratio for streamlining is `bound_mean_1' and the Sharpe ratio for guardrailing is `bound_mean_0'.", size(tiny))
graph export "$output/61.2 - Sharpe Ratio - NonIntl Joint Guardrail vs Streamlining.png", replace 



}

{ // check international vs. domestic returns
use "$temp/collapse2_combined", clear

keep if date == 672

tab all_van_domestic
assert r(N) != 0
summ forward_future_ret forward_future_var if all_van_domestic == 1 

tab all_van_intl
assert r(N) != 0
summ forward_future_ret forward_future_var if all_van_intl == 1

}

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

putexcel A13 = "Note: Changes in Sharpe ratios are top-coded at 1 and bottom-coded at -1."
putexcel A14 = "Sharpe ratios are top-coded at 10 and bottom-coded at -1."
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

putexcel A20 = "Note: Changes in Sharpe ratios are top-coded at 1 and bottom-coded at -1."
putexcel A21 = "Sharpe ratios are top-coded at 10 and bottom-coded at -1."
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

putexcel A20 = "Note: Changes in Sharpe ratios are top-coded at 1 and bottom-coded at -1."
putexcel A21 = "Sharpe ratios are top-coded at 10 and bottom-coded at -1."
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

putexcel A13 = "Note: Changes in Sharpe ratios are top-coded at 1 and bottom-coded at -1."
putexcel A14 = "Sharpe ratios are top-coded at 10 and bottom-coded at -1."
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

export excel using "$output/69 - Income Delta Sharpe Ratio Table.xlsx", ///
firstrow(varlabels) keepcellfmt replace 














}


use "$temp/fund_types_summary", clear

preserve
	gen counter = 1
	collapse (count) count = counter , by(fund_type date)

	reshape wide count, i(fund_type) j(date)
	replace count684 = 0 if missing(count684)

	graph hbar count672 count684, over(fund_type) ///
	ylab(,nogrid) ytitle("Count") ///
	bar(1,color("$color_p2")) bar(2,color("$color_p3")) ///
	blabel(total) ///
	legend(label(1 "Pre-Reform") label(2 "Post-Reform")) 
	graph export "$output/36 - Fund Types.png", replace


	graph hbar count672, over(fund_type) ///
	ylab(,nogrid) ytitle("Count") ///
	bar(1,color("$color_p2")) ///
	blabel(total) ///
	legend(label(1 "Pre-Reform")) 
	graph export "$output/36.1 - Fund Types Pre-Only.png", replace


	la var count672 "Pre-Reform"
	la var count684 "Post-Reform"
	la var fund_type "Fund Type"
	export excel using "$output/36.2 - Fund Type Table.xlsx", replace firstrow(varlabels)
restore 


merge m:1 Fund crsp_fundno date using "$temp/dominated.dta"
cap drop _m
la define dominated_simple 1 "Dominated" 0 "Not Dominated"
la val dominated_simple dominated_simple

preserve
	gen counter = 1
	collapse (count) count = counter , by(dominated_simple date)

	reshape wide count, i(dominated_simple) j(date)
	replace count684 = 0 if missing(count684)

	graph hbar count672 count684, over(dominated_simple) ///
	ylab(,nogrid) ytitle("Count") ///
	bar(1,color("$color_p2")) bar(2,color("$color_p3")) ///
	blabel(total) ///
	legend(label(1 "Pre-Reform") label(2 "Post-Reform")) 
	
	graph export "$output/46 - Dominated Fund Counts.png", replace

restore 

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




foreach file in cleaning_step_one guard_intrm_onlytdf_joint_nonintl guard_intrm_onlytdf_joint_all guard_intrm_onlytdf_intl guard_intrm_onlytdf_equitiesover guard_intrm_onlytdf_equitiesunder guard_intrm_onlytdf_sector guard_intrm_onlytdf_expenseratio {
di "`var'"

// load portfolio data
use "$temp/`file'.dta", clear
//use "$temp/cleaning_step_one.dta", clear

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

keep if lag < 61
keep if lag > 0

joinby caldt using "$temp/factor_returns.dta"
joinby month using "$temp/rf_rate.dta"

//excess returns
foreach x of varlist mret EFA IWD IWF IWN IWO VBISX VBLTX VGSLX {
	replace `x'= `x' - RF
}

// flag observations that do not have 60 months of data for a given date
bysort date ScrubbedID: gen date_count = _N
summ date_count

// calculate portfolio betas
bysort date ScrubbedID: asreg  mret MktRF, noc rmse
rename _b_MktRF beta
drop _rmse _Nobs _R2 _adjR2

/*
preserve 
egen yearly_ret = mean(mret), by(Scrubbed date)
keep Scrubbed date yearly_ret
duplicates drop Scrubbed date, force
save "$temp/portfolio_returns", replace

use "$temp/portfolio_returns", replace
keep if date == 672
duplicates drop Scr, force //9261 
restore 
*/

// EFA is international (excludes US and Canada)
// calculate betas with other funds
bysort date ScrubbedID: asreg  mret EFA IWD IWF IWN IWO VBISX VBLTX VGSLX, noc rmse
bys ScrubbedID date: keep if _n == 1

keep ScrubbedID date beta _rmse _R2 _b_* date_count

save "$temp/portfolio_betas_`file'", replace
}


//////////////////////////////////////////////////////
//This do file merges the 403b and ORP participants
//into a single list and creates a new id with a mapping to 
//the old id.  It drops ambiguous accounts with no clear match.
//
//It takes as input the raw plan data:
//  "403b Data.xlsx"
//  "ORP Data.xlsx"
//
//It's output is a file that can be used to generate new ids 
//for the two plan datasets appended together.  (See end of file below
//for details."
//////////////////////////////////////////////////////


//////////////////////////////////////////////////////
//Create a list of 403b account with identifying info
//////////////////////////////////////////////////////

clear
import excel "$input\PlanData.xlsx", sheet("Sheet1") firstrow clear

//Collapse on the identifying variables
gen t = 0
collapse t, by( ScrubbedID StatusinFidelity AgeasofNov2018 Gender MaritialStatus RoundedSalary AcaMCFlag HireDate TerminationDate)

//Drop entries with conflicting idetifiers 
duplicates drop ScrubbedID, force

//exclude medical center employees
drop if AcaMCFlag == "MC" // Academic vs. Medical Center plan; we drop the doctors unlike before (Zach's code)
drop t

gen Age = AgeasofNov2018 
rename MaritialStatus MaritalStatus

//standardize missing values
replace HireDate = 0 if missing(HireDate)
replace Gender = "NA" if missing(Gender)
replace Gender = "NA" if Gender == "0"
replace MaritalStatus = "NA" if missing(MaritalStatus)
replace MaritalStatus = "NA" if MaritalStatus == "0"
replace RoundedSalary = 0 if missing(RoundedSalary)
replace AcaMCFlag = "NA" if missing(AcaMCFlag)
replace AcaMCFlag = "NA" if AcaMCFlag == "0"


//We want some variables seperately named to test matches
gen Salary_403b = RoundedSalary
gen Gender_403b = Gender
gen MaritalStatus_403b  =MaritalStatus
gen TerminationDate_403b  =TerminationDate
gen Status_ORP = StatusinFidelity 
gen Status = StatusinFidelity

//drop if we don't know hire date
drop if HireDate == mdy(1,1,1960)

//This is a list of all relevant 403b account holders 
save "$temp\403b_accounts.dta", replace
use "$temp\403b_accounts.dta", replace // 10,661

//////////////////////////////////////////////////////
//Create a list of ORP account with identifying info
//////////////////////////////////////////////////////

clear
import excel "$input\ORP Data.xlsx", sheet("Sheet1") firstrow clear

//Collapse on the identifying variables
gen t = 0
collapse t, by( ScrubbedSSN Status CalculatedAgeDC Gender MaritalStatus RoundedSalary ACAMCFlag HireDate TerminationDate)

//make names consistent
rename  ACAMCFlag AcaMCFlag

//standardize missing values
replace HireDate = 0 if missing(HireDate)
replace Gender = "NA" if missing(Gender)
replace MaritalStatus = "NA" if missing(MaritalStatus)
replace MaritalStatus = "NA" if MaritalStatus == "0"
replace RoundedSalary = 0 if missing(RoundedSalary)
replace AcaMCFlag = "NA" if missing(AcaMCFlag)
replace AcaMCFlag = "ACA" if AcaMCFlag == "Aca"

//We want some variables seperately named to test matches
gen  ORPSalary = RoundedSalary 
gen Age = CalculatedAgeDC 
gen Gender_ORP = Gender
gen MaritalStatus_ORP  =MaritalStatus
gen TerminationDate_ORP  =TerminationDate
gen Status_ORP = Status 

//exclude medical center employees
drop if AcaMCFlag == "MC"
drop t

//drop if we don't know hire date
drop if HireDate == mdy(1,1,1960)

//This is a list of all relevant ORP account holders 
save "$temp\ORP_accounts.dta", replace
use "$temp\ORP_accounts.dta", replace // 3,886


//////////////////////////////////////////////////////
//Generate a list of overlapping accounts 
//////////////////////////////////////////////////////

use "$temp\ORP_accounts.dta", replace

//join on the subset of ID variables that are reliable (not salary and age)
joinby HireDate Status Gender TerminationDate AcaMCFlag using "$temp\403b_accounts.dta", unm(both)
tab _merge
drop _merge

//check for approximate match on salary and age (which could be off a bit)
gen age_diff = abs(CalculatedAgeDC - AgeasofNov2018)
gen salary_diff  =  abs(Salary_403b-ORPSalary)

gen good_match = 0
replace good_match = 1 if age_diff < 2  & salary_diff < 10000
keep if good_match == 1

duplicates tag ScrubbedID, generate(dupID)
duplicates tag ScrubbedSSN, generate(dupSSN)

//save pairs with dups information
save "$temp\temp.dta", replace

drop if dupSSN > 0
drop if dupID > 0

//list of unique pairs
save "$temp\overlapping_accounts.dta", replace
use "$temp\overlapping_accounts.dta", replace // 1,814

//////////////////////////////////////////////////////
//Generate a list of ambiguous matches we will exclude
//////////////////////////////////////////////////////

use "$temp\temp.dta", replace

keep if dupSSN > 0 | dupID > 0 
gen dup_ind = 1 
keep  ScrubbedSSN dup_ind
duplicates drop 

//list of non-unique matches we will drop
save "$temp\drop_these_ambiguous_SSNs.dta", replace

use "$temp\temp.dta", replace
keep if dupSSN > 0 | dupID > 0 
gen dup_ind = 1 
keep  ScrubbedID dup_ind
duplicates drop

//list of non-unique matches we will drop
save "$temp\drop_these_ambiguous_ids.dta", replace

//////////////////////////////////////////////////////
//Construct the new id crosswalk 
//////////////////////////////////////////////////////

//start with overlapping accounts  
use "$temp\overlapping_accounts.dta", replace

//merge in all the 43b accounts
joinby ScrubbedID using "$temp\403b_accounts.dta", unm(both)
tab _merge
drop _merge 

//merge in all the ORP accounts
joinby ScrubbedSSN using "$temp\ORP_accounts.dta", unm(both)
tab _merge
drop _merge 

//drop the ambiguous accounts that might be in both plans
joinby ScrubbedSSN using "$temp\drop_these_ambiguous_SSNs.dta", unm(both)
tab _merge
drop _merge 

joinby ScrubbedID using "$temp\drop_these_ambiguous_ids.dta", unm(both)
tab _merge
drop _merge 

drop if dup_ind == 1

gen id = _n

keep id Scrubbed*

save "$temp\master_id_crosswalk.dta", replace 

preserve 

drop ScrubbedID
save "$temp\SSN_ID_cross.dta", replace

restore 

preserve 

drop ScrubbedSSN
save "$temp\SID_ID_cross.dta", replace

restore 

//////////////////////////////////////////////////////
//Output is a file that maps the new "id" field to 
//existing ScrubbedID and ScrubbedSSN.
//
//To use it, start with the ORP and 403(b) position lists
//(the original data XLSX above) with the fields standardazed
//and append them together.  Make sure that only the ORP entries have 
//ScrubbedSSNs and only the 403b entries have Scrubbed ids when you
//append the data. The appended datasets will be the list of every position in 
//both plans with the identifier from the original data and the other iden
//tifier left missing.
//
//Starting from this dataset, join on the master_id_crosswalk.dta twice
//first by ScrubbedID, then by ScrubbedSSN.  This will 
//assign a new ID to every position in both datasets, and that ID
//will be common to both plans.  
//
//Then Collapse the data on id, fund_id, date, and sum the mkt_values
//so that an investor with positions in the same funds in both accounts
//gets a single position. (Check after this that there are no observations 
//with duplicate id, date, and fund.)
//
//Once this is done, you should be able to rename "id" to "ScrubbedID"
//and run the code as before.  
//////////////////////////////////////////////////////


//////////////////////////////////////////////////////
// Join crosswalk to ORP and Plan Data  
////////////////////////////////////////////////////// 

import excel "$input\ORP Data.xlsx", sheet("Sheet1") firstrow clear

rename CalculatedAgeDC AgeasofNov2018
rename Status StatusinFidelity
rename ACAMCFlag AcaMCFlag
rename MaritalStatus MaritialStatus

// drop if AcaMCFlag == "MC"

gen orp = 1 

by ScrubbedSSN, sort: gen nvals = _n == 1 
egen unique_ssn = sum(nvals) // 4217 

preserve 

import excel "$input\PlanData.xlsx", sheet("Sheet1") firstrow clear
duplicates drop
gen b403 = 1 
save "$temp\plan_data.dta", replace

restore 

append using "$temp\plan_data.dta"

tab orp ScrubbedID
tab b403 ScrubbedSSN


drop orp b403 // no obs. which means only the ORP entries have ScrubbedSSNs and only the 403b entries have Scrubbed ids

//// Individually merge id crosswalk onto ORP and Plan Datasets and then append 

// only joinby ORP

use "$temp\appended_orp_plan.dta", replace

drop FundsHeld

keep if ScrubbedID ~= . // keeps only 403b obs.

joinby ScrubbedID using "$temp\SID_ID_cross.dta" //, unmatched(master)

/*
by id, sort: gen nvals = _n == 1 
egen unique_id = sum(nvals) // 10,661 
*/

save "$temp\sid_id_joined.dta", replace // cross-walk between 403b users (ScrubbedID) and new "id" | 10,611 SSIDs	

// only joinby 403b

use "$temp\appended_orp_plan.dta", replace

drop FundsHeld

keep if ScrubbedSSN ~= .

joinby ScrubbedSSN using "$temp\SSN_ID_cross.dta" //, unmatched(master)

/*
by id, sort: gen nvals = _n == 1 
egen unique_id = sum(nvals) // 3,616 
*/

save "$temp\ssn_id_joined.dta", replace // cross-walk between ORP users (ScrubbedSSN) and new "id" | 10,611 SSIDs	
 
// append 

append using "$temp\sid_id_joined.dta"

save "$temp\id_ssn_sid_joined.dta", replace 

//// Collapse 
 
use "$temp\id_ssn_sid_joined.dta", replace 

sort id Fund CalendarDay

collapse MarketValue (firstnm) HireDate AcaMCFlag FundType Gender MaritialStatus RoundedSalary TerminationDate AgeasofNov2018, by(id Fund CalendarDay)

duplicates drop	// zero obs. 

//drop Scrubbed*

rename id ScrubbedID

save "$temp\orp_plan_merged.dta", replace


{ // compute CAPM betas

//format the Rf rate from French's website
import excel "$input/F-F_Research_Data_Factors.xlsx", sheet("F-F_Research_Data_Factors") firstrow clear
replace RF = RF/100
tostring Date, replace
replace Date  = Date + "01"
gen date = date(Date, "YMD")
format date %td
gen month = mofd(date)
format month %tm
gen mktrf = MktRF/100
gen rf = RF/100
keep month mktrf rf
save "$input/rf_rate.dta", replace

use "$temp/fund_returns.dta", replace
joinby month using "$temp/rf_rate.dta"

bys crsp_fundno caldt: gen dup = cond(_N==1,0,_n)
tab dup
drop if dup > 1

isid crsp_fundno caldt

replace mret = mret - rf

asreg  mret mktrf, noc min(36) rmse by(crsp_fundno) window(month 60)

rename _b_mktrf beta

keep crsp_fundno caldt beta

save "$temp/fund_betas.dta", replace
}

/*
Changes in plan participation after streamlining
ZRS

*/



// load data 
// use "$temp/collapse2_combined", clear

use "$temp/individual_ports.dta", clear

// keep one observation per person-date
bys ScrubbedID date: keep if _n == 1

// flag employees that are present in each year
bys ScrubbedID: egen present_2012 = max(date == 624)
bys ScrubbedID: egen present_2013 = max(date == 636)
bys ScrubbedID: egen present_2014 = max(date == 648)
bys ScrubbedID: egen present_2015 = max(date == 660)
bys ScrubbedID: egen present_2016 = max(date == 672)
bys ScrubbedID: egen present_2017 = max(date == 684)
bys ScrubbedID: egen present_2018 = max(date == 696)
summ present_*

// flag which year employees leave the plan
forvalues i = 2012/2017 {
	local j = `i' + 1 
	gen left_after_`i' = present_`j' == 0 if present_`i' == 1 
}
summ left_after_*

// flag employees that are 60+
replace date = 1960+date/12
gen age = AgeasofNov2018 - (2018 - date)
assert !missing(age)
gen under60 = age < 60

// determine total number of employees at each date
preserve
	gen counter = 1
	collapse (sum) counter, by(date)
	la var counter "Total participants"
	twoway 	(lfitci counter date) ///
	(scatter counter date) ///
	, ylab(,nogrid) xline(684)
	graph export "$output/74 - Participants by date.pdf", replace

restore

// determine total number of employees that were present in 2016 that were also present at each date
// (would need to do this for each year to have a proper comparison)
preserve
	keep if present_2016 == 1
	gen counter = 1
	collapse (sum) counter, by(date)
	la var counter "Total participants"
	scatter counter date, ylab(,nogrid) xline(684)
restore

// graph proportion present and proportion that leave 
preserve
	collapse (mean) present_* left_after_*
	gen i = 1
	reshape long present_ left_after_, i(i) j(date)
	drop i
	la var present_ `""Percent of all eventual" "participants present in year""'
	la var left_after_ `""Percent of those present" "in year that left plan after year""'	
	twoway 	(lfitci left_after date) ///
	(scatter left_after_ date) /// //(scatter present_ date, yaxis(2) ytitle(,size(vsmall))) ///
	, ylab(,nogrid) xline(684) ytitle(,size(vsmall)) legend(order(3) size(small))
	graph export "$output/73.1 - Proportion Leaving Plan by Date.pdf", replace

restore

// graph proportion present and proportion that leave, by 59 and under vs 60 and over
preserve
	collapse (mean) present_* left_after_*, by(under60)
	reshape long present_ left_after_, i(under60) j(date)
	la var present_ `""Share of all eventual" "participants present in year""'
	la var left_after_ `""Share of those present" "in year that left plan after year""'	

	twoway 	(lfitci left_after_ date if under60 == 1, color(%30)) ///
	(lfitci left_after_ date if under60 == 0, color(%30)) ///	
	(scatter left_after_ date if under60 == 1) ///
	(scatter left_after_ date if under60 == 0) ///
	, ylab(,nogrid) xline(684) ytitle(,size(vsmall)) ///
	legend(label(5 "Under 60") label(6 "60 and up") size(small) order(5 6)) 
	graph export "$output/73.2 - Proportion Leaving Plan by Date and Age.pdf", replace

restore






// comparing expected returns to realized returns to see if those that stayed changed contributions
// use "$temp/full_data.dta", clear
use "$temp/joined_fund_data", replace
gen ret = port_weight*mret
gen year = yofd(caldt)
gen year2 = 1960 + date/12
keep if year == year2 
drop year*
collapse (sum) ret, by(ScrubbedID date caldt)

bys ScrubbedID date: gen annualized_return = 1 + ret if _n == 1
by ScrubbedID date: replace annualized_return = (1 + ret) * annualized_return[_n-1] if _n != 1
by ScrubbedID date: replace annualized_return = annualized_return[_N]
drop ret caldt
by ScrubbedID date: keep if _n == 1
replace date = date + 12
rename annualized_return previous_year_annualized_return

merge 1:1 ScrubbedID date using "$temp/collapse2.dta"
keep if _m == 3

bys ScrubbedID: gen expected_assets = total_assets[_n-1] * previous_year_annualized_return
gen contributions = total_assets - expected_assets
gen diff_assets = (total_assets - expected_assets) / expected_assets 

gen lower_value_flag = diff_asset < -.05

replace date = 1960+date/12
gen age = AgeasofNov2018 - (2018 - date)
assert !missing(age)
gen under60 = age < 60

binscatter lower_value_flag year ///
, by(under60) ylab(,nogrid) linetype(none) ///
legend(label(1 "60 and over") label(2 "Under 60")) ///
ytitle(Share with assets 5%+ lower than expected)
graph export "$output/72 - Lower than expected assets.pdf", replace

binscatter contributions year ///
, by(under60) ylab(,nogrid) linetype(none) ///
legend(label(1 "60 and over") label(2 "Under 60")) ytitle("Contributions/withdrawals")
graph export "$output/75 - Contributions by age and year.pdf", replace


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
/*
// quick calculation on exp ratios
use "$temp/collapse2_combined.dta", clear
keep if date == 672
gen exp50 = cond(exp_ratio > 0.5, 1, 0)
gen exp75 = cond(exp_ratio > 0.75, 1, 0)
gen exp100 = cond(exp_ratio > 1, 1, 0)
sum exp50 exp75 exp100
*/
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


use "$temp/collapse2_combined.dta", clear

gen RMSD = sqrt(_rmse)

keep if inlist(date,672,684,696,991)
// bys ScrubbedID: assert _N == 4 | (_N == 3 & present_2018 == 0)

summ _b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse
summ _b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX _rmse if date == 672

{ // histograms of RMSD
twoway (hist RMSD if date == 672, start(0) w(.01) color("$color_p3%30") percent) ///
(hist RMSD if date == 684, start(0) w(.01) color("$color_p2%30") percent) ///
, legend(label(1 "Pre-Reform") label(2 "Post-Reform")) xtitle("Idiosyncratic Risk (RMSD)") ///
ylab(,nogrid) title("Idiosyncratic Risk Pre- And Post-Reform", pos(12) size(medium))
graph export "$output/50.1 - Idiosyncratic Risk Histogram - Pre-Post.png", replace

twoway (hist RMSD if date == 672 & any_guardrail == 1, start(0) w(.01) color("$color_p3%30") percent) ///
(hist RMSD if date == 672 & any_guardrail == 0, start(0) w(.01) color("$color_p2%30") percent) ///
, legend(label(1 "Would Be Affected") label(2 "Would Not Be Affected")) xtitle("Idiosyncratic Risk (RMSD)") ///
ylab(,nogrid) title("Pre-Reform Idiosyncratic Risk For Individuals" "That Would Be Affected By Any Guardrail", pos(12) size(medium))
graph export "$output/50.2 - Idiosyncratic Risk Histogram - All Guardrails.png", replace

twoway (hist RMSD if date == 672 & guardrail_not_intl == 1, start(0) w(.01) color("$color_p3%30") percent) ///
(hist RMSD if date == 672 & guardrail_not_intl == 0, start(0) w(.01) color("$color_p2%30") percent) ///
, legend(label(1 "Overweighted") label(2 "Not Overweighted")) xtitle("Idiosyncratic Risk (RMSD)") ///
ylab(,nogrid) title("Pre-Reform Idiosyncratic Risk For Individuals" "That Would Be Affected By Any Non-International Guardrail", pos(12) size(medium))
graph export "$output/50.3 - Idiosyncratic Risk Histogram - Non Intl Guardrails.png", replace

twoway (hist RMSD if date == 672 & guardrail_div == 1, start(0) w(.01) color("$color_p3%30") percent) ///
(hist RMSD if date == 672 & guardrail_div == 0, start(0) w(.01) color("$color_p2%30") percent) ///
, legend(label(1 "Would Be Affected") label(2 "Would Not Be Affected")) xtitle("Idiosyncratic Risk (RMSD)") ///
ylab(,nogrid) title("Pre-Reform Idiosyncratic Risk For Individuals" "That Would Be Affected By Any Diversification Guardrail", pos(12) size(medium))
graph export "$output/50.4 - Idiosyncratic Risk Histogram - Diversification Guardrails.png", replace

twoway (hist RMSD if date == 672, start(0) w(.01) color(ebblue%30) percent) ///
, legend(label(1 "Pre-Reform") label(2 "Post-Reform")) xtitle("Idiosyncratic Risk (RMSD)") ///
ylab(,nogrid) title("Pre-Reform Idiosyncratic Risk", pos(12) size(medium))
graph export "$output/50.6 - Idiosyncratic Risk Histogram - Pre-Reform.png", replace

twoway (hist RMSD if date == 672 & one_sector_overweight == 1, start(0) w(.01) color("$color_p3%30") percent) ///
(hist RMSD if date == 672 & one_sector_overweight == 0, start(0) w(.01) color("$color_p2%30") percent) ///
, legend(label(1 "Overweighted") label(2 "Not Overweighted")) xtitle("Idiosyncratic Risk (RMSD)") ///
ylab(,nogrid) title("Pre-Reform Idiosyncratic Risk For Individuals" "That Would Be Affected By Sector Guardrail", pos(12) size(medium))
graph export "$output/50.7 - Idiosyncratic Risk Histogram - Sector Guardrails.png", replace


}

// factor table
preserve

	local balance_vars = "_b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX RMSD"
	local n_vars : word count `balance_vars'
	local letters = "B C D E F G H I J"
	
	keep ScrubbedID date present_2018 _b_* RMSD 
	reshape wide _b_* RMSD, i(ScrubbedID) j(date)
	


	foreach var in `balance_vars'{
		di "`var'"
		gen `var'_prepost17 = `var'684 - `var'672
		gen `var'_prepost18 = `var'696 - `var'672		
		gen `var'_preguardrails = `var'991 - `var'672
	}
	
	gen RMSD_decrease_prepost = (RMSD_prepost17 < 0)
	gen RMSD_decrease_preguardrails = (RMSD_preguardrails < 0)


	putexcel set "$output/35 - Factor Differences", sheet("Factor Differences Delta",replace) modify
	putexcel A2 = ("Pre-Reform Mean")
	putexcel A4 = ("Joint Non-International Guardrails Minus Pre-Reform Mean") 
	putexcel A5 = ("Joint Non-International Guardrails Minus Pre-Reform P-Value") 
	putexcel A7 = ("Post-Reform (2017) Minus Pre-Reform Mean") 
	putexcel A8 = ("Post-Reform (2017) Minus Pre-Reform P-Value")
	putexcel A10 = ("Post-Reform (2018) Minus Pre-Reform Mean") 
	putexcel A11 = ("Post-Reform (2018) Minus Pre-Reform P-Value")
	putexcel B1 = ("Beta - EFA"), hcenter 
	putexcel C1 = ("Beta - IWD"), hcenter 
	putexcel D1 = ("Beta - IWF"), hcenter 
	putexcel E1 = ("Beta - IWN"), hcenter 
	putexcel F1 = ("Beta - IWO"), hcenter 
	putexcel G1 = ("Beta - VBISX"), hcenter 
	putexcel H1 = ("Beta - VBLTX"), hcenter 
	putexcel I1 = ("Beta - VGSLX"), hcenter 
	putexcel J1 = ("RMSD"), hcenter 


	forvalues i = 1/`n_vars' {
		local var : word `i' of `balance_vars'
		local letter : word `i' of `letters'
		
		di "Test delta on `var'"
		ttest `var'_prepost17 == 0
		local pval = r(p)
		local mean_prepost = r(mu_1)
		putexcel `letter'7 = `mean_prepost', hcenter nformat(0.000)
		putexcel `letter'8 = `pval', hcenter nformat(0.000)
		
		ttest `var'_prepost18 == 0 if present_2018 == 1
		local pval = r(p)
		local mean_prepost2 = r(mu_1)
		putexcel `letter'10 = `mean_prepost2', hcenter nformat(0.000)
		putexcel `letter'11 = `pval', hcenter nformat(0.000)
		
		ttest `var'_preguardrails == 0
		local pval = r(p)
		local mean_guardrailspre = r(mu_1)
		putexcel `letter'4 = `mean_guardrailspre', hcenter nformat(0.000) 
		putexcel `letter'5 = `pval', hcenter nformat(0.000)
		
		summ `var'672
		local pre_mean = r(mean)
		putexcel `letter'2 = `pre_mean', hcenter nformat(0.000)
	}

	ttest RMSD_decrease_prepost == .5
	local signtest_prepost_mean = round(r(mu_1)*100,.1)
	local signtest_prepost_p = round(r(p), .001)
	di `signtest_prepost_mean'
	di `signtest_prepost_p'
	
	ttest RMSD_decrease_preguardrails == .5 if RMSD_preguardrails != 0
	local signtest_preguardrails_mean = round(r(mu_1)*100,.1)
	local signtest_preguardrails_p = round(r(p), .001)
	di `signtest_preguardrails_mean'
	di `signtest_preguardrails_p'
	
	putexcel A14 = ("`signtest_prepost_mean' percent of investors experienced a decrease in idiosyncratic risk between pre- and 2017 post-reform (p = `signtest_prepost_p')."), nformat(0.000)
	putexcel A15 = ("`signtest_preguardrails_mean' percent of investors affected by guardrailing experienced a decrease in idiosyncratic risk between pre-reform and guardrails (p = `signtest_preguardrails_p')."), nformat(0.000)
	putexcel A16 = ("Post-reform 2018 values only include individuals that were observed in each of 2016, 2017, and 2018.")
	putexcel close

restore

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

*** Contracts Student Question -- Sharpe Ratios *****

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

la define plan_defaulted17 0 "Streamlined, affirmative choice" ///
	1 "Streamlined, plan-defaulted" ///
	2 "Non-streamlined"

gen temp = (date == 696)
bys ScrubbedID: egen present_2018 = max(temp)
drop temp

//keep if date == 672 & present_2018 == 1

// filter to one observation per person
//bys ScrubbedID: keep if _n == 1

gen affirmative17 = (plan_defaulted17 == 0)
gen defaulted17 = (plan_defaulted17 == 1)
gen non17 = (plan_defaulted17 == 2)

preserve 

use "$temp/collapse2_combined", clear
drop if year == .
keep Scr year sharpe sharpe_fiveyear
keep if sharpe != .

save "$temp/scr_sharpe", replace

restore 

gen year = 2016 if date == 672
replace year = 2017 if date == 684
replace year = 2018 if date == 696

preserve 

keep Scr affirmative17 defaulted17 non17
duplicates drop Scr, force
save "$temp/id_affirm_crosswalk", replace

restore 	

/*
merge m:1 ScrubbedID year using "$temp/scr_sharpe"

egen sharpe_pre_affirm = mean(sharpe) if affirmative == 1
egen sharpe_pre_default = mean(sharpe) if defaulted == 1
egen sharpe_pre_non = mean(sharpe) if non == 1

reg sharpe affirm default if year == 2016
reg sharpe affirm default if year == 2017 

gen treat = cond(affirmative == 1 | defaulted == 1, 1, 0)
gen post = cond(year == 2017, 1, 0)
gen did = treat * post

reg sharpe did

*/
preserve 

use "$temp/testing_pd2", replace

collapse (mean) ret exp_ratio sharpe sharpe_fiveyear, by(Scr year)
drop if sharpe == .

save "$temp/testing_pd3", replace

restore 

sort Scr date

merge m:1 ScrubbedID year using "$temp/testing_pd3"

la var affirmative "Streamlined, affirmative choice"
la var defaulted "Streamlined, plan-defaulted"
la var non "Non-streamlined"
la var date "Date"

gen treat = cond(affirmative == 1 | defaulted == 1, 1, 0)
gen post = cond(year == 2017, 1, 0)
gen did = treat * post

reg sharpe did i.year
reg ret did i.year
reg exp_ratio did i.year

gen treat2 = cond(affirmative == 1, 1, 0)
gen did2 = treat2 * post

gen treat3 = cond(default == 1, 1, 0)
gen did3 = treat3 * post

reg sharpe did2 did3
test did2 = did3

reg ret did2 did3
test did2 = did3

reg exp_ratio did2 did3
test did2 = did3 // significant--default had lower expense ratios 

*** Heterogeneity in Guardrail Violation ***

use "$temp/collapse2.dta", clear

foreach var of varlist goldbug one_sector_overweight total_intl_share_under total_exp_over total_eq_violation any_guardrail guardrail_not_intl guardrail_div {
    
	binscatter `var' total_assets if total_assets < 200000
	graph export "$output/`var'_binscatter.png", replace

	
}

foreach var of varlist goldbug one_sector_overweight total_intl_share_under total_exp_over total_eq_violation any_guardrail guardrail_not_intl guardrail_div {
    
	reg `var' total_assets 
	
}

reg any_guardrail total_assets

binscatter any_guardrail total_assets
binscatter any_guardrail total_assets
binscatter any_guardrail total_assets if total_assets < 2000000
binscatter any_guardrail total_assets if total_assets < 200000
binscatter guardrail_not_intl total_assets
binscatter guardrail_div total_assets
























































