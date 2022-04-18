{ // save fund type summary
use "$temp/collapse2_combined.dta", clear
keep if inlist(date,672)
keep ScrubbedID 
tempfile ids_used
save "`ids_used'"

use "$temp/individual_ports.dta", clear 
joinby Fund date using "$temp/fund_returns_series_crosswalk_post.dta" 


// Vanguard 2010 TDF is pushed into Income TDF in 2016, so replace it with Income Fund from 2014 onward (so we will have at least 2 future years of returns data)
replace crsp_fundno = 31290 if (Fund == "OKKK-VANG TARGET RET 2010" & date <= 672 & date >= 648) | (Fund == "OV6N-VANG INST TR 2010" & date == 684)
replace crsp_fundno = 64321 if (Fund == "OKKK-VANG TARGET RET 2010" & date <= 672 & date >= 648)
replace crsp_fundno = 31290 if (Fund == "OV6N-VANG INST TR 2010" & date == 684)
replace Fund = "OSHO-VANG TARGET RET INC" if Fund == "OKKK-VANG TARGET RET 2010" & date <= 672 & date >= 648
replace Fund = "OV6M-VANG INST TR INCOME" if Fund == "OV6N-VANG INST TR 2010" & date == 684

merge m:1 ScrubbedID using "`ids_used'"
keep if _m == 3
drop _m

merge m:1 Fund using "$temp/sectorfunds"
assert _m == 3 if inlist(date,672,684)
drop if _m == 2
drop _m

merge m:1 Fund using "$temp/intl_equity_funds"
assert _m != 1
drop if _m != 3
drop _m

keep if inlist(date,672,684)
bys Fund date: keep if _n == 1
keep Fund crsp_fundno date money_market bond equity balanced tdf intl_equity sector real_estate

gen fund_type = 1 if equity == 1 & intl_equity == 0 & sector == 0
replace  fund_type = 2 if equity == 1 & intl_equity == 0 & sector == 1
replace fund_type = 3 if equity == 1 & intl_equity == 1 & sector == 0
replace fund_type = 4 if equity == 1 & intl_equity == 1 & sector == 1
replace fund_type = 5 if tdf == 1
replace fund_type = 6 if balanced == 1
replace fund_type = 7 if bond == 1
replace fund_type = 8 if real_estate == 1
replace fund_type = 9 if money_market == 1

la define fund_type 1 "Domestic Equities - Broad" ///
2 "Domestic Equities - Sector" ///
3 "International Equities - Broad" ///
4 "International Equities - Region Funds" ///
5 "TDFs" ///
6 "Balanced" ///
7 "Bonds" ///
8 "Real Estate" ///
9 "Money Market" 
la val fund_type fund_type

la define date 672 "Pre-Reform" ///
684 "Post-Reform"
la val date date

save "$temp/fund_types_summary", replace
}

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

{ // reallocation fund balances table
preserve
	keep if inlist(date,672)
	
	save "$temp/streamlining assets affected", replace
	
	collapse (sum) fund_counter counter (mean) FundsHeld dropped_dollars steady_dollars, by(steady_pre)
	foreach var in FundsHeld dropped_dollars steady_dollars {
		replace `var' = round(`var',.01)
	}
	sort steady_pre
	order steady_pre counter fund_counter FundsHeld steady_dollars dropped_dollars

	la var fund_counter "No. funds"
	la var counter "No. participants"
	la var FundsHeld "Mean balance funds (USD per participant)"
	la var steady_dollars "Mean balance in non-deleted funds (USD per participant)"
	la var dropped_dollars "Mean balance in deleted funds (USD per participant)"
	la var steady_pre " "
	
	export excel "$output/41 - Streamlined Reallocation.xlsx", replace firstrow(varlabels) sheet("2016 Steamlining Allocations")
restore 
}

{ // individual characteristics table
preserve
	keep if inlist(date,672)

	bys ScrubbedID: keep if _n == 1

	la var n_funds "No. funds per person"

	gen sal30 = (RoundedSalary > 0 & RoundedSalary <= 30000)
	gen sal60 = (RoundedSalary > 30000 & RoundedSalary <= 60000)
	gen sal100 = (RoundedSalary > 60000 & RoundedSalary <= 100000)
	gen sal200 = (RoundedSalary > 100000 & RoundedSalary <= 200000)
	gen saltop = (RoundedSalary > 200000 & RoundedSalary < .)
	gen salmissing = (RoundedSalary == 0 | missing(RoundedSalary))
	
	la var sal30 "Salary 30,000 or under"
	la var sal60 "Salary 30,000-60,000"
	la var sal100 "Salary 60,000-100,000"
	la var sal200 "Salary 100,000-200,000"
	la var saltop "Salary over 200,000"
	la var salmissing "Salary data missing"

	
	iebaltab age20s age30s age40s age50s age60s age70s female male unknown_gender ///
	sal30 sal60 sal100 sal200 saltop salmissing n_funds, grpvar(steady_pre) ///
	rowvarlabels vce(robust) pttest onerow tblnote("Statistics are for January 2016 portfolios of individuals that appear in both 2016 and 2017." ///
	"Individuals with all assets invested in TDFs or in funds that were still available after reforms are included." ///
	"Ages are as of November 2016.") ///
	save("$output/42 - Differences in Streamlined Individual Characteristics.xlsx") replace
restore
}

{ // merge in fund types and create table
preserve 
	use "$temp/fund_types_summary", clear
	bys Fund: keep if _n == 1
	save "$temp/fundtypes1", replace
restore

preserve
	keep if inlist(date,672)

	merge m:1 Fund using "$temp/fundtypes1"
	assert _m != 1
	keep if _m == 3
	drop _m
	
	collapse (sum) port_weight (mean) steady_pre, by(ScrubbedID fund_type)
	
	// fill in missing fund types for each person so that we calculate a correct average
	tsset ScrubbedID fund_type
	tsfill, full
	replace port_weight = 0 if missing(port_weight)
	gen temp = steady_pre
	replace temp = 0 if missing(temp)
	drop steady_pre
	bys ScrubbedID: egen steady_pre = max(temp)
	bys ScrubbedID: gen count = (_n == 1)
	drop temp
	
	collapse (count) count (mean) port_weight, by(fund_type steady_pre)
	replace port_weight = round(port_weight, .01)
	reshape wide count port_weight, i(fund_type) j(steady_pre)
	
	decode fund_type, gen(fund_type_string)
	drop fund_type
	order fund_type_string
	la var fund_type_string "Fund Type"
	set obs `=_N+1'
	gen row = _n
	summ row
	local maxrow = r(max)
	replace fund_type = "N" if row == `maxrow'
	replace port_weight0 = count0[_n-1] if row == `maxrow'
	replace port_weight1 = count1[_n-1] if row == `maxrow'
	drop count* row
	
	la var port_weight0 "Streamlined"
	la var port_weight1 "Non-streamlined"
	
	export excel "$output/43 - Reallocation Pre-Reform Share of Assets.xlsx", firstrow(varlabels) replace

restore
}

{ // merge in dominated funds and create table
preserve 
	use "$temp/fund_types_summary", clear
	bys Fund: keep if _n == 1
	save "$temp/fundtypes1", replace
restore

preserve
	keep if inlist(date,672)

	merge m:1 Fund using "$temp/fundtypes1"
	assert _m != 1
	keep if _m == 3
	drop _m

	merge m:1 Fund date crsp_fundno using "$temp/dominated.dta"
	drop if _m == 2	
	replace dominated_simple = 0 if missing(dominated_simple)
	drop _m
	
	collapse (sum) port_weight (mean) steady_pre, by(ScrubbedID dominated_simple)
	
	// fill in missing fund types for each person so that we calculate a correct average
	tsset ScrubbedID dominated_simple
	tsfill, full
	replace port_weight = 0 if missing(port_weight)
	gen temp = steady_pre
	replace temp = 0 if missing(temp)
	drop steady_pre
	bys ScrubbedID: egen steady_pre = max(temp)
	bys ScrubbedID: gen count = (_n == 1)
	drop temp
	
	collapse (count) count (mean) port_weight, by(dominated_simple steady_pre)
	replace port_weight = round(port_weight, .001)
	reshape wide count port_weight, i(dominated_simple) j(steady_pre)
	
	la define dominated_simple 1 "Dominated" 0 "Not Dominated"
	la val dominated_simple dominated_simple 
	decode dominated_simple, gen(dominated_string)
	drop dominated_simple
	order dominated_string
	la var dominated_string "Fund Dominated"
	set obs `=_N+1'
	gen row = _n
	summ row
	local maxrow = r(max)
	replace dominated_string = "N" if row == `maxrow'
	replace port_weight0 = count0[_n-1] if row == `maxrow'
	replace port_weight1 = count1[_n-1] if row == `maxrow'
	drop count* row
	
	la var port_weight0 "Streamlined"
	la var port_weight1 "Non-streamlined"
	
	export excel "$output/43.1 - Reallocation Pre-Reform Share of Dominated Funds.xlsx", firstrow(varlabels) replace

restore
}

{ // set up fund mapping based on the age measure that we have
preserve 
	import excel "$input/fund_transfer_crosswalk update 2019_10_23.xls", firstrow clear
	keep Fund mapped_to_target_date map_to_fund
	expand 80
	bys Fund mapped_to_target_date map_to_fund: gen age2016 = _n + 18
	replace map_to_fund = "OV6M-VANG INST TR INCOME" if age2016 > 73 & mapped_to_target_date == 1
	replace map_to_fund = "OV6N-VANG INST TR 2010" if age2016 > 68 & age2016 <= 73 & mapped_to_target_date == 1
	replace map_to_fund = "OV6O-VANG INST TR 2015" if age2016 > 63 & age2016 <= 68 & mapped_to_target_date == 1
	replace map_to_fund = "OV6P-VANG INST TR 2020" if age2016 > 58 & age2016 <= 63 & mapped_to_target_date == 1
	replace map_to_fund = "OV6Q-VANG INST TR 2025" if age2016 > 53 & age2016 <= 58 & mapped_to_target_date == 1
	replace map_to_fund = "OV6R-VANG INST TR 2030" if age2016 > 48 & age2016 <= 53 & mapped_to_target_date == 1
	replace map_to_fund = "OV6S-VANG INST TR 2035" if age2016 > 43 & age2016 <= 48 & mapped_to_target_date == 1
	replace map_to_fund = "OV6T-VANG INST TR 2040" if age2016 > 38 & age2016 <= 45 & mapped_to_target_date == 1
	replace map_to_fund = "OV6U-VANG INST TR 2045" if age2016 > 33 & age2016 <= 38 & mapped_to_target_date == 1
	replace map_to_fund = "OV6V-VANG INST TR 2050" if age2016 > 28 & age2016 <= 33 & mapped_to_target_date == 1
	replace map_to_fund = "OV6W-VANG INST TR 2055" if age2016 > 23 & age2016 <= 28 & mapped_to_target_date == 1
	replace map_to_fund = "OV6X-VANG INST TR 2060" if age2016 <= 23 & mapped_to_target_date == 1
	save "$temp/reform_mapping", replace
restore


merge m:1 Fund age2016 using "$temp/reform_mapping"
drop if _m == 2
replace mapped_to_target_date = . if date != 672
replace map_to_fund = "" if date != 672
replace _merge = . if date != 672  
assert _m == 3 if date == 672
drop _m 

count if date == 672 & map_to_fund == ""
assert r(N) == 0
}

{ // save 2017 port_weights
preserve 
	// filter to individuals whose portfolios are streamlined
	keep if steady_pre == 0
	keep if date == 684
	keep ScrubbedID Fund port_weight
	rename port_weight port_weight17
	// collapse since some funds listed twice (but still sum to port_weight of 1)
	collapse (sum) port_weight17, by(ScrubbedID Fund)

	save "$temp/2017 simple holdings", replace
restore
}

{ // save 2018 port_weights
preserve 
	// filter to individuals whose portfolios are streamlined
	keep if steady_pre == 0
	keep if date == 696
	keep ScrubbedID Fund port_weight
	rename port_weight port_weight18
	// collapse since some funds listed twice (but still sum to port_weight of 1)
	collapse (sum) port_weight18, by(ScrubbedID Fund)
	
	// adjust Fidelity TDF names since they are slightly different in 2018
	replace Fund = "2171-FID FREEDOM K INCOME" if Fund == "3019-FID FREEDOM INC K"
	replace Fund = "2173-FID FREEDOM K 2005" if Fund == "3020-FID FREEDOM 2005 K"
	replace Fund = "2174-FID FREEDOM K 2010" if Fund == "3021-FID FREEDOM 2010 K"
	replace Fund = "2175-FID FREEDOM K 2015" if Fund == "3022-FID FREEDOM 2015 K"
	replace Fund = "2176-FID FREEDOM K 2020" if Fund == "3023-FID FREEDOM 2020 K"
	replace Fund = "2177-FID FREEDOM K 2025" if Fund == "3024-FID FREEDOM 2025 K"
	replace Fund = "2178-FID FREEDOM K 2030" if Fund == "3025-FID FREEDOM 2030 K"
	replace Fund = "2179-FID FREEDOM K 2035" if Fund == "3026-FID FREEDOM 2035 K"
	replace Fund = "2180-FID FREEDOM K 2040" if Fund == "3027-FID FREEDOM 2040 K"
	replace Fund = "2181-FID FREEDOM K 2045" if Fund == "3028-FID FREEDOM 2045 K"
	replace Fund = "2182-FID FREEDOM K 2050" if Fund == "3029-FID FREEDOM 2050 K"
	replace Fund = "2332-FID FREEDOM K 2055" if Fund == "3030-FID FREEDOM 2055 K"
	
	save "$temp/2018 simple holdings", replace
restore
}

{ // flag plan defaulted 2017 portfolios
preserve
	// filter to individuals whose portfolios are streamlined
	keep if steady_pre == 0
	keep if date == 672
	replace Fund = map_to_fund
	keep ScrubbedID Fund port_weight
	collapse (sum) port_weight, by(ScrubbedID Fund)
	rename port_weight port_weight16
	merge 1:1 ScrubbedID Fund using "$temp/2017 simple holdings"
	
	// allow individuals that are in any TDF not to be flagged
	replace _m = 3 if (strpos(Fund,"VANG INST TR") > 0 | ///
	strpos(Fund,"FID FREEDOM") > 0)
	
	bys ScrubbedID: egen temp = min(_m)
	gen no_merge17 = (temp != 3)
	drop temp _m
		
	gen temp = ((!missing(port_weight17) & !missing(port_weight16)) | (strpos(Fund,"VANG INST TR") > 0 | ///
	strpos(Fund,"FID FREEDOM") > 0))
	bys ScrubbedID: egen same_funds = min(temp)
	drop temp
	
	gen plan_defaulted17 = (same_funds == 1 & no_merge17 == 0)
	tab plan_defaulted17
	gen port_diff = port_weight16 - port_weight17
	la var port_diff "Differences in Allocation (%)"
	hist port_diff if same_funds == 1, ylabel(,nogrid) color(ebblue*.7) percent
	graph export "$output/47 - Allocation Changes in Default Funds.png", replace
	
	keep ScrubbedID plan_defaulted17
	bys ScrubbedID: keep if _n == 1
	
	save "$temp/plan_defaulted17", replace
restore
}

{ // flag plan defaulted 2018 portfolios
preserve
	// filter to individuals whose portfolios are streamlined
	keep if steady_pre == 0
	keep if date == 672
	replace Fund = map_to_fund
	keep ScrubbedID Fund port_weight
	collapse (sum) port_weight, by(ScrubbedID Fund)
	rename port_weight port_weight16
	merge 1:1 ScrubbedID Fund using "$temp/2018 simple holdings"

	// allow individuals that are in any TDF not to be flagged
	replace _m = 3 if (strpos(Fund,"VANG INST TR") > 0 | ///
	strpos(Fund,"FID FREEDOM") > 0)
	
	bys ScrubbedID: egen temp = min(_m)
	gen no_merge18 = (temp != 3)
	drop temp _m
		
	gen temp = ((!missing(port_weight18) & !missing(port_weight16)) | (strpos(Fund,"VANG INST TR") > 0 | ///
	strpos(Fund,"FID FREEDOM") > 0))
	bys ScrubbedID: egen same_funds = min(temp)
	drop temp
	
	gen plan_defaulted18 = (same_funds == 1 & no_merge18 == 0)
	gen port_diff = port_weight16 - port_weight18
	la var port_diff "Differences in Allocation (%)"
	hist port_diff if same_funds == 1, ylabel(,nogrid) color(ebblue*.7) percent

	keep ScrubbedID plan_defaulted18
	bys ScrubbedID: keep if _n == 1
	
	save "$temp/plan_defaulted18", replace
restore
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

{ // summary stats for share of portfolio streamlined
preserve

	keep if date == 672
	bys ScrubbedID: assert plan_defaulted17 == plan_defaulted17[1]
	bys ScrubbedID: assert plan_defaulted18 == plan_defaulted18[1]
	cap drop counter
	
	collapse (sum) dropped_dollars steady_dollars (first) plan_defaulted17, by(ScrubbedID date)
	
	gen counter = 1
	gen person_per_stream = dropped_dollars / (dropped_dollars + steady_dollars)
	assert !missing(person_per_stream)
	gen over_50 = (person_per_stream >= .5)
	gen over_90 = (person_per_stream >= .9)
		
	
	collapse (sum) counter dropped_dollars steady_dollars (mean) over_50 over_90, by(plan_defaulted17)
	gen per_streamlined = round(dropped_dollars / (dropped_dollars + steady_dollars), .001)
	keep plan_defaulted17 per_streamlined counter over_50 over_90
	
	la var plan_defaulted17 " "
	la define plan_defaulted17 0 "Streamlined, affirmative choice" ///
	1 "Streamlined, plan-defaulted" ///
	2 "Non-streamlined"
	la val plan_defaulted17 plan_defaulted17
	la var per_streamlined "Percent of assets changed by streamlining"
	la var counter "N"
	la var over_50 "Percent of investors with at least than 50% of assets changed by streamlining"
	la var over_90 "Percent of investors with at least than 90% of assets changed by streamlining"
	
	export excel "$output/63 - Share of Portfolio Streamlined.xlsx", replace firstrow(varlabels) keepcellfmt

restore
}

{ // share plan defaulted in each year
preserve 
	gen temp = (date == 696)
	bys ScrubbedID: egen present_2018 = max(temp)
	drop temp

	keep if date == 672 & present_2018 == 1
	
	// filter to one observation per person
	bys ScrubbedID: keep if _n == 1
	
	gen affirmative17 = (plan_defaulted17 == 0)
	gen defaulted17 = (plan_defaulted17 == 1)
	gen non17 = (plan_defaulted17 == 2)
	gen affirmative18 = (plan_defaulted18 == 0)
	gen defaulted18 = (plan_defaulted18 == 1)
	gen non18 = (plan_defaulted18 == 2)
	
	collapse (mean) affirmative17 affirmative18 defaulted17 defaulted18 non17 non18
	gen row = _n
	reshape long affirmative defaulted non, i(row) j(date)
	replace date = 2000 + date
	drop row
	
	gen share_of_streamlined = defaulted / (defaulted + affirmative)
	
	la var affirmative "Streamlined, affirmative choice"
	la var defaulted "Streamlined, plan-defaulted"
	la var non "Non-streamlined"
	la var date "Date"
	la var share_of_streamlined "Share of streamlined that are in plan default funds"
	
	order date share_of_streamlined affirmative defaulted non
	
	export excel "$output/64 - Streamlined Defaults 2017-2018.xlsx", sheet("Ignoring Share Class") replace firstrow(varlabels) keepcellfmt

restore
}

{ // add summary stats for share of portfolio streamlined (a row for all streamlined individuals
preserve
	keep if date == 672
	replace plan_defaulted17 = 1 if plan_defaulted17 == 0
	collapse (sum) dropped_dollars steady_dollars (first) plan_defaulted17, by(ScrubbedID date)
	
	gen counter = 1
	gen person_per_stream = dropped_dollars / (dropped_dollars + steady_dollars)
	assert !missing(person_per_stream)
	gen over_50 = (person_per_stream >= .5)
	gen over_90 = (person_per_stream >= .9)
		
	
	collapse (sum) counter dropped_dollars steady_dollars (mean) over_50 over_90, by(plan_defaulted17)
	gen per_streamlined = round(dropped_dollars / (dropped_dollars + steady_dollars), .001)
	keep plan_defaulted17 per_streamlined counter over_50 over_90
	
	la var plan_defaulted17 " "
	la define plan_defaulted17 1 "Streamlined, all" ///
	2 "Non-streamlined"
	la val plan_defaulted17 plan_defaulted17
	la var per_streamlined "Percent of assets changed by streamlining"
	la var counter "N"
	la var over_50 "Percent of investors with at least than 50% of assets changed by streamlining"
	la var over_90 "Percent of investors with at least than 90% of assets changed by streamlining"

	keep if plan_defaulted17 == 1
	assert _N == 1
	
	putexcel set "$output/63 - Share of Portfolio Streamlined.xlsx", modify
	
	putexcel A6 = ("Streamlined, all")
	putexcel B6 = (counter[1])
	putexcel C6 = (over_50[1])
	putexcel D6 = (over_90[1])
	putexcel E6 = (per_streamlined[1])

	putexcel close
	
restore
}	

{ // Difference in Mean Allocation Post-Pre Reform
preserve
	
	keep if inlist(date,672,684)
	
	merge m:1 Fund using "$temp/fundtypes1"
	assert _m != 1
	keep if _m == 3
	drop _m

	collapse (sum) port_weight (mean) plan_defaulted17, by(ScrubbedID fund_type date)

	// fill in missing fund types for each person so that we calculate a correct average
	gen double id = ScrubbedID + date/1000
	tsset id fund_type
	tsfill, full
	tostring id, force replace
	drop ScrubbedID date
	gen ScrubbedID = substr(id,1,strpos(id,".")-1)
	gen date = substr(id,strpos(id,".")+1,3)
	destring ScrubbedID date, replace
	order ScrubbedID date
	replace port_weight = 0 if missing(port_weight)
	gen temp = plan_defaulted17
	replace temp = 0 if missing(temp)
	drop plan_defaulted17
	bys ScrubbedID: egen plan_defaulted17 = max(temp)
	drop temp id

	sort ScrubbedID fund_type date
	by ScrubbedID fund_type: replace port_weight = port_weight - port_weight[_n-1] if _n == 2
	rename port_weight delta_port_weight
	by ScrubbedID fund_type: keep if _n == 2
	assert date == 684
	drop date
	bys ScrubbedID: gen count = (_n == 1)
	
	forvalues i = 1/9 {
		forvalues j = 0/2 {
			di "t-test for fund type `i' and plan defaulted `j'"
			ttest delta_port_weight == 0 if plan_defaulted17 == `j' & fund_type == `i'
			local p_`i'_`j' = r(p)
			di  "p_`i'_`j' is `p_`i'_`j''" 
		}
	}
	
	collapse (count) count (mean) delta_port_weight, by(fund_type plan_defaulted17)
	replace delta_port_weight = round(delta_port_weight, .001)
	reshape wide count delta_port_weight, i(fund_type) j(plan_defaulted17)

	decode fund_type, gen(fund_type_string)
	order fund_type_string
	la var fund_type_string "Fund Type"
	set obs `=_N+1'
	gen row = _n
	summ row
	local maxrow = r(max)
	replace fund_type_string = "N" if row == `maxrow'
	replace delta_port_weight0 = count0[_n-1] if row == `maxrow'
	replace delta_port_weight1 = count1[_n-1] if row == `maxrow'
	replace delta_port_weight2 = count2[_n-1] if row == `maxrow'
	tostring delta_port_weight*, replace force
	
	forvalues i = 0/2 {
		 replace delta_port_weight`i' = "-0." + substr(delta_port_weight`i',3,3) if substr(delta_port_weight`i',1,1) == "-" & substr(delta_port_weight`i',1,2) != "-0" & row != `maxrow'
		replace delta_port_weight`i' = "0." + substr(delta_port_weight`i',2,3) if substr(delta_port_weight`i',1,1) == "." & row != `maxrow'
		replace delta_port_weight`i' = delta_port_weight`i' + "00" if length(delta_port_weight`i') == 3 & substr(delta_port_weight`i',1,1) != "-"  & row != `maxrow'
		replace delta_port_weight`i' = delta_port_weight`i' + "0" if length(delta_port_weight`i') == 4 & substr(delta_port_weight`i',1,1) != "-"  & row != `maxrow'
		replace delta_port_weight`i' = delta_port_weight`i' + "00" if length(delta_port_weight`i') == 4 & substr(delta_port_weight`i',1,1) == "-"  & row != `maxrow'
		replace delta_port_weight`i' = delta_port_weight`i' + "0" if length(delta_port_weight`i') == 5 & substr(delta_port_weight`i',1,1) == "-"  & row != `maxrow'
		replace delta_port_weight`i' = "0.000" if delta_port_weight`i' == "0" & row != `maxrow'
	}
	
	drop count* row
	tostring delta_port_weight*, replace force
	/*
	forvalues i = 1/9 {
		forvalues j = 0/2 {
			replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .1
			replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .05
			replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .01
		}
	}
	*/
	drop fund_type
	la var delta_port_weight0 "Streamlined, affirmative choice"
	la var delta_port_weight1 "Streamlined, plan-defaulted"
	la var delta_port_weight2 "Non-streamlined"
	
	export excel "$output/44 - Difference in Mean Allocation Post-Pre Reform.xlsx", firstrow(varlabels) replace
	

restore
}

{ // Difference in Mean Allocation Post (2018) - Pre Reform 
preserve

	keep if inlist(date,672,696)
	
	// adjust fund names for merge
	replace Fund = "2171-FID FREEDOM K INCOME" if Fund == "3019-FID FREEDOM INC K"
	replace Fund = "2173-FID FREEDOM K 2005" if Fund == "3020-FID FREEDOM 2005 K"
	replace Fund = "2174-FID FREEDOM K 2010" if Fund == "3021-FID FREEDOM 2010 K"
	replace Fund = "2175-FID FREEDOM K 2015" if Fund == "3022-FID FREEDOM 2015 K"
	replace Fund = "2176-FID FREEDOM K 2020" if Fund == "3023-FID FREEDOM 2020 K"
	replace Fund = "2177-FID FREEDOM K 2025" if Fund == "3024-FID FREEDOM 2025 K"
	replace Fund = "2178-FID FREEDOM K 2030" if Fund == "3025-FID FREEDOM 2030 K"
	replace Fund = "2179-FID FREEDOM K 2035" if Fund == "3026-FID FREEDOM 2035 K"
	replace Fund = "2180-FID FREEDOM K 2040" if Fund == "3027-FID FREEDOM 2040 K"
	replace Fund = "2181-FID FREEDOM K 2045" if Fund == "3028-FID FREEDOM 2045 K"
	replace Fund = "2182-FID FREEDOM K 2050" if Fund == "3029-FID FREEDOM 2050 K"
	replace Fund = "2332-FID FREEDOM K 2055" if Fund == "3030-FID FREEDOM 2055 K"
	
	merge m:1 Fund using "$temp/fundtypes1"
	assert _m != 1
	keep if _m == 3
	drop _m

	collapse (sum) port_weight (mean) plan_defaulted18, by(ScrubbedID fund_type date)

	// fill in missing fund types for each person so that we calculate a correct average
	gen double id = ScrubbedID + date/1000
	tsset id fund_type
	tsfill, full
	tostring id, force replace
	drop ScrubbedID date
	gen ScrubbedID = substr(id,1,strpos(id,".")-1)
	gen date = substr(id,strpos(id,".")+1,3)
	destring ScrubbedID date, replace
	order ScrubbedID date
	replace port_weight = 0 if missing(port_weight)
	gen temp = plan_defaulted18
	replace temp = 0 if missing(temp)
	drop plan_defaulted18
	bys ScrubbedID: egen plan_defaulted18 = max(temp)
	drop temp id

	sort ScrubbedID fund_type date
	by ScrubbedID fund_type: replace port_weight = port_weight - port_weight[_n-1] if _n == 2
	rename port_weight delta_port_weight
	by ScrubbedID fund_type: keep if _n == 2
	assert date == 696
	drop date
	bys ScrubbedID: gen count = (_n == 1)
	
	forvalues i = 1/9 {
		forvalues j = 0/2 {
			di "t-test for fund type `i' and plan defaulted `j'"
			ttest delta_port_weight == 0 if plan_defaulted18 == `j' & fund_type == `i'
			local p_`i'_`j' = r(p)
			di  "p_`i'_`j' is `p_`i'_`j''" 
		}
	}
	
	collapse (count) count (mean) delta_port_weight, by(fund_type plan_defaulted18)
	replace delta_port_weight = round(delta_port_weight, .001)
	reshape wide count delta_port_weight, i(fund_type) j(plan_defaulted18)

	decode fund_type, gen(fund_type_string)
	order fund_type_string
	la var fund_type_string "Fund Type"
	set obs `=_N+1'
	gen row = _n
	summ row
	local maxrow = r(max)
	replace fund_type_string = "N" if row == `maxrow'
	replace delta_port_weight0 = count0[_n-1] if row == `maxrow'
	replace delta_port_weight1 = count1[_n-1] if row == `maxrow'
	replace delta_port_weight2 = count2[_n-1] if row == `maxrow'
	tostring delta_port_weight*, replace force
	
	forvalues i = 0/2 {
		 replace delta_port_weight`i' = "-0." + substr(delta_port_weight`i',3,3) if substr(delta_port_weight`i',1,1) == "-" & substr(delta_port_weight`i',1,2) != "-0" & row != `maxrow'
		replace delta_port_weight`i' = "0." + substr(delta_port_weight`i',2,3) if substr(delta_port_weight`i',1,1) == "." & row != `maxrow'
		replace delta_port_weight`i' = delta_port_weight`i' + "00" if length(delta_port_weight`i') == 3 & substr(delta_port_weight`i',1,1) != "-"  & row != `maxrow'
		replace delta_port_weight`i' = delta_port_weight`i' + "0" if length(delta_port_weight`i') == 4 & substr(delta_port_weight`i',1,1) != "-"  & row != `maxrow'
		replace delta_port_weight`i' = delta_port_weight`i' + "00" if length(delta_port_weight`i') == 4 & substr(delta_port_weight`i',1,1) == "-"  & row != `maxrow'
		replace delta_port_weight`i' = delta_port_weight`i' + "0" if length(delta_port_weight`i') == 5 & substr(delta_port_weight`i',1,1) == "-"  & row != `maxrow'
		replace delta_port_weight`i' = "0.000" if delta_port_weight`i' == "0" & row != `maxrow'
	}
	
	drop count* row
	tostring delta_port_weight*, replace force
	
	forvalues i = 1/9 {
		forvalues j = 0/2 {
			replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .1
			replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .05
			replace delta_port_weight`j' = delta_port_weight`j' + "*" if fund_type == `i' & `p_`i'_`j'' <= .01
		}
	}
	
	drop fund_type
	la var delta_port_weight0 "Streamlined, affirmative choice"
	la var delta_port_weight1 "Streamlined, plan-defaulted"
	la var delta_port_weight2 "Non-streamlined"
	
	export excel "$output/44.1  - Difference in Mean Allocation 2016-2018.xlsx", firstrow(varlabels) replace
	

restore
}

{ // reallocation regressions
// this analysis includes individuals that were entirely in TDFs/steady funds before reform

use "$temp/collapse2_combined.dta", replace
keep if inlist(date,672,684,991)
sort ScrubbedID date
merge m:1 ScrubbedID using "$temp/plan_defaulted17"
replace plan_defaulted17 = 2 if steady_pre == 1

// make sure dates are in the correct order
assert date[1] == 672
assert date[2] == 684
// assert date[3] == 991

local vars = "equities dominated_simple exp_ratio n_funds"

foreach var in `vars' {
	di "`var'"
	gen `var'_prepost = `var'[_n+1] - `var' if date == 672 & ScrubbedID == ScrubbedID[_n+1] 
	gen `var'_preguardrails = `var'[_n+2] - `var' if date == 672 & ScrubbedID == ScrubbedID[_n+2]
	drop `var'
}
keep if date == 672

// generate and label variables for regression	
la var equities_prepost "Delta % Equities Post Minus Pre"
la var equities_preguardrails "Delta % Equities Guardrails Minus Pre"
la var dominated_simple_prepost "Delta % Dominated Funds Post Minus Pre"
la var dominated_simple_preguardrails "Delta % Dominated Funds Guardrails Minus Pre"
la var exp_ratio_prepost "Delta Expense Ratio Post Minus Pre"
la var exp_ratio_preguardrails "Delta Expense Ratio Guardrails Minus Pre"
la var n_funds_prepost "Delta No. Funds Post Minus Pre"
la var n_funds_preguardrails "Delta No. Funds Guardrails Minus Pre"

gen sal30 = (RoundedSalary > 0 & RoundedSalary <= 30000)
gen sal60 = (RoundedSalary > 30000 & RoundedSalary <= 60000)
gen sal100 = (RoundedSalary > 60000 & RoundedSalary <= 100000)
gen sal200 = (RoundedSalary > 100000 & RoundedSalary <= 200000)
gen saltop = (RoundedSalary > 200000 & RoundedSalary < .)
gen salmissing = (RoundedSalary == 0 | missing(RoundedSalary))

la var sal30 "Salary 30,000 or under"
la var sal60 "Salary 30,000-60,000"
la var sal100 "Salary 60,000-100,000"
la var sal200 "Salary 100,000-200,000"
la var saltop "Salary over 200,000"
la var salmissing "Salary data missing"

gen female = (Gender == "F")
gen male = (Gender == "M")
gen unknown_gender = (male == 0 & female == 0)

gen age2016 = age2018 - 2
la var age2016 "Age as of 2016"
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
	
gen age_2 = age2016^2
la var age_2 "Age-squared"

gen total_assets_100 = total_assets/100000
la var total_assets_100 "Total assets (100,000 USD)"

la define plan_defaulted17 0 "Streamlined, affirmative choice" ///
1 "Streamlined, plan-defaulted"	///
2 "Non-streamlined"
la val plan_defaulted17 plan_defaulted17

gen streamlined_pd = (plan_defaulted17 == 1)
la var streamlined_pd "Streamlined, plan-defaulted"	
gen streamlined_npd = (plan_defaulted17 == 0)
la var streamlined_npd "Streamlined, non-plan-defaulted"	

rename dominated_simple_preguardrails dom_simple_preguard


// regression output
outreg2 using "$temp/48 - Reallocation Regressions.xls", replace skip
local vars = "equities_prepost equities_preguardrails dominated_simple_prepost dom_simple_preguard exp_ratio_prepost exp_ratio_preguardrails n_funds_prepost n_funds_preguardrails"
local n_vars : word count `vars'
local controls streamlined_pd streamlined_npd age2016 age_2 female unknown_gender total_assets_100 sal60 sal100 sal200 saltop salmissing
forvalues i = 1/`n_vars' {
	local var : word `i' of `vars'
	local lab: variable label `var'
	di "`var'"
	regress `var' `controls', robust 
	outreg2 using "$temp/48 - Reallocation Regressions.xls", append ctitle(`lab') label stats(coef pval) drop(equities_prepost equities_preguardrails dominated_simple_prepost dominated_simple_preguardrails exp_ratio_prepost exp_ratio_preguardrails n_funds_prepost n_funds_preguardrails)

	test streamlined_pd == streamlined_npd 
	local `var'_p = round(r(p),.001)
	local `var'_mean = round(_b[streamlined_pd] - _b[streamlined_npd],.00001)

}

/// must resave as .xlsx
preserve 
	import delimited "$temp\48 - Reallocation Regressions.txt", clear
	drop v1 
	replace v2 = "" if _n == 2
	drop if _n == 4 | _n == 5
	replace v2 = "N" if _n == 31
	replace v2 = "R-Squared" if _n == 32
	export excel "$output\48 - Reallocation Regressions.xlsx", replace
restore

// add in variable means
putexcel set "$output/48 - Reallocation Regressions.xlsx", modify sheet("Sheet1")
putexcel B1 = "Mean"
putexcel C1 = "(1)"
putexcel D1 = "(2)"
putexcel E1 = "(3)"
putexcel F1 = "(4)"
putexcel G1 = "(5)"
putexcel H1 = "(6)"
putexcel I1 = "(7)"
putexcel J1 = "(8)"

local controls "streamlined_pd streamlined_npd age2016 age_2 female unknown_gender total_assets_100 sal60 sal100 sal200 saltop salmissing"
local n_controls : word count `controls'
di `n_controls'
forvalues i = 1/`n_controls' {
	di `i'
	local var : word `i' of `controls'	
	di "`var'"
	local row = `i' * 2 + 2
	di `row'
	summ `var'
	local mean = r(mean)
	putexcel B`row' = `mean'
}

putexcel A35 = "Diff(β(Streamlined, plan-defaulted) – β(Streamlined, non-plan-defaulted))"
putexcel A36 = "Mean of dep var"
local letters "C D E F G H I J"
local vars = "equities_prepost equities_preguardrails dominated_simple_prepost dom_simple_preguard exp_ratio_prepost exp_ratio_preguardrails n_funds_prepost n_funds_preguardrails"
local n_vars : word count `vars'
forvalues i = 1/`n_vars' {
	local var : word `i' of `vars'
	local letter : word `i' of `letters'
	local stars = ""
	di ``var'_p'
	if (``var'_p' < .1) {
		local stars = "*"
	}
	if (``var'_p' < .05) {
		local stars = "**"
	}
	if (``var'_p' < .01) {
		local stars = "***"
	}
	putexcel `letter'35 = "``var'_mean'`stars'"
	summ `var'
	local dep_mean = round(r(mean), .001)
	putexcel `letter'36 = "`dep_mean'"
}



}









