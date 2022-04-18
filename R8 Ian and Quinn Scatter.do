**** Figure 7 with Ian and Quinn ****

use "$temp/collapse2_combined", clear

gen ian_flag = (ScrubbedID == 11596)
gen quinn = (ScrubbedID == 2822)

gen graph_helper = .

keep if date == 672 | date == 684

keep if date == 672

label define ScrubbedID 11596 "I" 2822 "Q" 
label values ScrubbedID ScrubbedID  

label var ian_flag "I"
label var quinn "Q"

// basic returns-variance for pre only
twoway (scatter ante_ret ante_var if date == 672 & var_used < .04 & smart == 0, mcolor("gs13") msize(tiny) msymbol(o)) ///
(scatter ante_ret ante_var if date == 672 & ScrubbedID == 11596, mcolor("gs2") mlabcolor("gs0") msize(huge) mlabel(ScrubbedID) msymbol(none)) ///
(scatter ante_ret ante_var if date == 672 & ScrubbedID == 2822, mcolor("gs2") mlabcolor("gs0") msize(huge) mlabel(ScrubbedID) msymbol(none)), ///
legend(pos(5) order(1 "Other Plan Participants" - "I: Ian Ayres" "Q: Quinn Curtis")) ///
note("Limited to observations with variance < 0.04", size(small)) ylabel(,nogrid) ytitle(Ex Post Return) xtitle(Ex Post Variance)

twoway (scatter return_used var_used if date == 672 & var_used < .04 & smart == 0, mcolor("gs13") msize(tiny) msymbol(o)) ///
(scatter return_used var_used if date == 672 & ScrubbedID == 11596, mcolor("gs2") mlabcolor("gs0") msize(huge) mlabel(ScrubbedID) msymbol(none)) ///
(scatter return_used var_used if date == 672 & ScrubbedID == 2822, mcolor("gs2") mlabcolor("gs0") msize(huge) mlabel(ScrubbedID) msymbol(none)), ///
legend(pos(5) order(1 "Other Plan Participants" - "I: Ian Ayres" "Q: Quinn Curtis")) ///
note("Limited to observations with variance < 0.04", size(small)) ylabel(,nogrid) ytitle(Ex Post Return) xtitle(Ex Post Variance)

graph export "$output/2.4 Ian Quinn Ex Ante.png", replace
graph save "$temp/2.4iq - Return Variance Only Pre Rescale.gph", replace

