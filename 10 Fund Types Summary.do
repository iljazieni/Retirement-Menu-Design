use "$temp/fund_types_summary", clear

preserve
	gen counter = 1
	collapse (count) count = counter , by(fund_type date)

	reshape wide count, i(fund_type) j(date)
	replace count684 = 0 if missing(count684)

	graph hbar count672 count684, over(fund_type) ///
	ylab(,nogrid) ytitle("Count") ///
	bar(1,color("$color_p2")) bar(2,color("$color_p3")) ///
	blabel(total) ///
	legend(label(1 "Pre-Reform") label(2 "Post-Reform")) 
	graph export "$output/36 - Fund Types.png", replace


	graph hbar count672, over(fund_type) ///
	ylab(,nogrid) ytitle("Count") ///
	bar(1,color("$color_p2")) ///
	blabel(total) ///
	legend(label(1 "Pre-Reform")) 
	graph export "$output/36.1 - Fund Types Pre-Only.png", replace


	la var count672 "Pre-Reform"
	la var count684 "Post-Reform"
	la var fund_type "Fund Type"
	export excel using "$output/36.2 - Fund Type Table.xlsx", replace firstrow(varlabels)
restore 


merge m:1 Fund crsp_fundno date using "$temp/dominated.dta"
cap drop _m
la define dominated_simple 1 "Dominated" 0 "Not Dominated"
la val dominated_simple dominated_simple

preserve
	gen counter = 1
	collapse (count) count = counter , by(dominated_simple date)

	reshape wide count, i(dominated_simple) j(date)
	replace count684 = 0 if missing(count684)

	graph hbar count672 count684, over(dominated_simple) ///
	ylab(,nogrid) ytitle("Count") ///
	bar(1,color("$color_p2")) bar(2,color("$color_p3")) ///
	blabel(total) ///
	legend(label(1 "Pre-Reform") label(2 "Post-Reform")) 
	
	graph export "$output/46 - Dominated Fund Counts.png", replace

restore 
