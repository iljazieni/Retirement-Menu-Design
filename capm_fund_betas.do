
{ // compute CAPM betas

//format the Rf rate from French's website
import excel "$input/F-F_Research_Data_Factors.xlsx", sheet("F-F_Research_Data_Factors") firstrow clear
replace RF = RF/100
tostring Date, replace
replace Date  = Date + "01"
gen date = date(Date, "YMD")
format date %td
gen month = mofd(date)
format month %tm
gen mktrf = MktRF/100
gen rf = RF/100
keep month mktrf rf
save "$input/rf_rate.dta", replace

use "$temp/fund_returns.dta", replace
joinby month using "$temp/rf_rate.dta"

bys crsp_fundno caldt: gen dup = cond(_N==1,0,_n)
tab dup
drop if dup > 1

isid crsp_fundno caldt

replace mret = mret - rf

asreg  mret mktrf, noc min(36) rmse by(crsp_fundno) window(month 60)

rename _b_mktrf beta

keep crsp_fundno caldt beta

save "$temp/fund_betas.dta", replace
}
