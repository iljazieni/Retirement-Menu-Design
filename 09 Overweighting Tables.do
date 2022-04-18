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

use "$temp/collapse2_combined.dta", clear
gen graph_helper = . 

summ goldbug if date == 672

keep if inlist(date,672,684)

twoway (scatter return_used var_used if var_used < .03 & goldbug16 == 0, mcolor("$color_p2") msize(vtiny) msymbol(o) by(date)) ///
(scatter return_used var_used if var_used < .03 & goldbug16 == 1, mfcolor(gold) mlcolor(gs0) msize(vsmall) msymbol(D) by(date, note("Only portfolios with variance < .03 are shown." , size(tiny)) ///
title("Goldbug Returns Pre- and Post-Reform", span size(medsmall) pos(12)))) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(small) msymbol(o)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "Other portfolios") ///
label(2 "Goldbugs (>20% of" "2016 portfolio in gold)")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
subtitle(, fcolor(white) lcol(white))
graph export "$output/26 - Goldbug Outcomes.png", replace 


twoway (scatter return_used var_used if var_used < .03 & goldbug16 == 0 & date == 672, mcolor("$color_p2") msize(vtiny) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & goldbug16 == 1 & date == 672, mfcolor(gold) mlcolor(gs0) msize(vsmall) msymbol(D)) ///
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
(scatter return_used var_used if var_used < .03 & goldbug16 == 1, mfcolor(gold) mlcolor(gs0) msize(vsmall) msymbol(D) by(date, note("Only portfolios with variance < .03 are shown." , size(tiny)) ///
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
(scatter return_used var_used if var_used < .03 & goldbug16 == 1 & date == 672, mfcolor(gold) mlcolor(gs0) msize(vsmall) msymbol(D)) ///
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
(scatter return_used var_used if var_used < .03 & goldbug16 == 1, mfcolor(gold) mlcolor(gs0) msize(vsmall) msymbol(D) by(date, note("Only portfolios with variance < .03 are shown." , size(tiny)) ///
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

twoway (pcarrow return_used672 var_used672 return_used684 var_used684, mcolor(gs0) lcolor(gold%50) lwidth(vthin) msize(small) msymbol(T)) ///
(scatter return_used672 var_used672, mcolor(gold) msize(small) msymbol(o)) ///
, title("Goldbug Returns With And Without Reforms", span size(medsmall) pos(12)) ///
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
subtitle(, fcolor(white) lcol(white)) legend(off)


graph export "$output/26.3 - Goldbug Outcomes Arrows.png", replace 






}

{ // one sector overweighted diversification guardrail graph
use "$temp/collapse2_combined.dta", clear
gen graph_helper = . 

keep if inlist(date,672)

twoway (scatter return_used var_used if var_used < .03 & one_sector_overweight == 0 & date == 672, mcolor("$color_p2") msize(vtiny) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & one_sector_overweight == 1 & date == 672, mfcolor("$color_p4*.5") mlcolor(gs0%20) msize(vsmall) msymbol(d)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(vsmall) msymbol(o)) ///
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
use "$temp/collapse2_combined.dta", clear
gen graph_helper = . 
set seed 758901
gen rand = runiformint(1,10)

keep if inlist(date,672)


twoway (scatter return_used var_used if var_used < .03 & total_intl_share_under == 1 & date == 672, mfcolor("$color_p4*.5") mlcolor(gs0%20) msize(tiny) msymbol(d)) ///
(scatter return_used var_used if var_used < .03 & total_intl_share_under == 0 & date == 672 & smart == 0, mcolor("$color_p2") msize(tiny) msymbol(o)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(vsmall) msymbol(o)) ///
(scatter return_used var_used if date == 672 & var_used < .5 & smart == 1, mcolor("$color_p3") msize(vsmall) msymbol(o)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "International Equities Not Underweighted Among Equities") ///
label(2 "International Equities Underweighted Among Equities")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
note("Only portfolios with variance < .03 are shown." ///
"TDFs highlighted in orange.", size(tiny)) ///
title("Highlighting International Equities Diversification Guardrail" "Returns Pre-Reform", span size(medsmall) pos(12))
graph export "$output/57 - international equities diversification guardrail scatterplot.png", replace 
graph save "$temp/57 - international equities diversification guardrail scatterplot.gph", replace 

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
use "$temp/collapse2_combined.dta", clear
gen graph_helper = . 

keep if inlist(date,672)

twoway (scatter return_used var_used if var_used < .03 & total_exp_over == 0 & date == 672, mcolor("$color_p2") msize(vtiny) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & total_exp_over == 1 & date == 672, mfcolor("$color_p4*.5") mlcolor(gs0%20) msize(vsmall) msymbol(d)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(vsmall) msymbol(o)) ///
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
use "$temp/collapse2_combined.dta", clear
gen graph_helper = . 

keep if inlist(date,672)

twoway (scatter return_used var_used if var_used < .03 & total_eq_violation == 0 & date == 672, mcolor("$color_p2") msize(vtiny) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & total_eq_violation == 1 & date == 672, mfcolor("$color_p4*.5") mlcolor(gs0%20) msize(vsmall) msymbol(d)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(vsmall) msymbol(o)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "Not Violating Equity Exposure Guardrail") ///
label(2 "Violating Equity Exposure Guardrail")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
note("Only portfolios with variance < .03 are shown.", size(tiny)) ///
title("Highlighting Exposure Guardrail" "Returns Pre-Reform", span size(medsmall) pos(12))
graph export "$output/55 - exposure guardrail scatterplot.png", replace 
graph save "$temp/55 - exposure guardrail scatterplot.gph", replace 

twoway (scatter return_used var_used if var_used < .03 & total_eq_over == 0 & date == 672, mcolor("$color_p2") msize(vtiny) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & total_eq_over == 1 & date == 672, mfcolor("$color_p4*.5") mlcolor(gs0%20) msize(vsmall) msymbol(d)) ///
(scatter graph_helper graph_helper, mcolor("$color_p2") msize(vsmall) msymbol(o)) ///
, legend(size(vsmall) order(2 3) ///
label(3 "Not Violating Maximum Equity Exposure Guardrail") ///
label(2 "Violating Maximum Equity Exposure Guardrail")) /// 
ylabel(,nogrid) ytitle(Return) xtitle(Variance) yline(0,lcolor(gs12) lwidth(thin) lpattern(shortdash)) ///
note("Only portfolios with variance < .03 are shown.", size(tiny)) ///
title("Highlighting Maximum Equity Exposure Guardrail" "Returns Pre-Reform", span size(medsmall) pos(12))
graph export "$output/55.1 - exposure upper bound guardrail scatterplot.png", replace 
graph save "$temp/55.1 - exposure upper bound guardrail scatterplot.gph", replace 

twoway (scatter return_used var_used if var_used < .03 & total_eq_under == 0 & date == 672, mcolor("$color_p2") msize(vtiny) msymbol(o)) ///
(scatter return_used var_used if var_used < .03 & total_eq_under == 1 & date == 672, mfcolor("$color_p4*.5") mlcolor(gs0%20) msize(vsmall) msymbol(d)) ///
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
use "$temp/individual_ports.dta", clear  
joinby Fund date using "$temp/fund_returns_series_crosswalk_post.dta" 

// check for duplicates
bys ScrubbedID CalendarDay AgeasofNov2018 Fund MarketValue Gender MaritialStatus RoundedSalary AcaMCFlag HireDate TerminationDate date crsp_fundno crsp_fundno_orig hand_match lipper_obj_cd series_length longest_series_length month RF _rmse _Nobs _R2 _adjR2 _b_EFA _b_IWD _b_IWF _b_IWN _b_IWO _b_VBISX _b_VBLTX _b_VGSLX sigma_hat_ido missing_data total_assets port_weight: gen dup = cond(_N==1,0,_n)
tab dup
drop if dup > 1
drop dup

// filter to pre-reform
keep if date == 672

// filter to ScrubbedIDs in cleaned data
cap drop _m
merge m:1 ScrubbedID date using "$temp/collapse2.dta"
keep if _m == 3

// filter to necessary variables
keep ScrubbedID date Fund port_weight


// fill out so we have equal number of observations for all funds
encode Fund, gen(fund_code)
gen double id = ScrubbedID + date/1000
tsset id fund_code
tsfill, full
tostring id, force replace
drop ScrubbedID date
gen ScrubbedID = substr(id,1,strpos(id,".")-1)
gen date = substr(id,strpos(id,".")+1,3)
destring ScrubbedID date, replace
order ScrubbedID date
replace port_weight = 0 if missing(port_weight)
drop Fund
decode(fund_code), gen(Fund)
drop fund_code id

save "$temp/pre_25", replace

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

use "$temp/pre_25", clear

/* old list; ignore now unless trying to recreate pre-ORP tables 
	keep if inlist(Fund, "0041-FID SEL GOLD", "0046-FID SEL RETAILING", "0042-FID SEL BIOTECH" ///
	, "0063-FID SEL HEALTHCARE", "0069-FID SEL CHEMICALS", "0580-FID SEL PHARMACEUTCL" ///
	"OQNG-VANGUARD ENERGY ADM", "0354-FID SEL MED TECH&DV", "0028-FID SEL SOFTWARE", "0514-FID SEL NATURAL RES")
*/

// new list based on ORP data 	
	gen dummy = 1 if inlist(Fund, "0041-FID SEL GOLD", "0046-FID SEL RETAILING", "0042-FID SEL BIOTECH" ///
	, "0063-FID SEL HEALTHCARE", "0069-FID SEL CHEMICALS", "0302-FID PACIFIC BASIN" ///
	"OQNG-VANGUARD ENERGY ADM", "0513-FID SEL NATURAL GAS", "0028-FID SEL SOFTWARE", "")
	
	replace dummy = 1 if inlist(Fund, "0352-FID CHINA REGION", "0513-FID SEL NATURAL GAS", "2120-FID GLB COMDTY STK")
	
	keep if dummy == 1
	drop dummy 
	
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
	
	drop sector  
	
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
twoway (hist sharpe if date == 672 & total_exp_over == 0, start(-1) w(.1) percent color("$color_p2%30")) ///
(hist sharpe if date == 672 & total_exp_over == 1, start(-1) w(.1) percent color("$color_p3%30")), ///
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
twoway (hist sharpe if date == 672 & one_sector_overweight == 0, start(-1) w(.1) percent color("$color_p2%30")) ///
(hist sharpe if date == 672 & one_sector_overweight == 1, start(-1) w(.1) percent color("$color_p3%30")), ///
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













