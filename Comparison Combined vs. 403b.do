/*
Guardrails ORP + 403b vs. 403b only 
PD
*/


{ // setup
clear all

cap log close

global home "C:/Users/ylsta/Dropbox/Retirement Menu Design"

global input "$home/code/STATA -- ZS/Input"
global temp "$home/code/STATA -- ZS/Temp_ORP"
global code "$home/code/STATA -- ZS/Code PD"
global output "$home/code/STATA -- ZS/Output_ORP"
global log "$home/code/STATA -- ZS/Log"

sysdir set PERSONAL "$code/ado"
//set scheme zrs, perm
set more off, perm		

global color_p2 = "86 180 233"
global color_p3 = "230 159 0"
global color_p4 = "0 205 150"


graph set window fontface "Times New Roman"

log using "$log/Analysis", replace

set maxvar 20000

}


{ // setup
clear all

cap log close

global home_zs "C:/Users/ylsta/Dropbox/Retirement Menu Design"

global input_zs "$home/code/STATA -- ZS/Input"
global temp_zs "$home/code/STATA -- ZS/Temp"
global code_zs "$home/code/STATA -- ZS/Code"
global output_zs "$home/code/STATA -- ZS/Output"
global log_zs "$home/code/STATA -- ZS/Log"

sysdir set PERSONAL "$code/ado"
//set scheme zrs, perm
set more off, perm		

global color_p2 = "86 180 233"
global color_p3 = "230 159 0"
global color_p4 = "0 205 150"


graph set window fontface "Times New Roman"

log using "$log/Analysis", replace

set maxvar 20000

}

{ // set levels that flag overweighting
global tot_mm_lev = .2
global ind_sec_lev = .1
global ind_gold_lev = .1
global tot_sec_lev = .5	
global intl_eq_perc = .2
global exp_ratio_cap = .0075

}

use "$temp/collapse2_combined.dta", clear

gen combined = 1

// Merge in Crosswalk that tells us which individuals have ORP accounts 

preserve 

use "$temp\SSN_ID_cross.dta", replace 
gen orp = 1 
rename ScrubbedSSN ScrubbedID 
drop if ScrubbedID == .
drop id 
save "$temp\orp_id", replace

restore 

merge m:1 ScrubbedID using "$temp\orp_id.dta"

keep if orp == 1

gen RMSD = sqrt(_rmse)

gen new = 1 

// Append old data (Only 403b plans)

append using "$temp_zs/collapse2_combined"
replace new = 0 
// Compare RMSD 

replace orp = 0 if orp == .
replace RMSD = sqrt(_rmse)
replace combined = 0 if combined == .

reg RMSD combined

format date 

// pre streamlining period--only combined observations (403b + ORP); two obs. 1-RMSD in 403b 2-RMSD in ORP + 403b 
// proportion of people whose RMSD drops after combining plans =/= 50% 


*** NEW DATA 

use "$temp/collapse2_combined.dta", clear

gen date_text = string(date, "%td")

keep if pre == 1
keep if date_text == "03nov1961"

// Merge in Crosswalk that tells us which individuals have ORP accounts 

preserve 

use "$temp\SSN_ID_cross.dta", replace //crosswalk from SSN to ID (final)
drop if ScrubbedSSN == .
gen orp = 1 
drop ScrubbedSSN
rename id ScrubbedID 
save "$temp\orp_id", replace

restore 

merge 1:1 ScrubbedID using "$temp\orp_id.dta"

replace orp = 0 if orp == . // identify non-orp obs to delete; housekeeping mainly 
keep if _m == 3 // drops empty rows with no information (ScrubbedIDs that are in the crosswalk but do not match)

drop _merge 

gen combined = 1  

gen id = ScrubbedID

gen new = 1 

save "$temp/new_collapse", replace

*** OLD DATA 

use "$temp_zs/collapse2_combined", replace // 403b only 

gen date_text = string(date, "%td")

keep if pre == 1
keep if date_text == "03nov1961"

gen new = 0

preserve 

use "$temp\SID_ID_cross.dta", replace //crosswalk from SSID (old) to new SSID (new) 
sort ScrubbedID
drop if ScrubbedID == .
//gen orp = 1 
//drop ScrubbedSSN
//rename id ScrubbedID 
save "$temp\old_new_id", replace

restore 

merge 1:1 ScrubbedID using "$temp\old_new_id.dta"

keep if _merge == 3

replace ScrubbedID = id
drop id 

sort ScrubbedID

drop _m 

save "$temp/old_collapse", replace 

*** Merge NEW and OLD 

use "$temp/old_collapse", replace

append using "$temp/new_collapse"

sort ScrubbedID

replace orp = 0 if orp == .

by ScrubbedID, sort: gen nvals = _n == 1 
egen unique_id = sum(nvals) 
egen matched = min(nvals), by(ScrubbedID)
keep if matched == 0

gen RMSD = sqrt(_rmse)

local outcomes RMSD annized_five_yr_ret total_assets

foreach var of local outcomes {
	
	ttest `var', by(new)
	
}

label var annized_five_yr_ret "5 year return net"
label var total_assets "Total Assets"

local summary_vars "RMSD annized_five_yr_ret total_assets RoundedSalary"
sum `summary_vars'

/*
drop if new == 0
drop if total_assets < 50000
*/
eststo mandatory: quietly estpost summarize ///
    `summary_vars' if new == 0
eststo permissive: quietly estpost summarize ///
    `summary_vars' if new == 1
eststo diff: quietly estpost ttest ///
    `summary_vars', by(new) unequal

esttab mandatory permissive diff using "$output\comparison_orp.rtf", replace ///
	cells("mean(pattern(1 1 0) fmt(2) label(Mean)) b(star pattern(0 0 1) fmt(2) label(Difference))") ///
	modelwidth(20) ///
label                               ///
	title("ORP Participants (Old vs. New) (Comparison)")       ///
	nonumbers mtitles("Old" "New" "T-Test")  ///
	addnote("Note: *p<0.10, **p<0.05, ***p<0.01") /// 
star(* 0.10 ** 0.05 *** 0.01)
