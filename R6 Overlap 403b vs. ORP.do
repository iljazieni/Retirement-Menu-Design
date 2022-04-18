*** ORP 403b Overalp  

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

merge m:1 ScrubbedID using "$temp\orp_id.dta"

replace orp = 0 if orp == .

ttest total_assets, by(orp) // orp accounts are almost 2x are size 

drop if _m == 2



// ******* WITHIN *******//

use "$temp/collapse2_combined.dta", clear

keep if date == 672
merge m:1 ScrubbedID using "$temp\orp_id.dta"
drop if _m == 2

replace orp = 0 if orp == .

ttest total_assets, by(orp)

gen total_assets_combined = total_assets

gen new = 1 

preserve 

use "$temp_zs/collapse2_combined", clear
keep if date == 672
gen new = 0
merge 1:1 ScrubbedID using "$temp\old_new_id.dta"
keep if _merge == 3
replace ScrubbedID = id
drop id 
sort ScrubbedID
drop _m 
save "$temp/old_collapsed", replace // filtered version of old data

restore 

append using "$temp/old_collapsed"

sort Scr

egen orp_combined = max(orp), by(Scr)

ttest total_assets if new == 0, by(orp_combined)
ttest total_assets if new == 1, by(orp_combined)

// crosswalking based on demographics-->gender, age, salary, start date, termination date. 