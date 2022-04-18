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
/*
{ // original graphs 
// date 672 is Jan 2016 (last available data before reforms went into effect. Dates are in months.)
twoway (scatter return_used var_used if date == 672, msize(vtiny) msymbol(o) mcolor("$color_p2")) ///
(scatter return_used var_used if date == 684, mcolor("$color_p3") msize(vtiny) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(medium)   msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p3") msize(medium)   msymbol(o)), ///
legend(label(3 "Pre-Redesign") label(4 "Post-Redesign") order(3 4)) ylabel(,nogrid) ytitle(Return) xtitle(Variance)
graph export "$output/1 - Return Variance Comparison.png", replace

// basic returns-variance for pre-post comparison
twoway (scatter return_used var_used if date == 672 & var_used < .03, msize(tiny) msymbol(o) mcolor("$color_p2")) ///
(scatter return_used var_used if date == 684 & var_used < .03, mcolor("$color_p3") msize(tiny) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(medium) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p3") msize(medium) msymbol(o)), ///
legend(label(3 "Pre-Redesign") label(4 "Post-Redesign") order(3 4)) note("Limited to observations with variance < 0.03", size(tiny)) ylabel(,nogrid) ytitle(Return) xtitle(Variance)
graph export "$output/2 - Return Variance Pre-Post Comparison Rescale.png", replace

// basic returns-variance for post only
twoway (scatter return_used var_used if date == 684 & var_used < .03, mcolor("$color_p2") msize(tiny) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(medium) msymbol(o)), ///
legend(label(2 "Post-Redesign") order(2)) note("Limited to observations with variance < 0.03", size(tiny)) ylabel(,nogrid) ytitle(Return) xtitle(Variance)
graph export "$output/2.0 - Return Variance Only Post Rescale.png", replace

// basic returns-variance for pre vs non-intl guardrails comparison
twoway (scatter return_used var_used if date == 672 & var_used < .04, msize(tiny) msymbol(o) mcolor("$color_p2")) ///
(scatter return_used var_used if date == 991 & var_used < .04, mcolor("$color_p3%40") msize(tiny) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(medium) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p3") msize(medium) msymbol(o)), ///
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

*/ 

use "$temp/collapse2_combined", clear
gen graph_helper = .

// basic returns-variance for pre only
twoway (scatter return_used var_used if date == 672 & var_used < .04 & smart == 0, mcolor("$color_p2") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 672 & var_used < .04 & smart == 1, mcolor("$color_p3*1.2") msize(vsmall) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p3*1.2") msize(medium) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(medium) msymbol(o)), ///
legend(label(3 "TDFs") label(4 "Other Portfolios") order(3 4)) ///
note("Limited to observations with variance < 0.04", size(tiny)) ylabel(,nogrid) ytitle(Ex-Post Return) xtitle(Ex-Post Variance)
graph export "$output/2.4 - Return Variance Only Pre Rescale.png", replace
graph save "$temp/2.4 - Return Variance Only Pre Rescale.gph", replace


// basic returns-variance for pre only
twoway (scatter ante_ret ante_var if date == 672 & ante_var < .04 & smart == 0, mcolor("$color_p2") msize(tiny) msymbol(o)) ///
(scatter ante_ret ante_var if date == 672 & ante_var < .04 & smart == 1, mcolor("$color_p3*1.2") msize(vsmall) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p3*1.2") msize(medium) msymbol(o)) ///
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
/*
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







