*** Idiosyncratic Risk Delta *** 

{ // RMSE for guardrails
use "$temp/collapse2_combined.dta", clear

keep if inlist(date,672)

putexcel set "$output/80 - Guardrails RMSE Means.xlsx", replace
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


*** Sharpe Risk Delta *** 

{ // RMSE for guardrails
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

putexcel close

}

/*
 any diversification: intl + sector 	
 any guardrail: anything  
 any non-intl: everything non-intl. 
 any exp ratio: is enough 
Diversification Error: Single Sector Fund Overweighted
Diversification Error: International Equities Underweighted (Less Than 20% Equities)
Expense Error: Average Expense Ratio Over 75 Basis Points
Exposure Error: Equities Share Less Than Half or More Than Double Benchmark TDF
Any Diversification Error
Any Non-International Error
Any Error
 
 */

 