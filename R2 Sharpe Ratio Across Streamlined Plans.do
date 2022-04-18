*** Contracts Student Question -- Sharpe Ratios *****

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

{ // merge in data on plan defaulted
merge m:1 ScrubbedID using "$temp/plan_defaulted17"
replace plan_defaulted17 = 2 if steady_pre == 1
drop _m

merge m:1 ScrubbedID using "$temp/plan_defaulted18"
replace plan_defaulted18 = 2 if steady_pre == 1
drop _m

preserve
	bys ScrubbedID date: gen temp1 = (_n == 1)
	drop if date == 696
	bys ScrubbedID: egen temp2 = total(temp1)
	assert temp2 == 2 if date != 696
	drop temp*
restore
}

la define plan_defaulted17 0 "Streamlined, affirmative choice" ///
	1 "Streamlined, plan-defaulted" ///
	2 "Non-streamlined"

gen temp = (date == 696)
bys ScrubbedID: egen present_2018 = max(temp)
drop temp

//keep if date == 672 & present_2018 == 1

// filter to one observation per person
//bys ScrubbedID: keep if _n == 1

gen affirmative17 = (plan_defaulted17 == 0)
gen defaulted17 = (plan_defaulted17 == 1)
gen non17 = (plan_defaulted17 == 2)

preserve 

use "$temp/collapse2_combined", clear
drop if year == .
keep Scr year sharpe sharpe_fiveyear
keep if sharpe != .

save "$temp/scr_sharpe", replace

restore 

gen year = 2016 if date == 672
replace year = 2017 if date == 684
replace year = 2018 if date == 696

preserve 

keep Scr affirmative17 defaulted17 non17
duplicates drop Scr, force
save "$temp/id_affirm_crosswalk", replace

restore 	

/*
merge m:1 ScrubbedID year using "$temp/scr_sharpe"

egen sharpe_pre_affirm = mean(sharpe) if affirmative == 1
egen sharpe_pre_default = mean(sharpe) if defaulted == 1
egen sharpe_pre_non = mean(sharpe) if non == 1

reg sharpe affirm default if year == 2016
reg sharpe affirm default if year == 2017 

gen treat = cond(affirmative == 1 | defaulted == 1, 1, 0)
gen post = cond(year == 2017, 1, 0)
gen did = treat * post

reg sharpe did

*/
preserve 

use "$temp/testing_pd2", replace

collapse (mean) ret exp_ratio sharpe sharpe_fiveyear, by(Scr year)
drop if sharpe == .

save "$temp/testing_pd3", replace

restore 

sort Scr date

merge m:1 ScrubbedID year using "$temp/testing_pd3"

la var affirmative "Streamlined, affirmative choice"
la var defaulted "Streamlined, plan-defaulted"
la var non "Non-streamlined"
la var date "Date"

gen treat = cond(affirmative == 1 | defaulted == 1, 1, 0)
gen post = cond(year == 2017, 1, 0)
gen did = treat * post

reg sharpe did i.year
reg ret did i.year
reg exp_ratio did i.year

gen treat2 = cond(affirmative == 1, 1, 0)
gen did2 = treat2 * post

gen treat3 = cond(default == 1, 1, 0)
gen did3 = treat3 * post

reg sharpe did2 did3
test did2 = did3

reg ret did2 did3
test did2 = did3

reg exp_ratio did2 did3
test did2 = did3 // significant--default had lower expense ratios 

