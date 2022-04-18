*** Replicating Fidelity Fiduciary Analysis from East Bay Report 

use "$temp/collapse2_combined.dta", clear

keep if inlist(date,672)

gen age = AgeasofNov2018 - 2

scatter equities AgeasofNov2018, msize(tiny) msymbol(o) mcolor("$color_p2") ///
	title("Equity Share by Participant Age") ///
	note("xx", size(tiny)) ylabel(,nogrid) ytitle(Equity Share) xtitle(Age) 

** Age-Equities Scatter with Guardrails 

use "$temp/cleaning_step_one.dta", clear

keep if inlist(date, 672)

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

sort Age

egen equities_id = max(equities), by(Scr)
egen tdf_equities_id = max(tdf_equities), by(Scr)

duplicates drop Scr, force

twoway (scatter equities AgeasofNov2018, msize(tiny) msymbol(o) mcolor("$color_p1")) ///
	   (scatter tdf_equities AgeasofNov2018, msize(tiny) msymbol(o) mcolor("$color_p3") ///
	title("Equity Share by Participant Age") ///
	note("xx", size(tiny)) ylabel(,nogrid) ytitle(Equity Share) xtitle(Age)) 

gen upper_bound = tdf_equities + 0.1 
gen lower_bound = tdf_equities - 0.1

twoway (scatter equities AgeasofNov2018, msize(tiny) msymbol(o) mcolor("$color_p1")) ///
		(line lower_bound AgeasofNov2018, msize(tiny) msymbol(o) mcolor("$color_p3")) ///
	   (line upper_bound AgeasofNov2018, msize(tiny) msymbol(o) mcolor("$color_p3") ///
	title("Equity Share by Participant Age") ///
	note("xx", size(tiny)) ylabel(,nogrid) ytitle(Equity Share) xtitle(Age)) 

gen upper_bound2 = tdf_equities * 2 
replace upper_bound2 = 1 if upper_bound2 > 1
gen lower_bound2 = tdf_equities / 2

twoway (scatter equities AgeasofNov2018, msize(tiny) msymbol(o) mcolor("$color_p1")) ///
		(line lower_bound2 AgeasofNov2018, msize(tiny) msymbol(o) mcolor("$color_p3")) ///
	   (line upper_bound2 AgeasofNov2018, msize(tiny) msymbol(o) mcolor("$color_p3") ///
	title("Equity Share by Participant Age") ///
	note("xx", size(tiny)) ylabel(,nogrid) ytitle(Equity Share) xtitle(Age)) 

** Risk-Return

use "$temp/collapse2_combined", clear
keep if inlist(date, 672)

// risk-return for all IDs and TDF-holders 

gen tdf_holder = cond(share_tdf16 > 0.99, 1, 0)

twoway (scatter return_used var_used if tdf_holder == 0 & var_used < 0.04, msize(tiny) msymbol(o) mcolor("$color_p1")) ///
	   (scatter return_used var_used if tdf_holder == 1 & var_used < 0.04, msize(tiny) msymbol(o) mcolor("$color_p3") ///
	title("Risk-Return (2016-17)") ///
	note("xx", size(tiny)) ylabel(,nogrid) ytitle(Return) xtitle(Risk)) 

// select risk-retun for ppl that are fully in TDFs 

preserve 

use "$temp/collapse2_combined", clear
keep if inlist(date, 672)
keep Scr fid_tdf_share
save "$temp/fid_tdf_100", replace

restore 

preserve 

use "$temp/cleaning_step_one.dta", clear
keep if inlist(date, 672)
keep if port_weight == 1

gen fid_year = substr(Fund, -4, 4)
destring fid_year, force replace

gen van_tdf1 = (strpos(Fund, "VANG INST TR") > 0 | strpos(Fund, "VANG TARGET RET") > 0)

gen fid_right_tdf = cond(retirement_target == fid_year, 1, 0)

keep Scr fid_right_tdf retirement_target van_tdf1

save "$temp/fid_tdf", replace

restore

// combine the two dataset 

use "$temp/collapse2_combined", clear

keep if inlist(date, 672)

merge 1:m Scr using "$temp/fid_tdf"
replace fid_right_tdf = 0 if fid_right_tdf == .
drop if _m == 2

gen age = AgeasofNov2018 - 2 

gen risk = var_used   
gen ret = return_used 

gen age30 = cond(age < 35, 1, 0)
gen age40 = cond(age > 34 & age < 45, 1, 0)
gen age50 = cond(age > 44 & age < 55, 1, 0)
gen age60 = cond(age > 54 & age < 65, 1, 0)
gen age70 = cond(age > 64, 1, 0)
gen age45 = cond(age > 44, 1, 0)

foreach i of numlist 30 40 50 60 70 45 {
    
	gen risk`i'_helper = risk if age == `i' & fid_right_tdf == 1
	egen risk`i' = max(risk`i') 
	drop risk`i'_helper
	
	gen ret`i'_helper = ret if age == `i' & fid_right_tdf == 1
	egen ret`i' = max(ret`i') 
	drop ret`i'_helper
	
}

drop if fid_right_tdf == 1 
drop if van_tdf1 == 1 

foreach i of numlist 30 40 50 60 70 45 {

	drop if risk == risk`i'
	drop if ret == ret`i'
	
}

foreach i of numlist 30 40 50 60 70 45 {
    
	gen lh`i' = 0 if age`i' == 1 
	replace lh`i' = 1 if risk < risk`i' & ret > ret`i' & lh`i' == 0

	gen ll`i' = 0 if age`i' == 1  
	replace ll`i' = 1 if risk < risk`i' & ret < ret`i' & ll`i' == 0

	gen hh`i' = 0 if age`i' == 1 
	replace hh`i' = 1 if risk > risk`i' & ret > ret`i' & hh`i' == 0

	gen hl`i' = 0 if age`i' == 1 
	replace hl`i' = 1 if risk > risk`i' & ret < ret`i' & hl`i' == 0

}

gen check30 = 1 if lh30 | ll30 | hl30 | hh30

/*
foreach i of numlist 30 40 50 60 70 {
    
	gen lh`i' = . 
	replace lh`i' = 1 if risk < risk`i' & ret > ret`i' & age`i' == 1
	replace lh`i' = 0 if age`i' == 1 & lh`i' == .

	gen ll`i' = . 
	replace ll`i' = 1 if risk < risk`i' & ret < ret`i' & age`i' == 1
	replace ll`i' = 0 if age`i' == 1 & ll`i' == .
	
	gen hh`i' = . 
	replace hh`i' = 1 if risk > risk`i' & ret > ret`i' & age`i' == 1
	replace hh`i' = 0 if age`i' == 1 & hh`i' == .
	
	gen hl`i' = . 
	replace hl`i' = 1 if risk > risk`i' & ret < ret`i' & age`i' == 1
	replace hl`i' = 0 if age`i' == 1 & hl`i' == .

}
*/

gen lh = .
foreach i of numlist 30 40 50 60 70 {
	
	replace lh = 1 if risk < risk`i' & ret > ret`i' & age`i' == 1
	replace lh = 0 if age`i' == 1 & lh == .
	
}

gen ll = .
foreach i of numlist 30 40 50 60 70 {
	
	replace ll = 1 if risk < risk`i' & ret < ret`i' & age`i' == 1
	replace ll = 0 if age`i' == 1 & ll == .
	
}

gen hh = .
foreach i of numlist 30 40 50 60 70 {
	
	replace hh = 1 if risk > risk`i' & ret > ret`i' & age`i' == 1
	replace hh = 0 if age`i' == 1 & hh == .
	
}

gen hl = .
foreach i of numlist 30 40 50 60 70 {
	
	replace hl = 1 if risk > risk`i' & ret < ret`i' & age`i' == 1
	replace hl = 0 if age`i' == 1 & hl == .
	
}

foreach var of varlist age30 age40 age50 age60 age70 {
	
	egen n`var' = count(`var') if `var' == 1
	
}


sum hl if age45 == 1

** Output Table ** 

putexcel set "$output/83 - Risk Return Table.xlsx", replace

putexcel C1:D1, hcenter merge
putexcel C2:G2, hcenter merge
putexcel A2:B2, hcenter merge

putexcel C1 = "Risk Return Table"
putexcel A2 = "Category"

putexcel A3 = "Risk"
putexcel A4 = "Lower"
putexcel A5 = "Lower"
putexcel A6 = "Higher"
putexcel A7 = "Higher"

putexcel B3 = "Return"
putexcel B4 = "Higher"
putexcel B5 = "Lower"
putexcel B6 = "Higher"
putexcel B7 = "Lower"

putexcel C2 = "Participants in each Category, by Age and Overall"

sum age30
local mean = string(r(mean))
local mean = `mean' * 100
local mean : di %5.2f `mean'

putexcel C3 = "25-35 (`mean'%)", hcenter

sum age40
local mean = string(r(mean))
local mean = `mean' * 100
local mean : di %5.2f `mean'

putexcel D3 = "35-45 (`mean'%)", hcenter

sum age50
local mean = string(r(mean))
local mean = `mean' * 100
local mean : di %5.2f `mean'

putexcel E3 = "45-55 (`mean'%)", hcenter

sum age60
local mean = string(r(mean))
local mean = `mean' * 100
local mean : di %5.2f `mean'

putexcel F3 = "55-65 (`mean'%)", hcenter

sum age70
local mean = string(r(mean))
local mean = `mean' * 100
local mean : di %5.2f `mean'

putexcel G3 = "65-75 (`mean'%)", hcenter

putexcel H3 = "Overall"

local i = 4

foreach x in "lh30" "ll30" "hh30" "hl30" {

	sum `x' 
	local mean = string(r(mean))
	di `mean'
	putexcel C`i' = `mean'	
	local i=`i'+1
	
}

local i = 4

foreach x in "lh40" "ll40" "hh40" "hl40" {

	sum `x' 
	local mean = string(r(mean))
	putexcel D`i' = `mean'	
	local i=`i'+1
	
}

local i = 4

foreach x in "lh50" "ll50" "hh50" "hl50" {

	sum `x' 
	local mean = string(r(mean))
	putexcel E`i' = `mean'	
	local i=`i'+1
	
}

local i = 4

foreach x in "lh60" "ll60" "hh60" "hl60" {

	sum `x' 
	local mean = string(r(mean))
	putexcel F`i' = `mean'	
	local i=`i'+1
	
}

local i = 4

foreach x in "lh70" "ll70" "hh70" "hl70" {

	sum `x' 
	local mean = string(r(mean))
	putexcel G`i' = `mean'	
	local i=`i'+1
	
}

local i = 4

foreach x in "lh" "ll" "hh" "hl" {

	sum `x' 
	local mean = string(r(mean))
	putexcel H`i' = `mean'	
	local i=`i'+1
	
}

putexcel close


*** TABLE 2 (only guardrail) ***

// combine the two dataset 

use "$temp/collapse2_combined", clear

keep if inlist(date, 672)

merge 1:m Scr using "$temp/fid_tdf"
replace fid_right_tdf = 0 if fid_right_tdf == .
drop if _m == 2

gen age = AgeasofNov2018 - 2 

gen risk = var_used   
gen ret = return_used 

gen age30 = cond(age < 35, 1, 0)
gen age40 = cond(age > 34 & age < 45, 1, 0)
gen age50 = cond(age > 44 & age < 55, 1, 0)
gen age60 = cond(age > 54 & age < 65, 1, 0)
gen age70 = cond(age > 64, 1, 0)
gen age45 = cond(age > 44, 1, 0)

foreach i of numlist 30 40 50 60 70 45 {
    
	gen risk`i'_helper = risk if age == `i' & fid_right_tdf == 1
	egen risk`i' = max(risk`i') 
	drop risk`i'_helper
	
	gen ret`i'_helper = ret if age == `i' & fid_right_tdf == 1
	egen ret`i' = max(ret`i') 
	drop ret`i'_helper
	
}

drop if fid_right_tdf == 1 
drop if van_tdf1 == 1 
drop if guardrail_not_intl == 0
drop if smart == 1 


foreach i of numlist 30 40 50 60 70 45 {

	drop if risk == risk`i'
	drop if ret == ret`i'
	
}

foreach i of numlist 30 40 50 60 70 45 {
    
	gen lh`i' = 0 if age`i' == 1 
	replace lh`i' = 1 if risk < risk`i' & ret > ret`i' & lh`i' == 0

	gen ll`i' = 0 if age`i' == 1  
	replace ll`i' = 1 if risk < risk`i' & ret < ret`i' & ll`i' == 0

	gen hh`i' = 0 if age`i' == 1 
	replace hh`i' = 1 if risk > risk`i' & ret > ret`i' & hh`i' == 0

	gen hl`i' = 0 if age`i' == 1 
	replace hl`i' = 1 if risk > risk`i' & ret < ret`i' & hl`i' == 0

}

gen check30 = 1 if lh30 | ll30 | hl30 | hh30
assert check30 == 1 

/*
foreach i of numlist 30 40 50 60 70 {
    
	gen lh`i' = . 
	replace lh`i' = 1 if risk < risk`i' & ret > ret`i' & age`i' == 1
	replace lh`i' = 0 if age`i' == 1 & lh`i' == .

	gen ll`i' = . 
	replace ll`i' = 1 if risk < risk`i' & ret < ret`i' & age`i' == 1
	replace ll`i' = 0 if age`i' == 1 & ll`i' == .
	
	gen hh`i' = . 
	replace hh`i' = 1 if risk > risk`i' & ret > ret`i' & age`i' == 1
	replace hh`i' = 0 if age`i' == 1 & hh`i' == .
	
	gen hl`i' = . 
	replace hl`i' = 1 if risk > risk`i' & ret < ret`i' & age`i' == 1
	replace hl`i' = 0 if age`i' == 1 & hl`i' == .

}
*/
gen lh = .
foreach i of numlist 30 40 50 60 70 {
	
	replace lh = 1 if risk < risk`i' & ret > ret`i' & age`i' == 1
	replace lh = 0 if age`i' == 1 & lh == .
	
}

gen ll = .
foreach i of numlist 30 40 50 60 70 {
	
	replace ll = 1 if risk < risk`i' & ret < ret`i' & age`i' == 1
	replace ll = 0 if age`i' == 1 & ll == .
	
}

gen hh = .
foreach i of numlist 30 40 50 60 70 {
	
	replace hh = 1 if risk > risk`i' & ret > ret`i' & age`i' == 1
	replace hh = 0 if age`i' == 1 & hh == .
	
}

gen hl = .
foreach i of numlist 30 40 50 60 70 {
	
	replace hl = 1 if risk > risk`i' & ret < ret`i' & age`i' == 1
	replace hl = 0 if age`i' == 1 & hl == .
	
}

gen check = 1 if lh | ll | hl | hh
assert check == 1 


** Output Table ** 

putexcel set "$output/84 - Risk Return Table Only Violators.xlsx", replace

putexcel C1:D1, hcenter merge
putexcel C2:G2, hcenter merge
putexcel A2:B2, hcenter merge

putexcel C1 = "Risk Return Table (Only Guardrail Violators)"
putexcel A2 = "Category"

putexcel A3 = "Risk"
putexcel A4 = "Lower"
putexcel A5 = "Lower"
putexcel A6 = "Higher"
putexcel A7 = "Higher"

putexcel B3 = "Return"
putexcel B4 = "Higher"
putexcel B5 = "Lower"
putexcel B6 = "Higher"
putexcel B7 = "Lower"

putexcel C2 = "Participants in each Category, by Age and Overall"

sum age30
local mean = string(r(mean))
local mean = `mean' * 100
local mean : di %5.2f `mean'

putexcel C3 = "25-35 (`mean'%)", hcenter

sum age40
local mean = string(r(mean))
local mean = `mean' * 100
local mean : di %5.2f `mean'

putexcel D3 = "35-45 (`mean'%)", hcenter

sum age50
local mean = string(r(mean))
local mean = `mean' * 100
local mean : di %5.2f `mean'

putexcel E3 = "45-55 (`mean'%)", hcenter

sum age60
local mean = string(r(mean))
local mean = `mean' * 100
local mean : di %5.2f `mean'

putexcel F3 = "55-65 (`mean'%)", hcenter

sum age70
local mean = string(r(mean))
local mean = `mean' * 100
local mean : di %5.2f `mean'

putexcel G3 = "65-75 (`mean'%)", hcenter

putexcel H3 = "Overall"

local i = 4

foreach x in "lh30" "ll30" "hh30" "hl30" {

	sum `x' 
	local mean = string(r(mean))
	di `mean'
	putexcel C`i' = `mean'	
	local i=`i'+1
	
}

local i = 4

foreach x in "lh40" "ll40" "hh40" "hl40" {

	sum `x' 
	local mean = string(r(mean))
	putexcel D`i' = `mean'	
	local i=`i'+1
	
}

local i = 4

foreach x in "lh50" "ll50" "hh50" "hl50" {

	sum `x' 
	local mean = string(r(mean))
	putexcel E`i' = `mean'	
	local i=`i'+1
	
}

local i = 4

foreach x in "lh60" "ll60" "hh60" "hl60" {

	sum `x' 
	local mean = string(r(mean))
	putexcel F`i' = `mean'	
	local i=`i'+1
	
}

local i = 4

foreach x in "lh70" "ll70" "hh70" "hl70" {

	sum `x' 
	local mean = string(r(mean))
	putexcel G`i' = `mean'	
	local i=`i'+1
	
}

local i = 4

foreach x in "lh" "ll" "hh" "hl" {

	sum `x' 
	local mean = string(r(mean))
	putexcel H`i' = `mean'	
	local i=`i'+1
	
}

putexcel close

*** TABLE 2 (only guardrail) **

use "$temp/collapse2_combined", clear

keep if inlist(date, 672)

merge 1:m Scr using "$temp/fid_tdf"
replace fid_right_tdf = 0 if fid_right_tdf == .
drop if _m == 2

gen age = AgeasofNov2018 - 2 

gen risk = var_used   
gen ret = return_used 

gen age30 = cond(age < 35, 1, 0)
gen age40 = cond(age > 34 & age < 45, 1, 0)
gen age50 = cond(age > 44 & age < 55, 1, 0)
gen age60 = cond(age > 54 & age < 65, 1, 0)
gen age70 = cond(age > 64, 1, 0)

foreach i of numlist 30 40 50 60 70 {
    
	gen risk`i'_helper = risk if age == `i' & fid_right_tdf == 1
	egen risk`i' = max(risk`i') 
	drop risk`i'_helper
	
	gen ret`i'_helper = ret if age == `i' & fid_right_tdf == 1
	egen ret`i' = max(ret`i') 
	drop ret`i'_helper
	
}

drop if smart 
drop if fid_right_tdf == 1 
drop if van_tdf1 == 1 
drop if guardrail_not_intl == 1

foreach i of numlist 30 40 50 60 70 {

	drop if risk == risk`i'
	drop if ret == ret`i'
	
}

foreach i of numlist 30 40 50 60 70 {
    
	gen lh`i' = 0 if age`i' == 1 
	replace lh`i' = 1 if risk < risk`i' & ret > ret`i' & lh`i' == 0

	gen ll`i' = 0 if age`i' == 1  
	replace ll`i' = 1 if risk < risk`i' & ret < ret`i' & ll`i' == 0

	gen hh`i' = 0 if age`i' == 1 
	replace hh`i' = 1 if risk > risk`i' & ret > ret`i' & hh`i' == 0

	gen hl`i' = 0 if age`i' == 1 
	replace hl`i' = 1 if risk > risk`i' & ret < ret`i' & hl`i' == 0

}

gen check30 = 1 if lh30 | ll30 | hl30 | hh30

/*
foreach i of numlist 30 40 50 60 70 {
    
	gen lh`i' = . 
	replace lh`i' = 1 if risk < risk`i' & ret > ret`i' & age`i' == 1
	replace lh`i' = 0 if age`i' == 1 & lh`i' == .

	gen ll`i' = . 
	replace ll`i' = 1 if risk < risk`i' & ret < ret`i' & age`i' == 1
	replace ll`i' = 0 if age`i' == 1 & ll`i' == .
	
	gen hh`i' = . 
	replace hh`i' = 1 if risk > risk`i' & ret > ret`i' & age`i' == 1
	replace hh`i' = 0 if age`i' == 1 & hh`i' == .
	
	gen hl`i' = . 
	replace hl`i' = 1 if risk > risk`i' & ret < ret`i' & age`i' == 1
	replace hl`i' = 0 if age`i' == 1 & hl`i' == .

}
*/
gen lh = .
foreach i of numlist 30 40 50 60 70 {
	
	replace lh = 1 if risk < risk`i' & ret > ret`i' & age`i' == 1
	replace lh = 0 if age`i' == 1 & lh == .
	
}

gen ll = .
foreach i of numlist 30 40 50 60 70 {
	
	replace ll = 1 if risk < risk`i' & ret < ret`i' & age`i' == 1
	replace ll = 0 if age`i' == 1 & ll == .
	
}

gen hh = .
foreach i of numlist 30 40 50 60 70 {
	
	replace hh = 1 if risk > risk`i' & ret > ret`i' & age`i' == 1
	replace hh = 0 if age`i' == 1 & hh == .
	
}

gen hl = .
foreach i of numlist 30 40 50 60 70 {
	
	replace hl = 1 if risk > risk`i' & ret < ret`i' & age`i' == 1
	replace hl = 0 if age`i' == 1 & hl == .
	
}


** Output Table ** 

putexcel set "$output/85 - Risk Return Table Only Non-Violators.xlsx", replace

putexcel C1:D1, hcenter merge
putexcel C2:G2, hcenter merge
putexcel A2:B2, hcenter merge

putexcel C1 = "Risk Return Table (Only Non-Violators)"
putexcel A2 = "Category"

putexcel A3 = "Risk"
putexcel A4 = "Lower"
putexcel A5 = "Lower"
putexcel A6 = "Higher"
putexcel A7 = "Higher"

putexcel B3 = "Return"
putexcel B4 = "Higher"
putexcel B5 = "Lower"
putexcel B6 = "Higher"
putexcel B7 = "Lower"

putexcel C2 = "Participants in each Category, by Age and Overall"

sum age30
local mean = string(r(mean))
local mean = `mean' * 100
local mean : di %5.2f `mean'

putexcel C3 = "25-35 (`mean'%)", hcenter

sum age40
local mean = string(r(mean))
local mean = `mean' * 100
local mean : di %5.2f `mean'

putexcel D3 = "35-45 (`mean'%)", hcenter

sum age50
local mean = string(r(mean))
local mean = `mean' * 100
local mean : di %5.2f `mean'

putexcel E3 = "45-55 (`mean'%)", hcenter

sum age60
local mean = string(r(mean))
local mean = `mean' * 100
local mean : di %5.2f `mean'

putexcel F3 = "55-65 (`mean'%)", hcenter

sum age70
local mean = string(r(mean))
local mean = `mean' * 100
local mean : di %5.2f `mean'

putexcel G3 = "65-75 (`mean'%)", hcenter

putexcel H3 = "Overall"

local i = 4

foreach x in "lh30" "ll30" "hh30" "hl30" {

	sum `x' 
	local mean = string(r(mean))
	di `mean'
	putexcel C`i' = `mean'	
	local i=`i'+1
	
}

local i = 4

foreach x in "lh40" "ll40" "hh40" "hl40" {

	sum `x' 
	local mean = string(r(mean))
	putexcel D`i' = `mean'	
	local i=`i'+1
	
}

local i = 4

foreach x in "lh50" "ll50" "hh50" "hl50" {

	sum `x' 
	local mean = string(r(mean))
	putexcel E`i' = `mean'	
	local i=`i'+1
	
}

local i = 4

foreach x in "lh60" "ll60" "hh60" "hl60" {

	sum `x' 
	local mean = string(r(mean))
	putexcel F`i' = `mean'	
	local i=`i'+1
	
}

local i = 4

foreach x in "lh70" "ll70" "hh70" "hl70" {

	sum `x' 
	local mean = string(r(mean))
	putexcel G`i' = `mean'	
	local i=`i'+1
	
}

local i = 4

foreach x in "lh" "ll" "hh" "hl" {

	sum `x' 
	local mean = string(r(mean))
	putexcel H`i' = `mean'	
	local i=`i'+1
	
}

putexcel close
