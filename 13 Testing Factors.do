
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





