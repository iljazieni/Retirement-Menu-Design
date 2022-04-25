*** Heterogeneity in Guardrail Violation ***

use "$temp/collapse2_combined.dta", clear

*** Portfolio Size and Guardrail

foreach var of varlist goldbug one_sector_overweight total_intl_share_under total_exp_over total_eq_violation any_guardrail guardrail_not_intl guardrail_div {

	binscatter `var' total_assets if total_assets < 200000
//	graph export "$output/`var'_binscatter.png", replace


}

foreach var of varlist goldbug one_sector_overweight total_intl_share_under total_exp_over total_eq_violation any_guardrail guardrail_not_intl guardrail_div {

	reg `var' total_assets

}

reg any_guardrail total_assets
/*
binscatter any_guardrail total_assets
binscatter any_guardrail total_assets
binscatter any_guardrail total_assets if total_assets < 2000000
binscatter any_guardrail total_assets if total_assets < 200000
binscatter guardrail_not_intl total_assets
binscatter guardrail_div total_assets
*/
*** Demographics (1) pre-reform; (2) same sample as before

keep if date == 672

gen male = cond(Gender == "M", 1, 0)

replace RoundedSalary = . if RoundedSalary == 0

label var male "Male"
label var AgeasofNov2018 "Age"
label var total_assets "Total Assets"
label var RoundedSalary "Salary"

ssc install outreg2

foreach var of varlist any_guardrail one_sector_overweight total_intl_share_under total_intl_share_under total_exp_over total_eq_violation guardrail_not_intl guardrail_div _rmse {

	reg `var' male AgeasofNov2018 total_assets RoundedSalary
	outreg2 using "$output/regressionresults2_salary_missing.xlsx", excel label // EI added Path

}

reg share_tdf17 AgeasofNov2018
reg total_tdf_share AgeasofNov2018
reg total_tdf_share AgeasofNov2018 if AgeasofNov2018 !=.
// expense violation (5);  (6); remove 8.  (6)



foreach var of varlist any_guardrail _rmse sharpe sharpe_fiveyear {

	reg `var' male AgeasofNov2018 total_assets RoundedSalary

}

reg any_guardrail male
reg _rmse male
reg sharpe male
reg sharpe_fiveyear male

// same sample as the sharpe histograms
// 10% violated non-intl guardrails
// outcomes: risk, all the guardrail types


// 8 different specifications:
