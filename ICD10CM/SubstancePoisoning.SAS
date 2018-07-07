*-------------------------------------------------------------------*
 *  Author:  Fan Xiong            <fanxiong0728@gmail.com>           *
*-------------------------------------------------------------------*

/*This SAS Program outputs diagnosis codes for mental health disorder due psychoactive substance use and drug poisoning ICD-10-CM diagnosis codes for data validation and assurance*/
/*The result was a summary table by Kansas Trauma and Emergency Medical Services Region of the diagnosis code used. Analysis was followed for any incomplete ICD-10-CM diagnosis codes and comparisons of variation in coding practices*/

%include "C:\TEMP\Medical Discharges\SAS CONNECT PROGRAMS for HD\REMOTE SAS SESSIONS EXAMPLE FOR HD.sas" / source2;
RUN;

DATA ICD10DRUGF3 (KEEP=CNTYNAME NEWCNTYFIPS HRPN HRPN_NAME TRAUMA TRAUMA_NAME ID YEAR YEARQTRD YEARQTRA PRINCIPALDRUG AGECAT AGECAT2 SEX RACE BIRTHYEAR multipledrug DISCHARGE DXF3 i);
SET HD.Ksicd102015 HD.Ksicd102016provisional;
WHERE PRINCIPALDRUG+multipledrug GE 1;
DISCHARGE=1;
LENGTH DXF3 $3.;
array dx (*) primdiag secdiag1-secdiag65;
do i = 1 to dim(dx);
if dx[i] NE "   " THEN DO;
DXF3=COMPRESS(SUBSTR(dx[i],1,3));
OUTPUT;
END;
END;
RUN; 

PROC FORMAT LIBRARY=HD;
VALUE $DXF3DRUG 
"F11"  ="Opioid related disorders"
"F12"  ="Cannabis related disorders"
"F13"  ="Sedative, hypnotic, or anxiolytic related disorders"
"F14"  ="Cocaine related disorders"
"F15"  ="Other stimulant related disorders"
"F16" ="Hallucinogen related disorders"
"F18"  ="Inhalant related disorders"
"F19"  ="Other psychoactive substance related disorders"
"T36" = "Poisoning by systemic antibiotics"
"T37" = "Poisoning by other systemic anti- infectives and antiparasitics"
"T38" = "Poisoning by hormones and their synthetic substitutes and antagonists, not elsewhere classified"
"T39"  = "Poisoning by nonopioid analgesics, antipyretics and antirheumatics"
"T40"  = "Poisoning by narcotics and psychodysleptics [hallucinogens]"
"T41"  = "Poisoning by anesthetics and therapeutic gases"
"T42"  = "Poisoning by antiepileptic, sedative- hypnotic and antiparkinsonism drugs"
"T43"  = "Poisoning by psychotropic drugs, not elsewhere classified"
"T44"  = "Poisoning by drugs primarily affecting the autonomic nervous system"
"T45"  = "Poisoning by primarily systemic and hematological agents, not elsewhere classified"
"T46"  = "Poisoning by agents primarily affecting the cardiovascular system"
"T47"  = "Poisoning by agents primarily affecting the gastrointestinal system"
"T48"  = "Poisoning by agents primarily acting on smooth and skeletal muscles and the respiratory system"
"T49"  = "Poisoning by topical agents primarily affecting skin and mucous membrane and by ophthalmological, otorhinorlaryngological and dental drugs"
"T50"  = "Poisoning by diuretics and other and unspecified drugs, medicaments and biological substances"

OTHER  = "Potentially Not Drug-related";

RUN;

PROC FREQ DATA=ICD10DRUGF3 NOPRINT;
TABLES AGECAT*AGECAT2*TRAUMA_NAME*DXF3 / out=ICDF3ANY noprint list;
WHERE  (PRINCIPALDRUG+multipledrug) GE 1 AND YEAR = 2016;
FORMAT DXF3 $DXF3DRUG.;
run;

proc sort data=ICDF3ANY OUT=HD.ICDF3ANY2;
by TRAUMA_NAME DXF3 AGECAT;
WHERE TRIM(PUT(DXF3,$DXF3DRUG.)) NE "Potentially Not Drug-related";
PROC TRANSPOSE DATA=HD.ICDF3ANY2 OUT=HD.ICDF3ANY3 (KEEP=DXF3 AGE1-AGE11)  PREFIX=AGE;
BY TRAUMA_NAME DXF3;
VAR COUNT;
ID AGECAT;
IDLABEL AGECAT2;
RUN;


PROC FREQ DATA=ICD10DRUGF3 NOPRINT;
TABLES AGECAT*AGECAT2*TRAUMA_NAME*DXF3 / out=ICDF3PRINC noprint list;
WHERE PRINCIPALDRUG=1 AND YEAR = 2016;
FORMAT DXF3 $DXF3DRUG.;
proc sort data=ICDF3PRINC OUT=HD.ICDF3PRINC2;
by TRAUMA_NAME DXF3 AGECAT;
WHERE TRIM(PUT(DXF3,$DXF3DRUG.)) NE "Potentially Not Drug-related";

PROC TRANSPOSE DATA=HD.ICDF3PRINC2 OUT=HD.ICDF3PRINC3 (KEEP=DXF3 AGE1-AGE11) PREFIX=AGE;
BY TRAUMA_NAME DXF3;
VAR COUNT;
ID AGECAT;
IDLABEL AGECAT2;
RUN;
