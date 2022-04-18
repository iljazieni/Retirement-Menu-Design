/*
Changes in plan participation after streamlining
ZRS

*/



// load data 
// use "$temp/collapse2_combined", clear

use "$temp/individual_ports.dta", clear

// keep one observation per person-date
bys ScrubbedID date: keep if _n == 1

// flag employees that are present in each year
bys ScrubbedID: egen present_2012 = max(date == 624)
bys ScrubbedID: egen present_2013 = max(date == 636)
bys ScrubbedID: egen present_2014 = max(date == 648)
bys ScrubbedID: egen present_2015 = max(date == 660)
bys ScrubbedID: egen present_2016 = max(date == 672)
bys ScrubbedID: egen present_2017 = max(date == 684)
bys ScrubbedID: egen present_2018 = max(date == 696)
summ present_*

// flag which year employees leave the plan
forvalues i = 2012/2017 {
	local j = `i' + 1 
	gen left_after_`i' = present_`j' == 0 if present_`i' == 1 
}
summ left_after_*

// flag employees that are 60+
replace date = 1960+date/12
gen age = AgeasofNov2018 - (2018 - date)
assert !missing(age)
gen under60 = age < 60

// determine total number of employees at each date
preserve
	gen counter = 1
	collapse (sum) counter, by(date)
	la var counter "Total participants"
	twoway 	(lfitci counter date) ///
	(scatter counter date) ///
	, ylab(,nogrid) xline(684)
	graph export "$output/74 - Participants by date.pdf", replace

restore

// determine total number of employees that were present in 2016 that were also present at each date
// (would need to do this for each year to have a proper comparison)
preserve
	keep if present_2016 == 1
	gen counter = 1
	collapse (sum) counter, by(date)
	la var counter "Total participants"
	scatter counter date, ylab(,nogrid) xline(684)
restore

// graph proportion present and proportion that leave 
preserve
	collapse (mean) present_* left_after_*
	gen i = 1
	reshape long present_ left_after_, i(i) j(date)
	drop i
	la var present_ `""Percent of all eventual" "participants present in year""'
	la var left_after_ `""Percent of those present" "in year that left plan after year""'	
	twoway 	(lfitci left_after date) ///
	(scatter left_after_ date) /// //(scatter present_ date, yaxis(2) ytitle(,size(vsmall))) ///
	, ylab(,nogrid) xline(684) ytitle(,size(vsmall)) legend(order(3) size(small))
	graph export "$output/73.1 - Proportion Leaving Plan by Date.pdf", replace

restore

// graph proportion present and proportion that leave, by 59 and under vs 60 and over
preserve
	collapse (mean) present_* left_after_*, by(under60)
	reshape long present_ left_after_, i(under60) j(date)
	la var present_ `""Share of all eventual" "participants present in year""'
	la var left_after_ `""Share of those present" "in year that left plan after year""'	

	twoway 	(lfitci left_after_ date if under60 == 1, color(%30)) ///
	(lfitci left_after_ date if under60 == 0, color(%30)) ///	
	(scatter left_after_ date if under60 == 1) ///
	(scatter left_after_ date if under60 == 0) ///
	, ylab(,nogrid) xline(684) ytitle(,size(vsmall)) ///
	legend(label(5 "Under 60") label(6 "60 and up") size(small) order(5 6)) 
	graph export "$output/73.2 - Proportion Leaving Plan by Date and Age.pdf", replace

restore






// comparing expected returns to realized returns to see if those that stayed changed contributions
// use "$temp/full_data.dta", clear
use "$temp/joined_fund_data", replace
gen ret = port_weight*mret
gen year = yofd(caldt)
gen year2 = 1960 + date/12
keep if year == year2 
drop year*
collapse (sum) ret, by(ScrubbedID date caldt)

bys ScrubbedID date: gen annualized_return = 1 + ret if _n == 1
by ScrubbedID date: replace annualized_return = (1 + ret) * annualized_return[_n-1] if _n != 1
by ScrubbedID date: replace annualized_return = annualized_return[_N]
drop ret caldt
by ScrubbedID date: keep if _n == 1
replace date = date + 12
rename annualized_return previous_year_annualized_return

merge 1:1 ScrubbedID date using "$temp/collapse2.dta"
keep if _m == 3

bys ScrubbedID: gen expected_assets = total_assets[_n-1] * previous_year_annualized_return
gen contributions = total_assets - expected_assets
gen diff_assets = (total_assets - expected_assets) / expected_assets 

gen lower_value_flag = diff_asset < -.05

replace date = 1960+date/12
gen age = AgeasofNov2018 - (2018 - date)
assert !missing(age)
gen under60 = age < 60

binscatter lower_value_flag year ///
, by(under60) ylab(,nogrid) linetype(none) ///
legend(label(1 "60 and over") label(2 "Under 60")) ///
ytitle(Share with assets 5%+ lower than expected)
graph export "$output/72 - Lower than expected assets.pdf", replace

binscatter contributions year ///
, by(under60) ylab(,nogrid) linetype(none) ///
legend(label(1 "60 and over") label(2 "Under 60")) ytitle("Contributions/withdrawals")
graph export "$output/75 - Contributions by age and year.pdf", replace




























