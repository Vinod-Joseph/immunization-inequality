
/********************************************************************
 NFHS (India) – Immunization inequality (12–23 months)
 Paper ref: Understanding inequalities in child immunization in India
*********************************************************************/

* Housekeeping ------------------------------------------------------
clear all
set more off
version 17

/*
Assumptions
- You have the KR file loaded (children ever born to interviewed women)
  Typical name (NFHS-4): IAIR74FL.DTA (or country-appropriate KR file)
- Variables follow DHS standard recode: h2/h3/h5/h7/h4/h6/h8/h9, b19/b5, v005, v021, v022, v024, v025, v106, v130, s116, v151, v190, v191, b4, bord
*/

* Weights & survey design ------------------------------------------
cap gen Sample_Weight= v005/1000000
la var Sample_Weight "Sample Weight"

/* DHS recommendation: PSU=v021; strata=v022 (or v023 if present). */
cap svyset v021 [pw=wt], strata(v022) singleunit(centered)

* Sample: alive children aged 12–23 months -------------------------
cap confirm variable b19
if _rc==0 {
    keep if inrange(b19,12,23)
} else {
    gen age_months = v008 - b3
    keep if inrange(age_months,12,23)
}
keep if b5==1  // alive

* Dependent variables (vaccination status) -------------------------
/* DHS codes for h* typically:
   0 = No, 1 = date on card, 2 = reported on card, 3 = marked on card,
   4 = reported by mother, 8 = Don't know. Treat 1–4 as vaccinated. */
local vaccs h2 h3 h5 h7 h4 h6 h8 h9
foreach v of local vaccs {
    gen `v'_any = inlist(`v',1,2,3,4) if `v'<.
}

rename (h2_any h3_any h5_any h7_any h4_any h6_any h8_any h9_any) ///
       (BCG    DPT_1  DPT_2  DPT_3  Polio_1 Polio_2 Polio_3 Measles)

label var BCG     "BCG received (any source)"
label var DPT_1   "DPT1 received (any source)"
label var DPT_2   "DPT2 received (any source)"
label var DPT_3   "DPT3 received (any source)"
label var Polio_1 "Polio1 received (any source)"
label var Polio_2 "Polio2 received (any source)"
label var Polio_3 "Polio3 received (any source)"
label var Measles "Measles received (any source)"

* Full immunization indicator (WHO basic schedule) -----------------
/* FULL = 1 dose BCG, 3 doses DPT, 3 doses Polio, 1 dose Measles */

gen byte Full_Imm = (BCG==1 & DPT_1==1 & DPT_2==1 & DPT_3==1 & ///
                     Polio_1==1 & Polio_2==1 & Polio_3==1 & Measles==1)
label var Full_Imm "Fully immunized (BCG, DPT3, Polio3, Measles)"

* Key covariates ----------------------------------------------------

* Sex of child
clonevar sex = b4
label define SEX 1 "Male" 2 "Female"
label values sex SEX
label var sex "Sex of child"

* Place of residence
clonevar Resi = v025
label define RESI 1 "Urban" 2 "Rural"
label values Resi RESI
label var Resi "Place of residence"

* Birth order
recode bord (1=1 "One") (2=2 "Two") (3=3 "Three") (4/15=4 "Four+") , gen(B_order)
label var B_order "Birth order"

* Mother's education
recode v106 (0=0 "No education") (1=1 "Primary") (2=2 "Secondary") (3=3 "Higher"), gen(M_Education)
label var M_Education "Mother's education"

* Religion
recode v130 (1=1 "Hindu") (2=2 "Muslim") (3=3 "Christian") (4/9=4 "Others"), gen(Reli)
label var Reli "Religion"

* Caste/tribe (India-specific: s116)
/* s116: 1=SC, 2=ST, 3=OBC, 4+ = Others/Missing */
recode s116 (1=1 "Scheduled caste") (2=2 "Scheduled tribe") (3=3 "OBC") (4/max=4 "Others"), gen(Social)
label var Social "Caste/tribe"

* Sex of household head
recode v151 (1=1 "Male") (2=2 "Female"), gen(Sex_HHead)
label var Sex_HHead "Sex of household head"

* Wealth quintile
recode v190 (1=1 "Poorest") (2=2 "Poorer") (3=3 "Middle") (4=4 "Richer") (5=5 "Richest"), gen(Wealth)
label var Wealth "Wealth index (quintile)"

* Regions (map states v024 -> 6 macro regions) ---------------------
/* NOTE: Verify codes for your NFHS round/state IDs before use. */
recode v024 ///
    (6 25 12/14 28 29 34 = 1 "North") ///
    (7 19 33               = 2 "Central") ///
    (5 15 26 35            = 3 "East") ///
    (3 4 21 22 23 24 30 32 = 4 "Northeast") ///
    (8 9 10 11 20          = 5 "West") ///
    (1 2 16 17 18 27 31 36 = 6 "South"), gen(Region)
label var Region "Macro region"

* Descriptives: weighted tabs --------------------------------------
svy: tab Full_Imm sex, row
svy: tab Full_Imm Resi, row
svy: tab Full_Imm B_order, row
svy: tab Full_Imm M_Education, row
svy: tab Full_Imm Reli, row
svy: tab Full_Imm Social, row
svy: tab Full_Imm Sex_HHead, row
svy: tab Full_Imm Wealth, row
svy: tab Full_Imm Region, row

* Survey‑logistic models -------------------------------------------
svy: logistic Full_Imm i.sex i.Resi i.B_order i.M_Education i.Reli i.Social i.Sex_HHead i.Wealth i.Region
estimates store m1

* OPTIONAL: simple model example
svy: logistic Full_Imm i.sex

/********************************************************************
 Concentration Index (CI) and decomposition (Wagstaff et al.)
********************************************************************/

* Outcome used for CI
clonevar immunization = Full_Imm
label var immunization "Full immunization (binary)"

* Binary regressors for decomposition ------------------------------
recode sex (1=1) (2=0), gen(Csex)             // male=1
recode Resi (1=0) (2=1), gen(CResi)           // rural=1
recode B_order (1/3=0) (4=1), gen(CB_order)   // birth order 4+
recode M_Education (0=1) (1/3=0), gen(CM_Edu) // illiterate=1
recode Reli (2=1) (1 3 4=0), gen(CReli)       // muslim=1
recode Social (2=1) (1 3 4=0), gen(CSocial)   // ST=1
recode Sex_HHead (1=0) (2=1), gen(CSex_HH)    // female head=1
recode Wealth (1/2=1) (3/5=0), gen(CWealth)   // poor (poorest/poorer)=1

label var Csex    "Male"
label var CResi   "Rural residence"
label var CB_order "Birth order 4+"
label var CM_Edu  "Mother illiterate"
label var CReli   "Muslim"
label var CSocial "Scheduled tribe"
label var CSex_HH "Female household head"
label var CWealth "Poor (Q1–Q2)"

* Fractional rank by wealth score (v191) ---------------------------
* v191 = wealth index factor score (continuous). Use for ranking.

egen raw_rank = rank(v191), unique
sort raw_rank
quietly summarize wt
scalar W = r(sum)
gen wi   = wt/W
gen cus  = sum(wi)
gen rj   = cus[_n-1]
replace rj = 0 if _n==1
* fractional rank in (0,1):
gen rank = rj + 0.5*wi

drop raw_rank wi cus rj

* Mean of outcome (weighted)
quietly summarize immunization [aw=wt]
scalar m_y = r(mean)

* Concentration index for outcome (covariance form)
correlate immunization rank [aw=wt], covariance
scalar CI_y = (2/m_y)*r(cov_12)
display as txt "Concentration Index (immunization): " as res CI_y

* Decomposition regressors ----------------------------------------
local X Csex CResi CB_order CM_Edu CReli CSocial CSex_HH CWealth

* Linear probability model for decomposition weights (elasticities)
regress immunization `X' [aw=wt]
quietly summarize immunization [aw=wt]
scalar m_y = r(mean)

display as txt "Mean immunization (weighted): " as res m_y

* Collect contributions
tempname table
mat `table' = J(`: word count `X'', 5, .)
local rix = 1
foreach x of local X {
    scalar b_`x' = _b[`x']
    * Covariance with rank
    correlate rank `x' [aw=wt], covariance
    scalar cov_`x' = r(cov_12)
    quietly summarize `x' [aw=wt]
    scalar mean_`x' = r(mean)
    scalar elas_`x' = (b_`x'*mean_`x')/m_y
    scalar CI_`x'   = (2*cov_`x')/mean_`x'
    scalar con_`x'  = elas_`x' * CI_`x'
    * Store: mean | beta | elasticity | CI | contribution
    mat `table'[`rix',1] = mean_`x'
    mat `table'[`rix',2] = b_`x'
    mat `table'[`rix',3] = elas_`x'
    mat `table'[`rix',4] = CI_`x'
    mat `table'[`rix',5] = con_`x'
    local ++rix
}

mat colnames `table' = mean beta elasticity CI contribution
mat rownames `table' = `X'
mat list `table'

* Sum of explained contribution
mata: st_numscalar("CON_EXPL", colsum(st_matrix("`table'")) [.,5])
display as txt "Explained contribution (sum): " as res CON_EXPL

* Residual (unexplained)
scalar residual = CI_y - CON_EXPL
scalar share_resid = residual/CI_y

display as txt "Residual contribution: " as res residual
capture noisily display as txt "Residual share (%): " as res share_resid

save "results/immunization_ci_tempvars.dta", replace

