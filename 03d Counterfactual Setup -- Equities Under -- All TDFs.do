// lower glidepath individual guardrail

use "$temp/cleaning_step_one.dta", clear

keep if inlist(date, 672, 684)

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
gen flag_eq = equities * port_weight
bys ScrubbedID date: egen tot_eq = total(flag_eq)
gen total_eq_under2 = (tot_eq < (tdf_equities / 2) & tot_eq < .)
gen lev_eq_under = tdf_equities * 2 - tot_eq
replace lev_eq_under = 0 if lev_eq_under < 0
count if lev_eq_under == .
assert r(N) == 0

// tdf_equities / 2 = tot_eq * (1 - x) + x * tdf_equities
// tdf_equities / 2 - tot_eq = x * tdf_equities - x * tot_eq
gen total_adjust3 = (tdf_equities / 2 - tot_eq ) / (tdf_equities - tot_eq)
replace total_adjust3 = 0 if total_eq_under2 == 0
assert !missing(total_adjust3)

preserve
	keep ScrubbedID total_adjust3
	rename total_adjust3 adjust_eq_under
	bys ScrubbedID: keep if _n == 1
	save "$temp/onlytdf_eq_under_adjust", replace
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
	assert Fund != ""
	assert crsp_fundno != .
	tempfile filler3
	save "`filler3'"
restore

append using "`filler3'"

// make sure port_weight sums correctly
cap drop temp2
bys ScrubbedID date: egen temp2 = total(port_weight)
// assert round(temp2,.0001) == 1

// calculate portfolio equities
cap drop flag_eq tot_eq
gen flag_eq = equities * port_weight
bys ScrubbedID date: egen tot_eq = total(flag_eq)
// assert round(tot_eq,.00001) >= (round(tdf_equities / 2, .00001)) | missing(tot_eq)

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

save "$temp/guard_intrm_onlytdf_equitiesunder", replace

