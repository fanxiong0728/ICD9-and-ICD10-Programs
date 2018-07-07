*-------------------------------------------------------------------*
 *  Author:  Fan Xiong            <fanxiong0728@gmail.com>           *
*-------------------------------------------------------------------*

/*This SAS macro relies on the using the CMS ICD-10-CM Table of Diagnosis Codes to extract specific poisoning cases of interest. */

/*There tens of thousands of ICD-10-CM diagnosis code. It's more efficient to extract only records of interest*/

/*Data: This program was used on ICD-10-CM Hospital Discharge Claims*/

%macro ManipulateHD (YEAR=);
%include 'C:\TEMP\Medical Discharges\SAS CONNECT PROGRAMS for HD\FX_COUNTY CODES AND REGIONS MASTER LIST.sas' / source2;
LIBNAME ICD10CM "C:\TEMP\Space\Projects";

/*IMPORT ICD-10-CM Table of Drugs and Chemicals*/

%LET DOWNLOAD = C:\TEMP\Space\Projects\;
%include "C:\TEMP\Space\Projects\UNZIP CMS ICD10CM.sas";

/*CREATE REGULAR EXPRESSION MACROS*/
%LET ICD10CM_GROUP = POISON; /*SPECIFY THE ICD-10-CM GROUPING--> IT IS EASIER (MORE SENSITIVE) TO MATCH THE FIRST WORD*/
%LET ICD10CM_CHAPTERS = "T36" <= SUBSTR(ICD10CM,1,3) <= "T50" ;  /*INCLUDE ICD-10-CM CODES BASED ON CHAPTERS*/
%LET ICD10CM_EXCLUDE = PRXMATCH("/UNDERDOSING|ADVERSE EFFECT/",LABEL) = 0;  /*EXCLUDE ICD-10-CM T36-250 WITH ADVERSE EFFECTS OR UNDERDOSING*/
%LET ICD10CM_INCLUDE = PRXMATCH("/INIT|SUBS/",LABEL) > 0; /*INCLUDE DIAGNOSIS CODES FOR INITIAL AND SUBSEQUENT ENCOUNTERS*/

PROC SQL NOPRINT; 
SELECT distinct COMPRESS(icd10cm) INTO: REGEX&ICD10CM_GROUP SEPARATED BY "|" 
		FROM Fy2016icdcms 
		WHERE ((HIPPA = "1") AND (PRXMATCH("/&ICD10CM_GROUP/",label) > 0) AND (&ICD10CM_EXCLUDE) AND (&ICD10CM_INCLUDE));

SELECT distinct quote(COMPRESS(icd10cm)) INTO: list&ICD10CM_GROUP SEPARATED BY "," 
		FROM Fy2016icdcms 
		WHERE ((HIPPA = "1") AND (&ICD10CM_CHAPTERS) and (PRXMATCH("/&ICD10CM_GROUP/",label) > 0) AND (&ICD10CM_EXCLUDE) AND (&ICD10CM_INCLUDE));

SELECT distinct quote(COMPRESS(icd10cm)) INTO: OPIATES SEPARATED BY "," 
		FROM Fy2016icdcms 
		WHERE ((HIPPA = "1") AND (SUBSTR(ICD10CM,1,3) = "T40") and (PRXMATCH("/COCAINE/",label) = 0) AND (&ICD10CM_EXCLUDE) AND (&ICD10CM_INCLUDE));

QUIT;

DATA HD.KSICD10&YEAR (KEEP=ID FY BIRTHYEAR BIRTHMONTH YEAR YEARQTRA YEARQTRD age agecat agecat2 sex race 
ETHNICITY PRINCIPALDRUG multipledrug OPIATES ICD10_F3 primdiag secdiag: CNTYCODE);
/*SET ALL HD SAS VIEWS*/
SET HD.KHA&YEAR;

/*Create a numeric summary count variable for the number of discharges*/
DISCHARGE=1;

/*Create a de-identified Unique ID*/
/*Control is a record locator number*/
LENGTH ID $36.;
ID=TRIM(CATX("|",CONTROL, SEX, RACE, ETHNICITY)); 

/*Create Admission/Discharge Datte Year-Qtr Variable*/
LENGTH YEARQTRA YEARQTRD $10.;
YEARQTRA=COMPRESS(PUT(ADATE,YYQ10.)); /*admission date year-qtr*/
YEARQTRD=COMPRESS(PUT(DDATE,YYQ10.)); /*discharge date year-qtr*/

/*For cohort specific analysis*/
BIRTHYEAR=YEAR(bdate);
BIRTHMONTH=MONTH(bdate);
BIRTHDAY=DAY(bdate);

age = abs(YEAR-BIRTHYEAR);  /*age is the number of years seperating the discharge year and birthyear*/

*age categories; 
 if 0<=age<1    then agecat=1;
 else if 1 <=age<5  then agecat=2;
 else if 5 <=age<15 then agecat=3;
  else if 15<=age<25 then agecat=4;
  else if 25<=age<35 then agecat=5;
  else if 35<=age<45 then agecat=6;
  else if 45<=age<55 then agecat=7;
  else if 55<=age<65 then agecat=8;
  else if 65<=age<75 then agecat=9;
  else if 75<=age<85 then agecat=10;
  else if 85<=age<=120  then agecat=11;
	ELSE agecat=.; 

length agecat2 $12.;
agecat2=COMPRESS(PUT(AGEcat, agecat_f.));

/*Principal/Primary Diagnosis Code Drug Poisoning Scan*/
if PRIMDIAG IN (&&list&ICD10CM_GROUP) then PRINCIPALDRUG =1;
ELSE PRINCIPALDRUG=0;

	/*Add other drug poisoning codes as needed*/

/*Any/All Mentioned Drug Poisoning Scan*/
multipledrug=0;OPIATES=0;
array anydiagx (*) primdiag secdiag1-secdiag65;
do i = 1 to dim(anydiagx);

/*all specified drug poisonings*/
    IF anydiagx[i] IN (&&list&ICD10CM_GROUP) THEN multipledrug+1;
/*all opioid drug poisonings*/
    IF anydiagx[i] IN (&OPIATES) THEN OPIATES+1;


    /*Leave row if diagnosis code is blank (i.e. end of non-missing diagnosis code fields)*/
    ELSE IF anydiagx[i] = "   " THEN LEAVE;
END;

	 RUN;

	 %MEND;
