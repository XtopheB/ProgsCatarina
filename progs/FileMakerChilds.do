/* 25/10/2010 	: Creation des fichiers des individus à partir des fichiers ménages */
/*  			: On utilise les fichiers Household2001  -2010.dta  en entrée        */
/* 				: création des fichiers ou seuls les ménages avec enfants sont retenus*/
/* 28/11/2012  	: Définition des parents enfants revue avec catarina  On utilise age (18 ans) */
/* 				: On vérifie les couples parents enfants ont une différence d'age suffisante (>=16 ans)  */
/* 				: creation d'un fichier avec tous les couples pour un mêmee lag 				*/



set more off 
pause on

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
	
	/* Hypothèses sur la famille */
	drop if nf == 1   /* we keep only families  */
	gen Status = "Parent"
	replace Status = "Enfant" if Age<18	
	
	/* Variables changing with years */
	ren  BMI BMI`y' 
	ren  ihau ihau`y' 
	ren  ipds ipds`y' 
	ren  Age Age`y' 
	
	keep nopnltNF Id indiv Sexe nf ana ihau* ipds* BMI* Age* Year20 an Status
	*duplicates drop Id, force       /* normalement ==0 */
	sort Id
	label data "All individuals WITHIN a familly with separate information between parent Child"
	notes  : Created using FileMakerChild.do (_$S_DATE). 
	compress
	save ../data/IndividFam`y', replace
}


/* PART 2 : Create sets with BMI difference for consecutive years   -----*/
/* create files with parents & separate file with parents present for consecutive years   */
/* create file with couples parents-children and BMI differences        */


/* On a toujours un pb en 2002 avec le BMI */

* initialement  on a testé sur 1 an de décalalage
*forvalues y1 = 2010(-1)2002 {
*local y2 = `y1' -1

* Variante sur 2 ans de décalalage
*forvalues y1 = 2010(-2)2003 {
*local y2 = `y1' -2

/* On automatise la création des différences  (28/11/2012)*/

local lag 2     /* <<<<<<<<<<<< Choice of  lag between two years  */

local yearfin= 2001+`lag'
forvalues y1 = 2010(-`lag')`yearfin'{
	local y2 = `y1' -`lag'
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
	
	ren Age`y1'  AgeParent`y1'
	ren Sexe SexeParent 
	*label value SexeParent typoSexeNew
	
	save ../data/IndividParent`y1'_`y2', replace
	sort nopnlt 
	restore

	keep if Status == "Enfant"
	gen DiffE`y1'_`y2' =  BMI`y1'-BMI`y2' if Status == "Enfant"
	
	ren Sexe SexeEnfant 
	ren Age`y1'  AgeEnfant`y1' 
	*label value SexeEnfant typoSexeNew

	save ../data/IndividEnfant`y1'_`y2', replace
	
	joinby nopnltNF using ../data/IndividParent`y1'_`y2'   /* <<<<<< ======= On crée tous les couples possibles   */
	
	di ""
	di " -----    Creation des couples : vérifications "
	di ""
	quietly count
	local Nball `r(N)'
	
	gen DiffAge`y1' = AgeParent`y1' - AgeEnfant`y1' 
	quietly count if DiffAge`y1' <16
	local noson `r(N)'
	
	di " -----    We have `noson' obs (on `Nball' couples) with less than 16 years difference  (removed) "
	drop if DiffAge`y1' <16
	
	quietly count
	local Nball `r(N)'
	quietly count if( DiffE`y1'_`y2' != 0 & DiffP`y1'_`y2' != 0)  
	local spam `r(N)'
	di ""
	di " -----    We have now `Nball' obs. for couples `y1' - `y2' and only `spam' BMI different from 0  ----------"
	di ""
	
	/* On réincorpore les information au niveau du ménage, pour l'année y1 pour les régressions  */
	merge n:1 nopnltNF using ../Sources/menages`y1' , ///
				keepusing(csp* habi rev* nocom noreg uc*  Region_insee Region Code_Commune foyer) noreport
				
	drop if _merge ==2  /* we don't need information form houshold not present */
	drop _merge			

	label data "All pairwise couples (Child-Parents) with information on BMI's differences"
	notes  : Created using FileMakerChild.do (_$S_DATE). 
	compress
	save ../data/Couples`y1'_`y2', replace
	
	/* Some cleaning to avoid too much files   */
	erase ../data/IndividEnfant`y1'_`y2'.dta                /* <====== WE CLEAR HERE   */
	erase ../data/IndividParent`y1'_`y2'.dta
	
	
	/* Stats sur les Différences de BMI (attention on compte les individus plusisuers fois (car couples ici !! ) */
		
	di " -----    regress DiffE`y1'_`y2' DiffP`y1'_`y2'   ----------"
	
	regress DiffE`y1'_`y2' DiffP`y1'_`y2'   /* Marche */
		
	di " -----    regress DiffE`y1'_`y2' DiffP`y1'_`y2' but Zero's (either parent or Child) removed  ----------"
	
	local Nonzero "( DiffE`y1'_`y2' != 0 & DiffP`y1'_`y2' != 0)"
	
	regress DiffE`y1'_`y2' DiffP`y1'_`y2' if `Nonzero'   /* marche moins bien */ 
	
	* Graphiques
	
	twoway lfitci DiffE`y1'_`y2' DiffP`y1'_`y2'  , stdf || scatter DiffE`y1'_`y2' DiffP`y1'_`y2' 
	
	*twoway lfitci DiffE`y1'_`y2' DiffP`y1'_`y2' if `Nonzero'   , stdf || scatter DiffE`y1'_`y2' DiffP`y1'_`y2' if `Nonzero' 
	*corr DiffE`y1'_`y2' DiffP`y1'_`y2'
	
	*pause On regarde le graphique (taper q pour reprendre)
}

/* Generation of one unique dataset with all the couples differences */

local yearfin2 = `yearfin' + `lag'   /* On part du fichier de la fin, pas la peine de l'appender 2 fois */
forvalues y1 = 2010(-`lag')`yearfin2'{
	local y2 = `y1' -`lag'
	di "  "
	di " --- We append now the file Couples`y1'_`y2'.dta ---"
	quietly append using ../data/Couples`y1'_`y2'
	count
	}

compress
label data "All pairwise couples with `lag' year lag (Child-Parents)"
notes : Created using FileMaker3.do ($S_DATE). All unique Individuals
count
save ../data/Couples2001-2010_Lag`lag', replace	


capture log close
/* END */
