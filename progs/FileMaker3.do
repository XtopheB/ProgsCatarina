/* 17/08/2010 :  Creation des fichiers des individus à partir des fichiers ménages */
/* 31/08/2010 : Ajout des données ménages 2001, 2002 et 2008     */
/* 17/11/2010 : Création de fichiers ménages  */
/* 23/10/2012 : Ajout des fichiers ménages 2009 et 2010 
		--> Sauvegarde 	IndividAll5.dta 
						Household2001-2010.dta    */
/* 01/11/2012 : keep all the individuals (not only if age >20  
			  : Modif def of ID, inserted in individYYYY.dta  */ 
/* 03/11/2012 : Ajout du calcul du BMI pour les individus de 2001  */
/* 25/11/2012 : rectification des BMI pour 2002 (tailles == 999)  */
/* 28/11/2012 : vu avec Catarina. Doublons au niveau NopnltNF Sexe ana (= ID)  */


set more off

*global root "c:/Chris/progs/catarina/"
*global root "D:/progs/catarina/"
global root "c:/Chris/Zprogs/catarina"

cd $root
capture log close

cd progs
log using "$root/progs/logs/FileMaker_$S_DATE.smcl", replace 
/* PART 1 : Generation of files  :
		-  Files at the Houshold level  per year 
		-  Files at individuals level from the original household's files */

forvalues y = 2001/2010 {
	use ../Sources/menages`y'.dta, clear
	notes drop _dta
	/*  for 2001 2002 files, wee need to do some stuff*/

	forvalues i = 1/ 14 { 
		capture rename ista`i' statut`i'
		capture rename iana`i' ana`i'
		capture gen ipds`i'=.
		}
	/* First clean the data  for 2001 & 2002 */
	 if `y' == 2001 {   
				forvalues i = 1/ 11 {  /* Only 11 people per household are recorded in 2001, 2002*/ 
				rename  ihau`i' ihauC`i'
				gen ihau`i' = .
				/*Men */
				replace ihau`i'= 163 if ihauC`i'== 10 & Sexe`i' ==1
				replace ihau`i'= 165 if ihauC`i'== 11 & Sexe`i' ==1
				replace ihau`i'= 168 if ihauC`i'== 12 & Sexe`i' ==1
				replace ihau`i'= 170 if ihauC`i'== 13 & Sexe`i' ==1
				replace ihau`i'= 173 if ihauC`i'== 14 & Sexe`i' ==1
				replace ihau`i'= 175 if ihauC`i'== 15 & Sexe`i' ==1
				replace ihau`i'= 178 if ihauC`i'== 16 & Sexe`i' ==1
				replace ihau`i'= 180 if ihauC`i'== 17 & Sexe`i' ==1
				replace ihau`i'= 183 if ihauC`i'== 18 & Sexe`i' ==1
				replace ihau`i'= .   if ihauC`i'== 19 & Sexe`i' ==1
				
				/*Women */
				replace ihau`i'= 153 if ihauC`i'== 20 & Sexe`i' == 2
				replace ihau`i'= 155 if ihauC`i'== 21 & Sexe`i' == 2
				replace ihau`i'= 158 if ihauC`i'== 22 & Sexe`i' == 2
				replace ihau`i'= 160 if ihauC`i'== 23 & Sexe`i' == 2
				replace ihau`i'= 163 if ihauC`i'== 24 & Sexe`i' == 2
				replace ihau`i'= 155 if ihauC`i'== 25 & Sexe`i' == 2
				replace ihau`i'= 168 if ihauC`i'== 26 & Sexe`i' == 2
				replace ihau`i'= 170 if ihauC`i'== 27 & Sexe`i' == 2
				replace ihau`i'= 172 if ihauC`i'== 28 & Sexe`i' == 2
				replace ihau`i'= .   if ihauC`i'== 29 & Sexe`i' == 2
				
				/* Generation of BMI (ajout 03/11/2012)*/
				gen Taille`i'= ihau`i'/100
				gen BMI`i'= . 
				replace BMI`i'= kgcper`i'/(Taille`i')^2 if kgcper`i' != 0    
								
				}
		capture drop Taille*
		}
	 if `y' == 2002 {  /*  pb specifiques pour  2002 certain BMI's sont calculés avec des tailles fausses (21/11/2012) */
		forvalues i = 1/ 11 { 
			capture replace BMI`i'=. if ipds`i' == 999
				}
		
	 }
	 if `y'==2010 {  /*  variable ana1, ana2, etc.; doesn't exist    */
	capture drop ana
	forvalues i = 1/ 11 { 
		capture rename ianb`i' ana`i'
		}
	}
	
	
	capture gen ana= naip
	
	/* Cleaning for all Years : one declare some values as missing  */ 
	
	 forvalues i = 1/ 14 {         /* As much as 14 people are recorded since 2003*/ 
		/* Validity of BMI's if height or weight is not correct    */
		
		capture replace BMI`i'=. if ipds`i' == 999 | ihau`i' <= 0
		capture replace ihau`i'=. if ihau`i' <= 0 /*  missing are sometimes -1 */
		capture replace ipds`i'=. if ipds`i' <= 0 /*  missing are sometimes -1 */
		capture drop if BMI`i' == 0  
		
		}
	/* keep only relevent variables (17/11/2010: we keep BMI !) */
	/* variables  revd, icol*, itpo*, itai*, ibas* doesn't exist in 2010  */
	
	keep  nopnltNF naip clas nf cspc naic /*revd*/ reve nocom noreg ucfo ucfe ucad /// 
	statut* iday* imoi* ana* icsp* /*icol* itpo* itai* ibas**/ ipds*    ihau*  Sexe* foyer ///
	an Dept Region Region_insee Code_Commune BMI*

	/* ----  Creation Of The Household Files  per year  ---- */
	/* That's the  information we keep at household level */
	quietly compress
	label data "File created using FileMaker3.do ($S_DATE). All Households with BMI and CSP"
	save ../data/Household`y', replace
/* ----  Creation Of The Individual Files    ---- */

	
	/* One line per individual in the same family */
	
	/* since we kept BMI at the Household level, we need to drop it now as it changes for individuals over time */
	capture drop BMI 	/*(17/11/2010)*/
	capture drop ana   /* 29/10/2012  */
	capture drop icsp  /* 28/11/2012  */ 
	
	/* a long list of variable that are already defined and that neefd to be removed  */
	di " " 
	di "-------------------"
	di " Year  `y', creating individual files "
	di ""
	
	quietly reshape long BMI ihau ipds Sexe ana statut iday imoi icsp /* icolitpo itai ibas */ , i(nopnlt) j(indiv)

	label variable ihau "Height (cm)"
	replace Sexe=(Sexe==1)
	label variable Sexe "Gender"
	label define typoSexeNew 0 "Women" 1 "Men" 
	label value Sexe typoSexeNew
	
	
	/* Visualization */
	count
	sort nopnltNF indiv
	order nopnltNF indiv Sexe nf ana ihau ipds 
	*edit	

	/* creation of some variables of interest  */
	gen Age = an- ana
	label var Age "Age"
	gen Year20 = ana+20  /* year when people were 20  */
	label var Year20 "Year of 20" 
	di " " 
	di " Cleaning individual files "
	di " "
	/* Now we drop non-complete lines  */
	drop if ihau == .    /* Beaucoup parce que 11 individus prévus et maj non renseignés */
	drop if Sexe == .
	drop if ana == .
	di ""
	di " Duplicates for  `y'  (same nopnltNF Sexe ana )"
	di""
	/* Examine and drop the duplicates  ( décidé avec Catarina  27/11/2012) */
	duplicates report nopnltNF Sexe ana   
	duplicates drop nopnltNF Sexe ana , force
	
	di " Statistics year `y' "
	di""
	/* Statistics */

	bysort Sexe : sum ihau /* ok with INSEE http://www.insee.fr/fr/themes/document.asp?reg_id=0&id=1954  */
	bysort Sexe : sum ipds

	*graph box ihau if Sexe==1 ,over(year20)
	*bysort year20 : sum ihau if Sexe==1
	*regress ihau Year20 i.Sexe if Year20 >1981 /* OK with INSEE */
	
	/* generation of a unique identifier */
	tostring nopnltNF , gen(Id)
	
	gen gender = "W" if Sexe==0
	replace gender="M" if Sexe==1
	tostring ana, gen(annaiss)
	replace Id = Id+gender+annaiss
	
	compress
	label data "Individual File (year `y' with BMI and personnal information"
	notes  : Created using FileMaker3.do ($S_DATE). All unique Individuals
	
	save ../data/Individ`y', replace
	*pause  (taper q pour reprendre)
}

di "--
di " Creating pooled files (2001-2010)"
di ""

/* PART 2 : ---- The Complete Household file -----*/
/* Generation of one unique dataset with all the households */

use ../data/Household2001.dta, clear
forvalues y = 2002/2010 {
	quietly append using ../data/Household`y'
	*duplicates report nopnltNF 
	count
}
	
compress
label data "Household File all years with personnal and household information"
notes  : Created using FileMaker3.do ($S_DATE). No duplicates check
save ../data/Household2001-2010, replace
	
	
/* PART 3 : ---- The Complete Individual file -----*/
/* Generation of one unique dataset with all the individuals */
 
 
use ../data/Individ2001, clear
 
forvalues y = 2002/2010 {
	quietly append using ../data/Individ`y'
	count
	}
/* For duplicates, the hypothesis is that :
	a same Household number, gender, year of birth = same individual ( cf def of ID) */
di ""
di " Duplicates computed on the pooled file"
	
duplicates report nopnltNF Sexe ana 
duplicates drop nopnltNF Sexe ana , force

order Id nopnltNF indiv Sexe nf  ihau ipds ana an

compress
label data "Individual File all years with BMI and personnal information"
notes : Created using FileMaker3.do ($S_DATE). All unique Individuals
notes : One line = one individual (unique ID per year), no duplicates)

save ../data/IndividAll5, replace

log close
