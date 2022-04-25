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


use "C:\Users\EI87\Dropbox (YLS)\Retirement Menu Design\code\STATA -- ZS\Temp\investor_mean_var_cleaning_step_one.dta", clear

collapse ret var, by(Scr)


preserve

use "$temp\investor_mean_var_cleaning_step_one.dta", replace

collapse ret var, by(Scr)

save "$temp\number_check.dta", replace

restore

append using "$temp\number_check.dta"
