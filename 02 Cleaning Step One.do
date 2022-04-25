
{ // clean data for cash-bond share and expense ratios (data is for 2010-2018)
use "$temp/crsp_fund_summary.dta", clear

 // check for duplicates
bys crsp_fundno caldt: gen dup = cond(_N==1,0,_n)
tab dup
drop if dup > 1

// check if the variables generally sum to one
gen total_per = cond(missing(per_com),0,per_com) + cond(missing(per_pref),0,per_pref) + ///
cond(missing(per_conv),0,per_conv) + cond(missing(per_corp),0,per_corp) + cond(missing(per_muni),0,per_muni) + ///
cond(missing(per_govt),0,per_govt) + cond(missing(per_oth),0,per_oth) + cond(missing(per_cash),0,per_cash) + ///
cond(missing(per_bond),0,per_bond) + cond(missing(per_abs),0,per_abs) + cond(missing(per_mbs),0,per_mbs) + ///
cond(missing(per_eq_oth),0,per_eq_oth) + cond(missing(per_fi_oth),0,per_fi_oth)
replace total_per = round(total_per)
count if total_per == 100
// filter to complete records
drop if total_per != 100

// adjust so no holdings are negative
foreach perc in per_com per_pref per_conv per_corp per_muni per_govt per_oth per_cash per_bond per_abs per_mbs per_eq_oth per_fi_oth {
	replace `perc' = 0 if `perc' < 0
}

 // calculate share of cash and bonds in each fund
gen cash_bonds = cond(missing(per_conv),0,per_conv) + cond(missing(per_corp),0,per_corp) + cond(missing(per_muni),0,per_muni) + ///
cond(missing(per_govt),0,per_govt) + cond(missing(per_cash),0,per_cash) + cond(missing(per_bond),0,per_bond) + ///
cond(missing(per_abs),0,per_abs) + cond(missing(per_abs),0,per_abs) + cond(missing(per_fi_oth),0,per_fi_oth)
replace cash_bonds = cash_bonds/100
drop if round(cash_bonds,.1) < 0 | round(cash_bonds,.1) > 1

 // calculate share of cash
gen cash_share = cond(missing(per_cash),0,per_cash)
replace cash_share = cash_share/100
drop if round(cash_share,.1) < 0 | round(cash_share,.1) > 1

 // calculate share of bonds in each fund
gen bond_share = cond(missing(per_conv),0,per_conv) + cond(missing(per_corp),0,per_corp) + cond(missing(per_muni),0,per_muni) + ///
cond(missing(per_govt),0,per_govt) + cond(missing(per_bond),0,per_bond) + ///
cond(missing(per_abs),0,per_abs) + cond(missing(per_abs),0,per_abs) + cond(missing(per_fi_oth),0,per_fi_oth)
replace bond_share = bond_share/100
drop if round(bond_share,.1) < 0 | round(bond_share,.1) > 1

// calculate share of equities in each fund
gen equities = cond(missing(per_eq_oth),0,per_eq_oth) + cond(missing(per_pref),0,per_pref) + ///
cond(missing(per_com),0,per_com)
replace equities = equities/100
drop if round(equities,.1) < 0 | round(equities,.1) > 1

// calculate share of other investments in each fund
gen oth_investments = cond(missing(per_oth),0,per_oth)
replace oth_investments = oth_investments/100
drop if round(oth_investments,.1) < 0 | round(oth_investments,.1) > 1

gen date = (yofd(caldt) - 1960) * 12

// deal with missing expense ratios
// if expense ratio is missing, fill in with previous available ratio, if still missing, use next available expense ratio
replace exp_ratio = . if exp_ratio == -99 | exp_ratio > 1 | exp_ratio == 0
sort crsp_fundno date
by crsp_fundno: replace exp_ratio = exp_ratio[_n-1] if missing(exp_ratio)
forvalues i = 1/9 {
	by crsp_fundno: replace exp_ratio = exp_ratio[_n+1] if missing(exp_ratio)
}

keep crsp_fundno date cash_bonds equities oth_investments cash_share bond_share exp_ratio

save "$temp/cashbond", replace

}

{ // load map of 2016 and 2017 funds to sector funds
import excel using "$input/2016 sector fund list.xlsx", clear firstrow
tempfile tempsector
save "`tempsector'"
import excel using "$input/2017_2018 Fund List.xls", clear firstrow
append using "`tempsector'"
drop perc_domestic_equities perc_intl_equities
bys Fund: keep if _n == 1
foreach var of varlist sector gold money_market bond equity tdf balanced real_estate {
	replace `var' = 0 if missing(`var')
}

save "$temp/sectorfunds", replace

keep Fund intl_share_of_equities
rename Fund age_TDF
rename intl_share_of_equities tdf_intl_share
save "$temp/tdf_sectorfunds", replace

}

{ // load individual portfolio data
use "$temp/individual_ports.dta", clear // 12,442 unique

joinby Fund date using "$temp/fund_returns_series_crosswalk_post.dta"

// check for duplicates
duplicates drop

// save total assets by ScrubbedID and date
preserve
	bys ScrubbedID date: keep if _n == 1
	keep ScrubbedID date total_assets Gender RoundedSalary MaritialStatus
	save "$temp/asset_list", replace
restore


// Vanguard 2010 TDF is pushed into Income TDF in 2016, so replace it with Income Fund from 2014 onward (so we will have at least 2 future years of returns data)
replace crsp_fundno = 31290 if (Fund == "OKKK-VANG TARGET RET 2010" & date <= 672 & date >= 648) | (Fund == "OV6N-VANG INST TR 2010" & date == 684)
replace crsp_fundno = 64321 if (Fund == "OKKK-VANG TARGET RET 2010" & date <= 672 & date >= 648)
replace crsp_fundno = 31290 if (Fund == "OV6N-VANG INST TR 2010" & date == 684)
replace Fund = "OSHO-VANG TARGET RET INC" if Fund == "OKKK-VANG TARGET RET 2010" & date <= 672 & date >= 648
replace Fund = "OV6M-VANG INST TR INCOME" if Fund == "OV6N-VANG INST TR 2010" & date == 684

// save a list of all funds by date
preserve
	bys Fund date: keep if _n == 1
	gen calyear = date/12 + 1960
	keep Fund calyear crsp_fundno
	save "$temp/fund_date_list", replace
restore

// save a list of all funds from 2016-2018
preserve
	keep if inlist(date,672,684,696)
	gen date_2016 = (date == 672)
	gen date_2017 = (date == 684)
	gen date_2018 = (date == 696)
	bys Fund: egen flag_2016 = max(date_2016)
	bys Fund: egen flag_2017 = max(date_2017)
	bys Fund: egen flag_2018 = max(date_2018)
	bys Fund: keep if _n == 1
	keep Fund crsp_fundno flag_2016 flag_2017 flag_2018

	export excel "$temp/limited_fund_list.xls", replace firstrow(variable)
restore

}

{ // merge in crsp data
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m
drop if missing(date)

// save list of missing expense ratios
preserve
	keep if missing(exp_ratio)
	keep if inlist(date, 672, 684, 696)
	bys Fund crsp_fundno: keep if _n == 1
	keep Fund crsp_fundno
	export excel "$temp/missing expense ratios.xlsx", replace firstrow(variables)
	// manually found expense ratios (as of Dec. 2019) for these funds
restore

// import and merge in additional expense ratio data
preserve
	import excel "$input/missing expense ratio data.xlsx", firstrow clear
	rename exp_ratio exp_ratio2
	bys crsp_fundno: keep if _n == 1
	drop Fund
	save "$temp/missing expense ratio data", replace
restore

cap drop _m
merge m:1 crsp_fundno using "$temp/missing expense ratio data"
drop if _m == 2
replace exp_ratio = exp_ratio2 if missing(exp_ratio)
assert !missing(exp_ratio) if inlist(date, 672, 684, 696)
drop _m exp_ratio2


// save list of missing equities ratios
preserve
	keep if missing(equities)
	keep if inlist(date, 672, 684, 696)
	bys Fund crsp_fundno: keep if _n == 1
	keep Fund crsp_fundno
	export excel "$temp/missing equities.xlsx", replace firstrow(variables)
	// manually found share equities (as of Dec. 2019) for these funds
restore

// import and merge in additional equities data
preserve
	import excel "$input/missing equities data.xlsx", firstrow clear
	rename equities equities2
	bys crsp_fundno: keep if _n == 1
	drop Fund
	save "$temp/missing equities data", replace
restore

cap drop _m
merge m:1 crsp_fundno using "$temp/missing equities data"
drop if _m == 2
replace equities = equities2 if missing(equities)
assert !missing(equities) if inlist(date, 672, 684, 696)
drop _m equities2

}

{ // drop 2019 data
drop if date >= 708
}

{ // merge in data on sector funds
merge m:1 Fund using "$temp/sectorfunds"
drop if _m == 2
assert _m == 3 if inlist(date, 672, 684)
drop _m
replace intl_share_of_equities = .3 if date < 672 & (inlist(Fund, "OV6M-VANG INST TR INCOME", "OV6N-VANG INST TR 2010", "OV6O-VANG INST TR 2015","OV6P-VANG INST TR 2020","OV6Q-VANG INST TR 2025") ///
| inlist(Fund, "OV6R-VANG INST TR 2030","OV6S-VANG INST TR 2035", "OV6T-VANG INST TR 2040", "OV6U-VANG INST TR 2045","OV6V-VANG INST TR 2050","OV6W-VANG INST TR 2055","OV6X-VANG INST TR 2060") ///
| inlist(Fund, "OSHO-VANG TARGET RET INC", "OKKK-VANG TARGET RET 2010",  "OSHQ-VANG TARGET RET 2015", "OKKL-VANG TARGET RET 2020", "OSHR-VANG TARGET RET 2025") ///
| inlist(Fund, "OKKM-VANG TARGET RET 2030", "OSHS-VANG TARGET RET 2035", "OKKN-VANG TARGET RET 2040", "OSHT-VANG TARGET RET 2045", "OKKO-VANG TARGET RET 2050", "OEKG-VANG TARGET RET 2055"))

replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0

gen intl_equity_share = intl_share_of_equities*equities
// define international equities as equity funds that are > 50% international
gen intl_equity_fund = (equity == 1 & intl_share_of_equities > .5)
preserve
	keep Fund intl_equity_fund
	bys Fund: keep if _n == 1
	save "$temp/intl_equity_funds", replace
restore

keep ScrubbedID date crsp_fundno crsp_fundno_orig port_weight sector gold money_market AgeasofNov2018 ///
Fund intl_equity_share intl_share_of_equities exp_ratio cash_bonds cash_share bond_share equities oth_investments
}

{ // determine correct TDF and benchmark level of domestic equities & international equities
gen retirement_target = round(2018 - AgeasofNov2018 + 65, 5)
replace retirement_target = 2055 if retirement_target > 2055 & retirement_target != . & date > 672
replace retirement_target = 2060 if retirement_target > 2060 & retirement_target != . & date <= 672

gen age_TDF = ""
gen crsp_fundno_age_TDF = .
// TDFs for later years
replace crsp_fundno_age_TDF  = 31290 if retirement_target <= 2010 & date <= 672
replace age_TDF = "OSHO-VANG TARGET RET INC" if retirement_target <= 2010 & date <= 672
replace crsp_fundno_age_TDF  = 31292 if retirement_target == 2015 & date <= 672
replace age_TDF = "OSHQ-VANG TARGET RET 2015" if retirement_target == 2015 & date <= 672
replace crsp_fundno_age_TDF  = 31297 if retirement_target == 2020 & date <= 672
replace age_TDF = "OKKL-VANG TARGET RET 2020" if retirement_target == 2020 & date == 672
replace crsp_fundno_age_TDF  = 31293 if retirement_target == 2025 & date <= 672
replace age_TDF = "OSHR-VANG TARGET RET 2025" if retirement_target == 2025 & date <= 672
replace crsp_fundno_age_TDF  = 31300 if retirement_target == 2030 & date <= 672
replace age_TDF = "OKKM-VANG TARGET RET 2030" if retirement_target == 2030 & date <= 672
replace crsp_fundno_age_TDF  = 31294 if retirement_target == 2035 & date <= 672
replace age_TDF = "OSHS-VANG TARGET RET 2035" if retirement_target == 2035 & date <= 672
replace crsp_fundno_age_TDF  = 31299 if retirement_target == 2040 & date <= 672
replace age_TDF = "OKKN-VANG TARGET RET 2040" if retirement_target == 2040 & date <= 672
replace crsp_fundno_age_TDF  = 31295 if retirement_target == 2045 & date <= 672
replace age_TDF = "OSHT-VANG TARGET RET 2045" if retirement_target == 2045 & date <= 672
replace crsp_fundno_age_TDF  = 31298 if retirement_target == 2050 & date <= 672
replace age_TDF = "OKKO-VANG TARGET RET 2050" if retirement_target == 2050 & date <= 672
replace crsp_fundno_age_TDF  = 50154 if retirement_target >= 2055 & retirement_target < . & date <= 672
replace age_TDF = "OEKG-VANG TARGET RET 2055" if retirement_target >= 2055 & retirement_target < . & date <= 672

// TDFs for earlier years
replace crsp_fundno_age_TDF  = 31290 if retirement_target <= 2010 & date > 672
replace age_TDF = "OV6M-VANG INST TR INCOME" if retirement_target <= 2010 & date > 672
replace crsp_fundno_age_TDF  = 31292 if retirement_target == 2015 & date > 672
replace age_TDF = "OV6O-VANG INST TR 2015" if retirement_target == 2015 & date > 672
replace crsp_fundno_age_TDF  = 31297 if retirement_target == 2020 & date > 672
replace age_TDF = "OV6P-VANG INST TR 2020" if retirement_target == 2020 & date > 672
replace crsp_fundno_age_TDF  = 31293 if retirement_target == 2025 & date > 672
replace age_TDF = "OV6Q-VANG INST TR 2025" if retirement_target == 2025 & date > 672
replace crsp_fundno_age_TDF  = 31300 if retirement_target == 2030 & date > 672
replace age_TDF = "OV6R-VANG INST TR 2030" if retirement_target == 2030 & date > 672
replace crsp_fundno_age_TDF  = 31294 if retirement_target == 2035 & date > 672
replace age_TDF = "OV6S-VANG INST TR 2035" if retirement_target == 2035 & date > 672
replace crsp_fundno_age_TDF  = 31299 if retirement_target == 2040 & date > 672
replace age_TDF = "OV6T-VANG INST TR 2040" if retirement_target == 2040 & date > 672
replace crsp_fundno_age_TDF  = 31295 if retirement_target == 2045 & date > 672
replace age_TDF = "OV6U-VANG INST TR 2045" if retirement_target == 2045 & date > 672
replace crsp_fundno_age_TDF  = 31298 if retirement_target == 2050 & date > 672
replace age_TDF = "OV6V-VANG INST TR 2050" if retirement_target == 2050 & date > 672
replace crsp_fundno_age_TDF  = 50154 if retirement_target == 2055 & date > 672
replace age_TDF = "OV6W-VANG INST TR 2055" if retirement_target == 2055 & date > 672
replace crsp_fundno_age_TDF  = 54310 if retirement_target >= 2060 & retirement_target < . & date > 672
replace age_TDF = "OV6X-VANG INST TR 2060" if retirement_target >= 2060 & retirement_target < . & date > 672

// merge in crsp data for TDFs (add in the missing data for future merges)
preserve
	use "$temp/cashbond", clear
	assert !missing(date)
	bys crsp_fundno date: assert _N == 1

	// append on for missing date & drop duplicates (since not all of those that appear in crsp have full the set of dates)
	append using "$temp/missing expense ratio data"
	replace date = 672 if missing(date)
	append using "$temp/missing expense ratio data"
	replace date = 684 if missing(date)
	append using "$temp/missing expense ratio data"
	replace date = 696 if missing(date)
	append using "$temp/missing equities data"
	replace date = 672 if missing(date)
	append using "$temp/missing equities data"
	replace date = 684 if missing(date)
	append using "$temp/missing equities data"
	replace date = 696 if missing(date)

	bys crsp_fundno date: gen count = _N
	drop if count == 3 & equities2 != .
	drop count
	bys crsp_fundno date: gen count = _N
	assert count <= 2
	drop if count == 2 & exp_ratio2 != .
	drop exp_ratio2 equities2 count
	bys crsp_fundno date: gen count = _N
	asser count == 1
	drop count

	// merge in data for missing equities and expense ratio data
	merge m:1 crsp_fundno using "$temp/missing expense ratio data"
	replace exp_ratio = exp_ratio2 if missing(exp_ratio)
	cap drop _m
	merge m:1 crsp_fundno using "$temp/missing equities data"
	replace equities = equities2 if missing(equities)
	drop exp_ratio2 equities2 _m


	// resave crsp data with manually collected values
	save "$temp/cashbond", replace


	rename crsp_fundno crsp_fundno_age_TDF
	foreach var in cash_bonds equities oth_investments cash_share bond_share exp_ratio {
		rename `var' tdf_`var'
	}

	save "$temp/cashbond_tdf", replace

restore

merge m:1 date crsp_fundno_age_TDF using "$temp/cashbond_tdf"
drop if _m == 2
assert _m != 1 if date == 672
drop _m

// merge in international share of equities
merge m:1 age_TDF using "$temp/tdf_sectorfunds"
drop if _m == 2
assert _m == 3 if inlist(date, 672,684,696)
drop _m
replace tdf_intl_share = .3 if date < 672 & (inlist(age_TDF, "OV6M-VANG INST TR INCOME", "OV6N-VANG INST TR 2010", "OV6O-VANG INST TR 2015","OV6P-VANG INST TR 2020","OV6Q-VANG INST TR 2025") ///
| inlist(age_TDF, "OV6R-VANG INST TR 2030","OV6S-VANG INST TR 2035", "OV6T-VANG INST TR 2040", "OV6U-VANG INST TR 2045","OV6V-VANG INST TR 2050","OV6W-VANG INST TR 2055","OV6X-VANG INST TR 2060") ///
| inlist(age_TDF, "OSHO-VANG TARGET RET INC", "OKKK-VANG TARGET RET 2010",  "OSHQ-VANG TARGET RET 2015", "OKKL-VANG TARGET RET 2020", "OSHR-VANG TARGET RET 2025") ///
| inlist(age_TDF, "OKKM-VANG TARGET RET 2030", "OSHS-VANG TARGET RET 2035", "OKKN-VANG TARGET RET 2040", "OSHT-VANG TARGET RET 2045", "OKKO-VANG TARGET RET 2050", "OEKG-VANG TARGET RET 2055"))
gen tdf_intl_eq_share = tdf_intl_share * tdf_equities
gen tdf_dom_eq_share = tdf_equities - tdf_intl_eq_share
assert date != 672 if (tdf_intl_eq_share == . | tdf_dom_eq_share == .)

}

{ // save glidepath data
preserve
	keep if date == 672
	gen target_age2018 = 2018 - (retirement_target - 65)
	keep if retirement_target <= 2055 & retirement_target >= 2010
	keep if AgeasofNov2018 == target_age2018
	bys age_TDF: keep if _n == _N

	gsort -AgeasofNov2018
	gen age = AgeasofNov2018 - 3
	gen empty = ""
	la var age "Age"
	la var age_TDF "Fund"
	la var tdf_cash_share "% Cash"
	la var tdf_bond_share "% Bonds"
	la var tdf_cash_bonds "% Cash & Bonds"
	la var tdf_intl_eq_share "% International Equities"
	la var tdf_dom_eq_share "% Domestic Equities"
	la var tdf_equities "% Equities"
	la var empty " "

	gen graph_equities = tdf_equities*100
	gen graph_equities2 = graph_equities/2
	gen graph_equities3 = graph_equities*2
	replace graph_equities3 = 100 if graph_equities3 > 100
	save "$temp/glidepath graph data", replace

	keep age_TDF tdf_cash_share tdf_bond_share tdf_cash_bonds tdf_intl_eq_share tdf_dom_eq_share tdf_equities empty
	order age_TDF tdf_cash_share tdf_bond_share tdf_intl_eq_share tdf_dom_eq_share empty tdf_cash_bonds tdf_equities

	export excel "$output/51 - 2016 Glidepath.xlsx", replace firstrow(varlabels)


restore
}

{ // weight sector variables by portfolio share
// replace missing variables with zeros (only have flags for any funds that were present in 2016 and 2017 currently)
foreach var of varlist sector gold money_market intl_share_of_equities {
	replace `var' = 0 if missing(`var')
}

assert !missing(sector) & !missing(gold) & !missing(money_market) & ! missing()
replace sector = port_weight*sector
replace gold = port_weight*gold
replace money_market = port_weight*money_market
}

{ // flag over- and under-weighting

// individual sector funds
gen temp = (gold > $ind_gold_lev & gold < .)
bys ScrubbedID date: egen goldbug = max(temp)
drop temp
gen temp = (sector > $ind_sec_lev & sector < .)
bys ScrubbedID date: egen one_sector_overweight = max(temp)
drop temp

// total sector funds cap
bys ScrubbedID date: egen total_sector_temp = total(sector)
gen total_sector_overweight = (total_sector_temp > $tot_sec_lev & sector < .)

// total money market funds cap
bys ScrubbedID date: egen total_mm_temp = total(money_market)
gen total_mm_overweight = (total_mm_temp > $tot_mm_lev & total_mm_temp < .)

// total international share of equities minimum
gen intl_weight = equities * port_weight
bys ScrubbedID date: egen total_intl_share_temp = wtmean(intl_share_of_equities), weight(intl_weight)
gen total_intl_share_under = (total_intl_share_temp < $intl_eq_perc)
drop intl_share_of_equities

// total expense ratio cap
bys ScrubbedID date: egen total_exp_temp = wtmean(exp_ratio), weight(port_weight)
gen total_exp_over = (total_exp_temp > $exp_ratio_cap & total_exp_temp < .)
gen total_exp_over_50 = (total_exp_temp > .0050 & total_exp_temp < .)
gen total_exp_over_100 = (total_exp_temp > .0100 & total_exp_temp < .)

// minimum half of glide path for equities, max double
bys ScrubbedID date: egen tot_eq = wtmean(equities), weight(port_weight)
gen total_eq_under = (tot_eq < (tdf_equities / 2))
gen total_eq_over = (tot_eq > (tdf_equities * 2) & tot_eq < .)
gen total_eq_violation = (total_eq_under == 1 | total_eq_over == 1)

}

{ // filter out portfolios that have weights that do not sum to one
bys ScrubbedID date: egen total_weight = total(port_weight)
assert !missing(total_weight) & total_weight >= .9999
drop total_weight
}

{ // save list portfolios affected by guardrails
preserve
	keep if date == 672
	keep ScrubbedID goldbug total_eq_under total_eq_over total_eq_violation total_exp_over total_exp_over_50 total_exp_over_100 total_intl_share_under total_mm_overweight total_sector_overweight one_sector_overweight AgeasofNov2018
	bys ScrubbedID: keep if _n == 1
	save "$temp/guardrails flags", replace
restore

preserve
	keep ScrubbedID date goldbug total_eq_under total_eq_over total_eq_violation total_exp_over total_intl_share_under total_mm_overweight total_sector_overweight one_sector_overweight
	bys ScrubbedID date: keep if _n == 1
	save "$temp/guardrail each date flags", replace
restore

}

{ // save data
save "$temp/cleaning_step_one.dta", replace
}


use "$temp/cleaning_step_one.dta", replace

sort Scr date

collapse (mean) crsp_fundno exp_ratio, by(Scr) // 12442 in ORP data

use "C:\Users\EI87\Dropbox (YLS)\Retirement Menu Design\code\STATA -- ZS\Temp\cleaning_step_one.dta", clear

sort Scr date

collapse (mean) crsp_fundno exp_ratio, by(Scr) // 14547 in old data
