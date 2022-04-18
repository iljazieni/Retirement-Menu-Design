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

duplicates drop Scr, force // 12,442

}
