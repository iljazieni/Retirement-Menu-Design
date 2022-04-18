// sector fund individual guardrail


use "$temp/guard_intrm_onlytdf_sector_temp", clear

collapse (sum) port_weight, by(ScrubbedID Fund crsp_fundno crsp_fundno_orig date)

// merge in additional fund data
merge m:1 date crsp_fundno using "$temp/cashbond"
drop if _m == 2
drop _m 
merge m:1 Fund using "$temp/sectorfunds"
assert _m != 1
drop if _m != 3
drop _m

replace intl_share_of_equities = 0 if missing(intl_share_of_equities) & equities > 0
gen intl_equity_share = intl_share_of_equities*equities
// define international equities as equity funds that are > 50% international
gen intl_equity_fund = (equity == 1 & intl_share_of_equities > .5)

// merge in guardrails flags
merge m:1 ScrubbedID using "$temp/guardrails flags"
assert _m == 3 if date == 672
drop _m


save "$temp/guard_intrm_onlytdf_sector", replace




