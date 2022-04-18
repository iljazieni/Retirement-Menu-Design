


foreach file in cleaning_step_one guard_intrm_onlytdf_joint_nonintl guard_intrm_onlytdf_joint_all guard_intrm_onlytdf_intl guard_intrm_onlytdf_equitiesover guard_intrm_onlytdf_equitiesunder guard_intrm_onlytdf_sector guard_intrm_onlytdf_expenseratio {
di "`var'"

// load portfolio data
use "$temp/`file'.dta", clear
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

// EFA is international (excludes US and Canada)
// calculate betas with other funds
bysort date ScrubbedID: asreg  mret EFA IWD IWF IWN IWO VBISX VBLTX VGSLX, noc rmse
bys ScrubbedID date: keep if _n == 1

keep ScrubbedID date beta _rmse _R2 _b_* date_count

save "$temp/portfolio_betas_`file'", replace
}



