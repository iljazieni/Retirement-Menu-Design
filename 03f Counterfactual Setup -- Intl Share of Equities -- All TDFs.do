// intl share of equities individual guardrail 

use "$temp/cleaning_step_one.dta", clear

keep if inlist(date, 672, 684)

// merge in equities data
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
assert _m == 3 if inlist(date, 672,684,696)
drop _m

// calculate total international share of equities minimum
cap drop intl_share_of_equities
merge m:1 Fund using "$temp/sectorfunds"
assert _m != 1
drop if _m != 3
drop _m
replace intl_share_of_equities = .3 if date < 672 & (inlist(Fund, "OV6M-VANG INST TR INCOME", "OV6N-VANG INST TR 2010", "OV6O-VANG INST TR 2015","OV6P-VANG INST TR 2020","OV6Q-VANG INST TR 2025") ///
| inlist(Fund, "OV6R-VANG INST TR 2030","OV6S-VANG INST TR 2035", "OV6T-VANG INST TR 2040", "OV6U-VANG INST TR 2045","OV6V-VANG INST TR 2050","OV6W-VANG INST TR 2055","OV6X-VANG INST TR 2060") ///
| inlist(Fund, "OSHO-VANG TARGET RET INC", "OKKK-VANG TARGET RET 2010",  "OSHQ-VANG TARGET RET 2015", "OKKL-VANG TARGET RET 2020", "OSHR-VANG TARGET RET 2025") ///
| inlist(Fund, "OKKM-VANG TARGET RET 2030", "OSHS-VANG TARGET RET 2035", "OKKN-VANG TARGET RET 2040", "OSHT-VANG TARGET RET 2045", "OKKO-VANG TARGET RET 2050", "OEKG-VANG TARGET RET 2055"))
replace equities = . if equities == 0
replace intl_share_of_equities = . if equities == .
replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0 & !missing(equities)
assert equities == . if intl_share_of_equities == .

cap drop non_missing_weight
bys ScrubbedID date: egen non_missing_weight1 = total(port_weight) if !missing(intl_share_of_equities) & !missing(equities)
bys ScrubbedID date: egen non_missing_weight = min(non_missing_weight)

// check intl weighting
cap drop intl_weight
gen intl_weight = port_weight * equities
gen intl_tot_1 = equities * intl_share_of_equities 
bys ScrubbedID date: egen intl_tot_2 = wtmean(intl_tot_1), weight(port_weight)
bys ScrubbedID date: egen intl_tot_3 = wtmean(equities), weight(port_weight)
gen intl_tot_4 = intl_tot_2/intl_tot_3
bys ScrubbedID date: egen total_intl_share_temp2 = wtmean(intl_share_of_equities), weight(intl_weight)
// assert round(total_intl_share_temp2, .0001) == round(intl_tot_4, .0001)

cap drop flag_eq tot_eq
gen flag_eq = equities * port_weight
bys ScrubbedID date: egen tot_eq = total(flag_eq)

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
	save "$temp/onlytdf_intl_adjust", replace
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
	assert Fund != ""
	assert crsp_fundno != .
	tempfile filler5
	save "`filler5'"
restore

append using "`filler5'"

// make sure port_weight sums correctly
cap drop temp2
bys ScrubbedID date: egen temp2 = total(port_weight)
// assert round(temp2,.0001) == 1

// update weighting
replace intl_weight = port_weight * equities

// calculate portfolio equities
cap drop total_intl_share_temp2
bys ScrubbedID date: egen total_intl_share_temp2 = wtmean(intl_share_of_equities), weight(intl_weight)
// assert round(total_intl_share_temp2, .0001) >= round($intl_eq_perc, .0001)


{ // collapse in case repeatedly placed in same TDF and make sure we have all necessary variables
collapse (sum) port_weight, by(ScrubbedID Fund crsp_fundno crsp_fundno_orig date)

// merge in additional fund data
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m 
merge m:1 Fund using "$temp/sectorfunds"
assert _m != 1
drop if _m != 3
drop _m

replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0
gen intl_equity_share = intl_share_of_equities*equities
// define international equities as equity funds that are > 50% international
gen intl_equity_fund = (equity == 1 & intl_share_of_equities > .5)

// merge in guardrails flags
merge m:1 ScrubbedID using "$temp/guardrails flags"
assert _m == 3 if date == 672
drop _m
}


save "$temp/guard_intrm_onlytdf_intl", replace










