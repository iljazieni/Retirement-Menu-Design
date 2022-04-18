// expense ratio individual guardrail

use "$temp/cleaning_step_one.dta", clear

keep if inlist(date, 672, 684)

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
assert total_exp_temp <= .0075 | missing(total_exp_temp) if missing(total_adjust2)
replace total_adjust2 = 0 if missing(total_adjust2) | total_adjust2 < 0

// adjust down the port_weight of those that are over cutoff (proportionate to their port_weight among those that are over cutoff)
gen share_total_over = port_weight / port_weight_over2
replace port_weight = port_weight - (share_total_over * total_adjust2) if exp_ratio > .0075 & !missing(exp_ratio)

// make sure port_weight sums correctly
bys ScrubbedID date: egen temp2 = total(port_weight)
// assert round(temp2 + total_adjust2, .0001) == 1

preserve
	keep ScrubbedID total_adjust2
	rename total_adjust2 adjust_exp_ratio
	bys ScrubbedID: keep if _n == 1
	save "$temp/onlytdf_exp_ratio_adjust", replace
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
	assert Fund != ""
	assert crsp_fundno != .
	tempfile filler2
	save "`filler2'"
restore

append using "`filler2'"

// make sure port_weight sums correctly
cap drop temp2
bys ScrubbedID date: egen temp2 = total(port_weight)
// assert round(temp2,.0001) == 1

// calculate portfolio expense ratio (and fix rounding errors)
cap drop total_exp_temp
bys ScrubbedID date: egen total_exp_temp = wtmean(exp_ratio), weight(port_weight)
gen temp3 = round(total_exp_temp,.0001)
// assert round(total_exp_temp,.0001) <= round($exp_ratio_cap,.0001) | missing(total_exp_temp)

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

save "$temp/guard_intrm_onlytdf_expenseratio", replace

