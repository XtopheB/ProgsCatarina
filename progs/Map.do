/* 19/08/2010 :  Map of the individuals of our global sample  */
/* Maps of Mean departemetal Heights  fo men and Women  */
/* 02/04/2013 : Update of Individual file AllIndividual5  */ 

set more off
set autotabgraphs on , permanently
use ../data/IndividAll5.dta, clear 
keep if Age > 18
count
global Nsample =`r(N)'
keep  Id Dept Region Region_insee Code_Commune
gen Idnum=_n


collapse (count) Idnum , by( Dept)
ren Idnum NbIndiv

gen spam=Dept+1000
tostring spam, gen(toto) 
gen CODE_DEPT=substr(toto, 3,4)
sort CODE_DEPT

drop toto
drop spam

/*On récupère l'id de IGN et le fond de carte */

merge CODE_DEPT using ../Sources/frdb.dta  
tab _merge
drop _merge

/* On récupère la population Française (recencement de 2005 ??) */
sort CODE_DEPT 
merge CODE_DEPT using ../Sources/PopDep2005.dta  

preserve
/* Men average Height  */
use ../data/IndividAll5.dta, clear 
numlabel typoSexeNew, add
keep Id ihau Dept Sexe
keep if Sexe == 1 /*MEN */
count
global Nmen `r(N)'
collapse ihau , by (Dept)
ren ihau MeanMenHeight
sort Dept
save ../data/HeightMenDept5.dta, replace

/* women average height */
use ../data/IndividAll5.dta, clear 
numlabel typoSexeNew, add

keep Id ihau Dept Sexe
keep if Sexe == 2 /* Women */
count
global Nwomen =`r(N)'
collapse ihau , by (Dept)
ren ihau MeanWomenHeight
sort Dept
save ../data/HeightWomenDept5.dta, replace
restore

/* recovering Men's height by departement */
capture drop _merge 
sort Dept 
merge Dept using ../data/HeightMenDept5.dta

/* recovering Women's height by departement */
capture drop _merge 
sort Dept 
merge Dept using ../data/HeightWomenDept5.dta

/* MAPS  */

/* Distribution of the Population in 2005  */

spmap total2005  using ../Sources/francecoord.dta if id<97, id(id) fcolor(Reds2) ocolor(none ..)   ///
title("French Population", size(*0.8)) ///
clmethod(quantile) clnumber(5) name(FrancePop, replace)   
graph export "Graphics\FrenchMap.pdf", as(pdf) replace  
 
/* Distributionnal Map of the whole sample  */

spmap  NbIndiv using ../Sources/francecoord.dta if id<97, id(id) fcolor(Reds2) ocolor(none ..)   ///
title("Sample geographic distribution, $Nsample obs.", size(*0.8)) ///
clmethod(quantile) clnumber(5) name(Population, replace)       
graph export "Graphics\KantarSampleMap.pdf", as(pdf) replace  

/* Heights in France  */

spmap  MeanMenHeight using ../Sources/francecoord.dta if id<97, id(id) fcolor(Reds2) ocolor(none ..) ///
title("Height Distribution (Men), $Nmen obs.", size(*0.8)) ///
clmethod(quantile) clnumber(5)  name(HeightMen, replace)  
graph export "Graphics\MenHeightMap.pdf", as(pdf) replace  
     

spmap  MeanWomenHeight using ../Sources/francecoord.dta if id<97, id(id) fcolor(Reds2) ocolor(none ..) ///
title("Height Distribution (Women) $Women obs.", size(*0.8)) ///
clmethod(quantile) clnumber(5) name(HeightWomen, replace)       
graph export "Graphics\WomenHeightMap.pdf", as(pdf) replace  



/* Height over Time  */

use ../data/IndividAll5.dta, clear 
keep if Age > 18
numlabel typoSexeNew, add
count
tab Sexe
keep if Sexe == 1 /*MEN */
count
graph box ihau if Year20>1940  , over(Year20, label(angle(-90)))  noout medline(lcolor(red)) medtype(cline) ////
					title("Height Distribution (Men), `r(N)' obs.", size(*0.8)) ///
					subtitle("Height at the age of 20, 1940-2011")
graph export "Graphics\MenHeightTrend.pdf", as(pdf) replace  

use ../data/IndividAll5.dta, clear 
keep if Age > 18
numlabel typoSexeNew, add

keep if Sexe == 2 /*WOMEN */
count
graph box ihau if Year20>1940  , over(Year20, label(angle(-90)))  noout medline(lcolor(red)) medtype(cline) ////
					title("Height Distribution (Women), `r(N)' obs.", size(*0.8)) ///
					subtitle("Height at the age of 20, 1940-2011")

graph export "Graphics\WomenHeightTrend.pdf", as(pdf) replace  


 



