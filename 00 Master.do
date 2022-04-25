/*
Guardrails Master File
ZRS + PD + EI
*/


{ // setup
clear all

cap log close

global home "C:/Users/EI87/Documents/GitHub/Retirement-Menu-Design"
global output "C:/Users/EI87/Dropbox (YLS)/Retirement Menu Design/code/STATA -- ZS/replication_EI"
global input "C:/Users/EI87/Dropbox (YLS)/Retirement Menu Design/code/STATA -- ZS/Input"
global temp "C:/Users/EI87/Dropbox (YLS)/Retirement Menu Design/code/STATA -- ZS/Temp_ORP_EI"

/*global home "C:\Users\iayers\Dropbox (Yale Law School)\Retirement Menu Design"
global input "$home/code/STATA -- ZS/Input"
global code "$home/code/STATA -- ZS/Code EI/relevant code"
global output "$home/code/STATA -- ZS/replication"
 global log "$home/code/STATA -- ZS/Log"
*/
// sysdir set PERSONAL "$code/ado"
//set scheme zrs, perm
set more off, perm

global color_p2 = "gs11"
global color_p3 = "gs1"
global color_p4 = "gs8"


graph set window fontface "Times New Roman"

//log using "$log/Analysis", replace

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

// Replicating Book Results Chapters 4 - 11
do "$home/replication.do"


/*
qui do "$code/01 setup.do" // done

qui do "$code/02 Cleaning Step One.do" // done

qui do "$code/03a Counterfactual Setup -- Joint -- All TDFs.do"
qui do "$code/03b Counterfactual Setup -- Sector -- All TDFs.do"
qui do "$code/03c Counterfactual Setup -- Expense Ratio -- All TDFs.do"
qui do "$code/03d Counterfactual Setup -- Equities Under -- All TDFs.do"
qui do "$code/03e Counterfactual Setup -- Equities Over -- All TDFs.do"
qui do "$code/03f Counterfactual Setup -- Intl Share of Equities -- All TDFs.do"
qui do "$code/03g Counterfactual Setup -- Summarize Share Affected -- All TDFs.do"

qui do "$code/04 Individual Portfolio Moments.do"

qui do "$code/05 Cleaning Step Two.do"

qui do "$code/06 Cleaning Step Three.do"

qui do "$code/08 Reallocation Summary.do"

qui do "$code/09 Overweighting Tables.do"

qui do "$code/10 Fund Types Summary.do"

qui do "$code/11 Guardrails CRRA Analysis.do"

qui do "$code/12 Baseline CRRA Analysis.do"

qui do "$code/13 Testing Factors.do"

qui do "$code/14 Miscellaneous.do"

qui do "$code/15 Participation.do"


cap log close

/** Go to streamlined data --> just look at those funds that are not the affirmative choice participants (look at unaffected portfolios).
