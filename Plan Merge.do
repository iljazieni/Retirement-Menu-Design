//////////////////////////////////////////////////////
//This do file merges the 403b and ORP participants
//into a single list and creates a new id with a mapping to 
//the old id.  It drops ambiguous accounts with no clear match.
//
//It takes as input the raw plan data:
//  "403b Data.xlsx"
//  "ORP Data.xlsx"
//
//It's output is a file that can be used to generate new ids 
//for the two plan datasets appended together.  (See end of file below
//for details."
//////////////////////////////////////////////////////


//////////////////////////////////////////////////////
//Create a list of 403b account with identifying info
//////////////////////////////////////////////////////

clear
import excel "$input\PlanData.xlsx", sheet("Sheet1") firstrow clear

//Collapse on the identifying variables
gen t = 0
collapse t, by( ScrubbedID StatusinFidelity AgeasofNov2018 Gender MaritialStatus RoundedSalary AcaMCFlag HireDate TerminationDate)

//Drop entries with conflicting idetifiers 
duplicates drop ScrubbedID, force

//exclude medical center employees
drop if AcaMCFlag == "MC" // Academic vs. Medical Center plan; we drop the doctors unlike before (Zach's code)
drop t

gen Age = AgeasofNov2018 
rename MaritialStatus MaritalStatus

//standardize missing values
replace HireDate = 0 if missing(HireDate)
replace Gender = "NA" if missing(Gender)
replace Gender = "NA" if Gender == "0"
replace MaritalStatus = "NA" if missing(MaritalStatus)
replace MaritalStatus = "NA" if MaritalStatus == "0"
replace RoundedSalary = 0 if missing(RoundedSalary)
replace AcaMCFlag = "NA" if missing(AcaMCFlag)
replace AcaMCFlag = "NA" if AcaMCFlag == "0"


//We want some variables seperately named to test matches
gen Salary_403b = RoundedSalary
gen Gender_403b = Gender
gen MaritalStatus_403b  =MaritalStatus
gen TerminationDate_403b  =TerminationDate
gen Status_ORP = StatusinFidelity 
gen Status = StatusinFidelity

//drop if we don't know hire date
drop if HireDate == mdy(1,1,1960)

//This is a list of all relevant 403b account holders 
save "$temp\403b_accounts.dta", replace
use "$temp\403b_accounts.dta", replace // 10,661

//////////////////////////////////////////////////////
//Create a list of ORP account with identifying info
//////////////////////////////////////////////////////

clear
import excel "$input\ORP Data.xlsx", sheet("Sheet1") firstrow clear

//Collapse on the identifying variables
gen t = 0
collapse t, by( ScrubbedSSN Status CalculatedAgeDC Gender MaritalStatus RoundedSalary ACAMCFlag HireDate TerminationDate)

//make names consistent
rename  ACAMCFlag AcaMCFlag

//standardize missing values
replace HireDate = 0 if missing(HireDate)
replace Gender = "NA" if missing(Gender)
replace MaritalStatus = "NA" if missing(MaritalStatus)
replace MaritalStatus = "NA" if MaritalStatus == "0"
replace RoundedSalary = 0 if missing(RoundedSalary)
replace AcaMCFlag = "NA" if missing(AcaMCFlag)
replace AcaMCFlag = "ACA" if AcaMCFlag == "Aca"

//We want some variables seperately named to test matches
gen  ORPSalary = RoundedSalary 
gen Age = CalculatedAgeDC 
gen Gender_ORP = Gender
gen MaritalStatus_ORP  =MaritalStatus
gen TerminationDate_ORP  =TerminationDate
gen Status_ORP = Status 

//exclude medical center employees
drop if AcaMCFlag == "MC"
drop t

//drop if we don't know hire date
drop if HireDate == mdy(1,1,1960)

//This is a list of all relevant ORP account holders 
save "$temp\ORP_accounts.dta", replace
use "$temp\ORP_accounts.dta", replace // 3,886


//////////////////////////////////////////////////////
//Generate a list of overlapping accounts 
//////////////////////////////////////////////////////

use "$temp\ORP_accounts.dta", replace

//join on the subset of ID variables that are reliable (not salary and age)
joinby HireDate Status Gender TerminationDate AcaMCFlag using "$temp\403b_accounts.dta", unm(both)
tab _merge
drop _merge

//check for approximate match on salary and age (which could be off a bit)
gen age_diff = abs(CalculatedAgeDC - AgeasofNov2018)
gen salary_diff  =  abs(Salary_403b-ORPSalary)

gen good_match = 0
replace good_match = 1 if age_diff < 2  & salary_diff < 10000
keep if good_match == 1

duplicates tag ScrubbedID, generate(dupID)
duplicates tag ScrubbedSSN, generate(dupSSN)

//save pairs with dups information
save "$temp\temp.dta", replace

drop if dupSSN > 0
drop if dupID > 0

//list of unique pairs
save "$temp\overlapping_accounts.dta", replace
use "$temp\overlapping_accounts.dta", replace // 1,814

//////////////////////////////////////////////////////
//Generate a list of ambiguous matches we will exclude
//////////////////////////////////////////////////////

use "$temp\temp.dta", replace

keep if dupSSN > 0 | dupID > 0 
gen dup_ind = 1 
keep  ScrubbedSSN dup_ind
duplicates drop 

//list of non-unique matches we will drop
save "$temp\drop_these_ambiguous_SSNs.dta", replace

use "$temp\temp.dta", replace
keep if dupSSN > 0 | dupID > 0 
gen dup_ind = 1 
keep  ScrubbedID dup_ind
duplicates drop

//list of non-unique matches we will drop
save "$temp\drop_these_ambiguous_ids.dta", replace

//////////////////////////////////////////////////////
//Construct the new id crosswalk 
//////////////////////////////////////////////////////

//start with overlapping accounts  
use "$temp\overlapping_accounts.dta", replace

//merge in all the 43b accounts
joinby ScrubbedID using "$temp\403b_accounts.dta", unm(both)
tab _merge
drop _merge 

//merge in all the ORP accounts
joinby ScrubbedSSN using "$temp\ORP_accounts.dta", unm(both)
tab _merge
drop _merge 

//drop the ambiguous accounts that might be in both plans
joinby ScrubbedSSN using "$temp\drop_these_ambiguous_SSNs.dta", unm(both)
tab _merge
drop _merge 

joinby ScrubbedID using "$temp\drop_these_ambiguous_ids.dta", unm(both)
tab _merge
drop _merge 

drop if dup_ind == 1

gen id = _n

keep id Scrubbed*

save "$temp\master_id_crosswalk.dta", replace 

preserve 

drop ScrubbedID
save "$temp\SSN_ID_cross.dta", replace

restore 

preserve 

drop ScrubbedSSN
save "$temp\SID_ID_cross.dta", replace

restore 

//////////////////////////////////////////////////////
//Output is a file that maps the new "id" field to 
//existing ScrubbedID and ScrubbedSSN.
//
//To use it, start with the ORP and 403(b) position lists
//(the original data XLSX above) with the fields standardazed
//and append them together.  Make sure that only the ORP entries have 
//ScrubbedSSNs and only the 403b entries have Scrubbed ids when you
//append the data. The appended datasets will be the list of every position in 
//both plans with the identifier from the original data and the other iden
//tifier left missing.
//
//Starting from this dataset, join on the master_id_crosswalk.dta twice
//first by ScrubbedID, then by ScrubbedSSN.  This will 
//assign a new ID to every position in both datasets, and that ID
//will be common to both plans.  
//
//Then Collapse the data on id, fund_id, date, and sum the mkt_values
//so that an investor with positions in the same funds in both accounts
//gets a single position. (Check after this that there are no observations 
//with duplicate id, date, and fund.)
//
//Once this is done, you should be able to rename "id" to "ScrubbedID"
//and run the code as before.  
//////////////////////////////////////////////////////


//////////////////////////////////////////////////////
// Join crosswalk to ORP and Plan Data  
////////////////////////////////////////////////////// 

import excel "$input\ORP Data.xlsx", sheet("Sheet1") firstrow clear

rename CalculatedAgeDC AgeasofNov2018
rename Status StatusinFidelity
rename ACAMCFlag AcaMCFlag
rename MaritalStatus MaritialStatus

// drop if AcaMCFlag == "MC"

gen orp = 1 

by ScrubbedSSN, sort: gen nvals = _n == 1 
egen unique_ssn = sum(nvals) // 4217 

preserve 

import excel "$input\PlanData.xlsx", sheet("Sheet1") firstrow clear
duplicates drop
gen b403 = 1 
save "$temp\plan_data.dta", replace

restore 

append using "$temp\plan_data.dta"

tab orp ScrubbedID
tab b403 ScrubbedSSN


drop orp b403 // no obs. which means only the ORP entries have ScrubbedSSNs and only the 403b entries have Scrubbed ids

//// Individually merge id crosswalk onto ORP and Plan Datasets and then append 

// only joinby ORP

use "$temp\appended_orp_plan.dta", replace

drop FundsHeld

keep if ScrubbedID ~= . // keeps only 403b obs.

joinby ScrubbedID using "$temp\SID_ID_cross.dta" //, unmatched(master)

/*
by id, sort: gen nvals = _n == 1 
egen unique_id = sum(nvals) // 10,661 
*/

save "$temp\sid_id_joined.dta", replace // cross-walk between 403b users (ScrubbedID) and new "id" | 10,611 SSIDs	

// only joinby 403b

use "$temp\appended_orp_plan.dta", replace

drop FundsHeld

keep if ScrubbedSSN ~= .

joinby ScrubbedSSN using "$temp\SSN_ID_cross.dta" //, unmatched(master)

/*
by id, sort: gen nvals = _n == 1 
egen unique_id = sum(nvals) // 3,616 
*/

save "$temp\ssn_id_joined.dta", replace // cross-walk between ORP users (ScrubbedSSN) and new "id" | 10,611 SSIDs	
 
// append 

append using "$temp\sid_id_joined.dta"

save "$temp\id_ssn_sid_joined.dta", replace 

//// Collapse 
 
use "$temp\id_ssn_sid_joined.dta", replace 

sort id Fund CalendarDay

collapse MarketValue (firstnm) HireDate AcaMCFlag FundType Gender MaritialStatus RoundedSalary TerminationDate AgeasofNov2018, by(id Fund CalendarDay)

duplicates drop	// zero obs. 

//drop Scrubbed*

rename id ScrubbedID

save "$temp\orp_plan_merged.dta", replace