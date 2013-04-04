/* 25/10/2010 	: Creation des fichiers des individus à partir des fichiers ménages */
/*  			: On utilise les fichiers Household2001 -2010.dta  en entrée        */
/* 				: création des fichiers ou seuls les ménages avec enfants sont retenus*/
/* 28/11/2012  	: Définition des parents enfants revue avec catarina  On utilise age (18 ans) */
/* 				: On vérifie les couples parents enfants ont une différence d'age suffisante (>=16 ans)  */
/* 				: creation d'un fichier avec tous les couples pour un mêmee lag 				*/
/* 				: Information sur les jumeaux en France (environ 9-11/1000), de 1972 à 1989  */
/* 				: Source http://onlinelibrary.wiley.com/doi/10.1111/j.1471-0528.1993.tb12985.x/abstract */
/* 11/12/2012	: Suppression des BMI trop faibles (<10) ou trop forts (>50)                            */
/* 				: Suppression des différences de BMI vraiment fortes (>10 )  <<< à moduler suivant le lag ??   */
/* 8/01/2013	: Suppression des Parents dont la taille varie  												*/
/*				: Nouvelle définition des variation pour Enfants (distance au mode!) 							*/ 
/* 28/01/2013 	: Incoporation des BMI enfants Français (utilisation des données LMC cf file "LMS et centiles à envoyer xls  valeurs.xlsx" 		*/
/* 31/01/2013   : Création de BMI2med = BMI-Mediane IMC Français pour les enfants       */


set more off 
pause on

global root "D:/progs/catarina/"
*global root "c:/Chris/Zprogs/catarina/"

cd $root
capture log close

log using "$root/progs/logs/FileMakerChild_$S_DATE.smcl", replace 
cd progs
/* Part 0 : Generation of French IMC data Files  */
clear
foreach CharSexe in Girls Boys {
	clear
	capture insheet using ..\Sources\LMS`CharSexe'.csv, delimit(";")
	di " le fichier est celui des `CharSexe' "
	rename age Age
	gen Sexe = 1+ ("`CharSexe'"== "Girls")       /* 1= Boys, 2=Girls */
	save ..\data\LMS`CharSexe'.dta, replace
	}
	
use ..\data\LMSBoys.dta , clear
append using ..\data\LMSGirls.dta 
save  ..\data\LMSAll.dta , replace

graph twoway (rarea  v7 v9 Age if Sexe==1 & Age <=21,  fintensity(inten10)) ///
			(rarea v7 v9 Age if Sexe==2 & Age <=21, fintensity(inten10)) ///
			(line  v8 Age if Sexe==1 & Age <=21,lcolor(navy) )   ///
			(line  v8 Age if Sexe==2 & Age <=21,lcolor(cranberry ) )
			

/* PART 1 : Generation of files with at least one child 
		-  Files at individuals level from the individual files */

forvalues y = 2001/2010 {
	/* ----  We use the Individual Files    ---- */
	use ../data/Individ`y'.dta, clear
	
	/* Hypothèses sur la famille */
	drop if nf == 1   /* we keep only families  */
	gen Status = "Parent"
	replace Status = "Enfant" if Age<18	
	
	/* 	NewDef of BMI variation for Childs (08/01/2013) */
	/*(cf Thibault et al. 2010 http://www.sciencedirect.com/science/article/pii/S0929693X10004185# */ 
	/*  ba = bmi-for-age */
	
	egen Zscore = zanthro(BMI,ba,US) if Status=="Enfant", xvar(Age) gender(Sexe) gencode(male=1, female=2) ageunit(year) 
	
	/* CREATION DES BMI par AGE et Sexe pour les enfants  */
	/* Rolland-Cachera MF, Cole TJ, Sempé M, Tichet J, Rossignol C, Charraud A.      */
	/* "Body Mass Index variations: centiles from birth to 87 years". Eur J Clin Nutr 1991;45:13-21		*/								
	
		
	merge n:1 Age Sexe using ..\data\LMSAll.dta, keepusing(v8)
	rename v8 IMCp50
	gen BMI2med = BMI - IMCp50 if Age <=21		
	drop _merge
	
	
	/* CHECKS    :   SUPPRESSION BMI importants  11/12/2012 */
	drop if BMI <10 | BMI >50
	
	/* Variables changing with years */
	ren  BMI BMI`y' 
	ren  ihau ihau`y' 
	ren  ipds ipds`y' 
	ren  Age Age`y' 
	ren  Zscore  Zscore`y'
	ren  BMI2med BMI2med`y'
	
	keep nopnltNF Id indiv Sexe nf ana ihau* ipds* BMI* Age* Zscore Year20 an Status
	*duplicates drop Id, force       /* normalement ==0 */
	sort Id
	label data "All individuals WITHIN a familly with separate information between Parent or Child"
	notes  : Created using FileMakerChild.do (_$S_DATE). Z-score included, Unprobable BMI removed
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
local VarBMI BMI2med  /* <<<- choix de la variable BMI pour les enfants = BMI ou Zscore ou BMI2Med   */


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
		gen DiffP`y1'_`y2' =  BMI`y1'-BMI`y2' 

		ren Age`y1'  AgeParent`y1'
		ren Sexe SexeParent 
		
		/* Check on Height difference  */
		
		gen DiffHeight`y1'_`y2' =  ihau`y1'-ihau`y2' 
		drop if abs(DiffHeight`y1'_`y2')>5	& DiffHeight`y1'_`y2' !=. /* Suppression des variation de taille importantes  */
		
		*label value SexeParent typoSexeNew
		sort nopnlt
		
		label data "Individual PARENT file  between`y1'_`y2'"
		notes  : Created using FileMakerChilds.do ($S_DATE). Checks on Height variation done 
		save ../data/IndividParent`y1'_`y2', replace
	restore

	keep if Status == "Enfant"
	*gen DiffE`y1'_`y2' =  BMI`y1'-BMI`y2' 
	gen DiffZ`y1'_`y2' =  Zscore`y1'-Zscore`y2'
	gen DiffE`y1'_`y2' =  `VarBMI'`y1'-`VarBMI'`y2'       /*  modif pour généricité ici (31/01/2013)  */
	
	ren Sexe SexeEnfant 
	ren Age`y1'  AgeEnfant`y1' 
	*label value SexeEnfant typoSexeNew 
	
	label data "Individual CHILD file  between`y1'_`y2'"
	notes  : Created using FileMakerChilds.do ($S_DATE). 
	save ../data/IndividEnfant`y1'_`y2', replace
	joinby nopnltNF using ../data/IndividParent`y1'_`y2'   /* <<<<<< ======= On crée tous les couples possibles   */
	di " -----    Creation des couples : vérifications "
	di ""
	quietly count
	local Nball `r(N)'
	
	/* On supprime les grosses différences  (11/12/2012) */
	drop if abs(DiffE`y1'_`y2') > 10  | abs(DiffP`y1'_`y2') >10
	
	gen DiffAge`y1' = AgeParent`y1' - AgeEnfant`y1' 
	quietly count if DiffAge`y1' <16
	local noson `r(N)'
	
	di " We have `noson' obs. (on `Nball' couples) with less than 16 years difference (removed) "
	di " "
	drop if DiffAge`y1' <16
	
	quietly count 
	local Nball `r(N)'
	quietly count if( DiffE`y1'_`y2' != 0 & DiffP`y1'_`y2' != 0)  
	local spam `r(N)'
	di "-----"
	di "We have now `Nball' obs. for couples `y1' - `y2' "
	di " -->  and only `spam' for which the difference on `VarBMI'  (etiher parents or child) is different from 0 "
	di "-----"
	
	/* On réincorpore les information au niveau du ménage, pour l'année y1 pour les régressions  */
	merge n:1 nopnltNF using ../Sources/menages`y1' , ///
				keepusing(csp* habi rev* nocom noreg uc*  Region_insee Region Code_Commune foyer ) noreport
				
	drop if _merge ==2  /* we don't need information form houshold not present (households with no childs) */
	drop _merge			

	label data "All pairwise couples (Child-Parents) with information on BMI's differences"
	notes  : Created using FileMakerChild.do (_$S_DATE). 
	compress
	save ../data/Couples`y1'_`y2', replace
	
	/* Some cleaning to avoid too much files   */
	erase ../data/IndividEnfant`y1'_`y2'.dta                /* <====== WE CLEAR HERE   */
	erase ../data/IndividParent`y1'_`y2'.dta
	
	/* Stats sur les Différences de BMI (attention on compte les individus plusisuers fois (car couples ici !! ) */
		
	di " -----   Variable `VarBMI' used for Childs ;   regress DiffE`y1'_`y2' DiffP`y1'_`y2'   ----------"
	regress DiffE`y1'_`y2' DiffP`y1'_`y2'   /* Marche */
	outtex, level plain  title("Regression DiffE`y1'-`y2' on DiffP`y1'-`y2'" ) ///
			file("Tables/Reg`y1'_`y2'C.tex") replace
	eststo Reg`y1'_`y2'C
			
	di " -----    regress DiffE`y1'_`y2' DiffP`y1'_`y2' For Mother    ----------"
	regress DiffE`y1'_`y2' DiffP`y1'_`y2' if SexeParent==	2
	outtex, level plain  title("Regression DiffE`y1'-`y2' on DiffP`y1'-`y2' (Mother only)" ) ///
			file("Tables/Reg`y1'_`y2'MO.tex") replace
	eststo Reg`y1'_`y2'MO
	
	di " -----    regress DiffE`y1'_`y2' DiffP`y1'_`y2' if Zero's (either parent or Child) removed  ----------"
	local Nonzero "( DiffE`y1'_`y2' != 0 & DiffP`y1'_`y2' != 0)"
	regress DiffE`y1'_`y2' DiffP`y1'_`y2' if `Nonzero'   /* marche moins bien */ 
	outtex, level plain  title("Regression DiffE`y1'-`y2' on DiffP`y1'-`y2' (zeros excluded)" ) ///
			file("Tables/Reg`y1'_`y2'ZE.tex") replace
	
	eststo Reg`y1'_`y2'ZE
	
	di " -----    regress DiffE`y1'_`y2' DiffP`y1'_`y2' For Mother & Zeros excluded    ----------"
	regress DiffE`y1'_`y2' DiffP`y1'_`y2' if  `Nonzero' & SexeParent==	2
	outtex, level plain  title("Regression DiffE`y1'-`y2' on DiffP`y1'-`y2' (Mother only, zeros excluded)" ) ///
			file("Tables/Reg`y1'_`y2'MOZE.tex") replace
	eststo Reg`y1'_`y2'MOZE
		
	* Graphiques
	
	*twoway lfitci DiffE`y1'_`y2' DiffP`y1'_`y2'  , stdf || scatter DiffE`y1'_`y2' DiffP`y1'_`y2' 
	
	*twoway lfitci DiffE`y1'_`y2' DiffP`y1'_`y2' if `Nonzero'   , stdf || scatter DiffE`y1'_`y2' DiffP`y1'_`y2' if `Nonzero' 
	*corr DiffE`y1'_`y2' DiffP`y1'_`y2'
	*di " -----  Z-Scores  "
	*di " -----  regress DiffZ`y1'_`y2' DiffP`y1'_`y2'   ----------"
	*regress DiffZ`y1'_`y2' DiffP`y1'_`y2'   
	*di " -----  regress DiffZ`y1'_`y2' DiffP`y1'_`y2' if  Zero's (either parent or Child) removed  ----------"
	*regress DiffZ`y1'_`y2' DiffP`y1'_`y2'  if  `Nonzero'  
	*twoway lfitci DiffZ`y1'_`y2' DiffP`y1'_`y2'  , stdf || scatter DiffZ`y1'_`y2' DiffP`y1'_`y2' 
	
	*pause /*On regarde le graphique (taper q pour reprendre)*/
}


esttab Reg*, mtitles("Reg `lag' lags"  " Reg ZE"  "Reg MO" "Reg MO+ZE")


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
