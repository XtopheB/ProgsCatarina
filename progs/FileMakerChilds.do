/* 25/10/2010 :  Creation des fichiers des individus à partir des fichiers ménages */
/*  			On utilise les fichiers Household2001  -2010.dta  en entrée        */
/* 				création des fichiers ou seuls les ménages avec enfants sont retenus*/


set more off

*global root "c:/Chris/progs/catarina/"
*global root "D:/progs/catarina/"
global root "c:/Chris/Zprogs/catarina/"

cd $root
capture log close

log using "$root/progs/logs/FileMakerChild_$S_DATE.smcl", replace 
cd progs
/* PART 1 : Generation of files with at least one child 
		-  Files at individuals level from the individual files */

forvalues y = 2001/2010 {
	/* ----  We use the Individual Files    ---- */
	use ../data/Individ`y'.dta, clear
	drop if nf == 1   /* we keep only families  */
	gen Status = "Parent"
	replace Status = "Enfant" if Age<20	
	
	/* Variables changing with years */
	gen BMI`y' = BMI
	gen ihau`y' = ihau
	gen ipds`y' = ipds
	gen Age`y' = Age
	/* cleaning  */
	di " drop BMI null "
	count if BMI`y' == 0  
	di ""
	drop if BMI`y' == 0  
	drop BMI ipds ihau Age
	keep nopnltNF Id indiv Sexe nf ana ihau* ipds* BMI* Age* Year20 an Status
	duplicates drop Id, force       /* on a des doublons avec des BMI différents (mais peu !)*/
	sort Id
	compress
	save ../data/IndividFam`y', replace
}


/* PART 2 : Create sets with BMI difference for consecutive years   -----*/
/* create files with parents & separate file with parents present for consecutive years   */
/* create file with couples parents-cnhildren and BMI differences        */


/* On a toujours un pb en 2002 avec le BMI */

* initialement  on a testé sur 1 an de décalalage
*forvalues y1 = 2010(-1)2002 {
*local y2 = `y1' -1

forvalues y1 = 2010(-3)2004{
	local y2 = `y1' -3
	di ""
	di " -----    Différence year `y1'  - `y2'   ----------"
	di ""
	use ../data/IndividFam`y1', clear
	merge 1:1 Id using ../data/IndividFam`y2'.dta, noreport
	keep if _merge ==3
	drop _merge

/*  PART 3 : Separating the parents from their childs  */
	preserve 
	keep if Status == "Parent"
	gen DiffP`y1'_`y2' =  BMI`y1'-BMI`y2' if Status == "Parent"
	gen SexeParent = Sexe
	label value SexeParent typoSexeNew

	drop Sexe
	save ../data/IndividParent`y1'_`y2', replace
	sort nopnlt 
	restore

	keep if Status == "Enfant"
	gen DiffE`y1'_`y2' =  BMI`y1'-BMI`y2' if Status == "Enfant"
	gen SexeEnfant = Sexe
	label value SexeEnfant typoSexeNew
	drop Sexe
	save ../data/IndividEnfant`y1'_`y2', replace
	
	joinby nopnltNF using ../data/IndividParent`y1'_`y2'   /* <<<<<< ======= On crée tous les couples possibles   */
	
	quietly count
	local foo `r(N)'
	
	quietly count if( DiffE`y1'_`y2' != 0 & DiffP`y1'_`y2' != 0)  
	local spam `r(N)'
	di ""
	di " -----    We have `foo' obs. for couples `y1'  - `y2' and only `spam' different from 0  ----------"
	di ""
	
	merge n:1 nopnltNF using ../Sources/menages`y1' , ///
				keepusing(csp* habi rev* nocom noreg uc*  Region_insee Region Code_Commune foyer) noreport
	drop if _merge ==2  /* we don't need information form houshold not present */
	drop _merge			
	
	save ../data/Couples`y1'_`y2', replace
	
	/* Some cleaning to avaoid too much files   */
	erase ../data/IndividEnfant`y1'_`y2'.dta
	erase ../data/IndividParent`y1'_`y2'.dta
	
	
	/* Stats sur les Différences de BMI (attention on compte les individus plusisuers fois (car couples ici !! ) */
	
	regress DiffE`y1'_`y2' DiffP`y1'_`y2'   /* Marche */
	*regress DiffE`y1'_`y2' DiffP`y1'_`y2'   /* Marche aussi */
	regress DiffE`y1'_`y2' DiffP`y1'_`y2' if( DiffE`y1'_`y2' != 0 & DiffP`y1'_`y2' != 0)   /* marche moins bien */ 
	
	
	
	corr DiffE`y1'_`y2' DiffP`y1'_`y2' 
	twoway lfitci DiffE`y1'_`y2' DiffP`y1'_`y2'  , stdf || scatter DiffE`y1'_`y2' DiffP`y1'_`y2' 
}
	

*bysort SexeEnfant : regress DiffE10_09 DiffP10_09    /* Marche  pour les filles   !!!!   */
*bysort SexeParent : regress DiffE10_09 DiffP10_09    /* Marche  pour les papas (mais pas nombreux !)   */


capture log close
/* END */
