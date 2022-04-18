*** REAL ESTATE SUBSETTING 

{ // extra data cleaning steps (filtered to only 2016)
use "$temp/collapse2.dta", clear

keep ScrubbedID steady_pre steady_pre_sc smart
bys ScrubbedID: keep if _n == 1
tempfile steady_pre_list 
save "`steady_pre_list'"

use "$temp/full_data.dta", clear
merge m:1 ScrubbedID using "`steady_pre_list'"
// assert _m != 2
// filter to observations in final data (including the smart/steady investors)
keep if _m == 3
drop _m

merge m:1 Fund using "$temp/funds_2016_2017"
gen steady_fund = (_m == 3)
drop _m

// filter to pre- and post-reform
keep if inlist(date, 672, 684, 696)

{ // clean variables
la define steady_pre 0 "Streamlined group" ///
1 "Non-streamlined group"
la val steady_pre steady_pre

// merge in total assets
merge m:1 ScrubbedID date using "$temp/asset_list"
assert _m != 1
keep if _m == 3
drop _m
gen FundsHeld = round(total_assets * port_weight, .01)

keep ScrubbedID date Fund FundsHeld total_assets port_weight steady_pre steady_pre_sc steady_fund AgeasofNov2018 RoundedSalary Gender
gen counter = 1
bys ScrubbedID date: gen n_funds = _N
bys Fund steady_pre date: gen fund_counter = (_n == 1)
gen dropped_dollars = (-1 * (steady_fund-1)) * FundsHeld
gen steady_dollars = steady_fund*FundsHeld

gen female = (Gender == "F")
gen male = (Gender == "M")
gen unknown_gender = (male == 0 & female == 0)

gen age2016 = AgeasofNov2018 - 2
gen age20s = (age2016 < 30)
gen age30s = (age2016 >= 30 & age2016 < 40)
gen age40s = (age2016 >= 40 & age2016 < 50)
gen age50s = (age2016 >= 50 & age2016 < 60)
gen age60s = (age2016 >= 60 & age2016 < 70)
gen age70s = (age2016 >= 70 & age2016 < .)

la var age20s "Age under 30" 
la var age30s "Age 30-39" 
la var age40s "Age 40-49" 
la var age50s "Age 50-59" 
la var age60s "Age 60-69" 
la var age70s "Age 70+" 

la var female "Female"
la var male "Male"
la var unknown_gender "Gender unknown"
}


}

** Real Estate Descriptives 

gen real_estate = 1 if Fund == "0303-FID REAL ESTATE INVS" | Fund == "OKBH-VAN REAL EST IDX IS" | Fund == "1368-FID INTL REAL ESTATE" | Fund == "OQNJ-VAN REAL EST IDX ADM" | Fund == "0833-FID REAL ESTATE INC" | Fund == "1505-FID STRAT REAL RET"
replace real_estate = 0 if real_estate == .

egen real_estate_exposure = sum(port_weight) if real_estate, by(ScrubbedID date)
replace real_estate_exposure = 0 if real_estate_exposure == .

sort ScrubbedID date real_estate_exposure

gen tdf = 1 if cond(strpos(Fund, "FID FREEDOM K") > 0, 1, 0)
replace tdf = 0 if tdf == .

egen tdf_holder = max(tdf), by(Scr date)

sum real_estate_exposure if tdf_holder == 1 
sum real_estate_exposure if tdf_holder == 0

foreach value of numlist 1 2 5 90 {
	
	gen pp`value' = `value' / 100
	gen prop`value' = cond(real_estate_exposure > pp`value', 1, 0)
	sum prop`value'
	gen fraction`value' = `r(mean)'
	drop pp`value'
	drop prop`value'
}

foreach value of numlist 1 2 5 90 {
	
	gen pp`value' = `value' / 100
	gen prop`value' = cond(real_estate_exposure > pp`value', 1, 0)
	sum prop`value' if tdf_holder == 0
	gen fraction`value'_notdf = `r(mean)' 
	drop pp`value'
	drop prop`value'
}

//drop if total_assets < 10000

gen helper = cond(real_estate_exposure > 90/100, 1, 0)
egen sum_1 = sum(helper)

gen helper2 = cond(real_estate_exposure > 90/100 & tdf_holder == 0, 1, 0)
egen sum_2 = sum(helper2)


/*
duplicates drop Fund, force

preserve 

import excel "$input/real_estate_data.xlsx", sheet("Sheet1") firstrow clear

save "$temp/fund_list_zs", replace

restore 

merge 1:m Fund using "$temp/fund_list_zs"

drop if _m != 3 
keep Fund CleanFundName BasicMaterials ConsumerCyclical FinancialServices RealEstate ConsumerDefensive Healthcare Utilities CommunicationServices Energy Industrials Technology

export delimited using "$temp\fund list real estate.csv", replace
*/
*** Compute Real Estate Fraction ***

import excel "$input/real_estate_tdf.xlsx", firstrow clear

gen Fund = "2174-FID FREEDOM K 2010"

rename A sub_fund
rename RealEstateFraction real_estate

destring real_estate, force replace

keep sub_fund real_estate Fund

gen fraction = ""
replace fraction = sub_fund
destring fraction, force replace

order Fund sub_fund fraction real_estate

drop if sub_fund == ""
replace sub_fund = "" if substr(sub_fund, 1, 1) == "."

gen n = _n
replace fraction = fraction[_n+1] if fraction == .
replace real_estate = real_estate[_n+1] if real_estate == .

drop if sub_fund == ""
drop n
drop if sub_fund == "Emerging-Markets Equities"

replace real_estate = 0 if real_estate == .
replace real_estate = real_estate / 100

gen product = real_estate * fraction

egen product_sum = sum(product) 
egen fraction_sum = sum(fraction)

gen real_estate_fraction = product_sum * fraction_sum // 0.2% 

// 2050 

import excel "$input/Real Estate Data Collection 2020 to 2050.xlsx", sheet("Fidelity Freedom K 2050") firstrow clear
gen Fund = "2175-FID FREEDOM K 2015"

rename B real_estate
rename DomesticEquities sub_fund

gen fraction = ""
replace fraction = sub_fund
destring fraction, force replace

order Fund sub_fund fraction real_estate

drop if sub_fund == ""
drop if sub_fund == ""
drop if sub_fund == "0"
replace sub_fund = "" if substr(sub_fund, 1, 1) == "."

gen n = _n
replace fraction = fraction[_n+1] if fraction == .
replace real_estate = real_estate[_n+1] if real_estate == .

replace real_estate = 0 if real_estate == .
replace real_estate = real_estate / 100

drop if sub_fund == "Equities"
drop if sub_fund == "International Equities"
drop if sub_fund == "Commodities"
drop if sub_fund == "Developed-Markets Equities"
drop if sub_fund == "Emerging-Markets Equities"

drop n

collapse (firstnm) fraction real_estate, by(sub_fund Fund)

drop if sub_fund == "MSCI EAFE FUT JUN21 MFSM1"

gen n = _n

drop if n == 1

drop n

gen product = real_estate * fraction

egen product_sum = sum(product) 
egen fraction_sum = sum(fraction)

gen real_estate_fraction = product_sum * fraction_sum // 0.0134 => 1.34%

