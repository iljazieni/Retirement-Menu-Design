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


