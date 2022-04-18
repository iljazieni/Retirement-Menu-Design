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








