*-------------------------------------------------------------------*
*  Author:  Fan Xiong            <fanxiong0728@gmail.com>           *
*-------------------------------------------------------------------*

/*This SAS program relies on the use of a CALL Regular Expression Search to make it more easily modifable for EHR data and other clinical documents that may also contain ICD-9-CM diagnosis codes.*/

/*FOR DATA PRIOR TO OCTOBER 1st, 2015---->USE ICD-9 CM SAS CODE: COPY AND PASTE BELOW*/
/*ICD-9-CM SAS PROGRAM TO CLASSIFY EVENT AS A DRUG POISONING BY ALL PHARMACUTICAL POISONING AND INTENT*/
/*Case definition is defined by any mention of an N or E code: http://www.publichealthreports.org/issueopen.cfm?articleID=3254*/

%LET primdiag = ; /*Name of underlying cause or primary diagnosis NOTE: Leave blank for EDV dataset*/
%LET N = 207; /*Maximum number of contributing causes: 49 for EDV and 65 for HDD*/
%LET contribudiag = diag1-diag&N; /*Variable name of contributing causes*/ 

/*PRIMARY DIAGNOSIS IS A DRUG*/
*IF ("960" <= substr(&primdiag,1,3) <= "979") then prim_drug=1; /* TURN OFF FOR EDV: THERE IS NO PRIMARY DIAGNOSIS FIELD*/

/*At least one N-code is a drug poisoning: N-codes can give specific information about the specific drug involved---N codes do not tell intent*/
drug_dx=0;pharma_dx=0; RXopioid_dx=0;illopioid_dx=0;nec_n=0;benzo_n=0;psycho_n=0;
array dx [207] &primdiag &contribudiag;
array primdx [207] $;
do i = 1 to 207; 
if dx[i]= '    ' then leave; /*leave if blank*/
if substr(dx[i],1,1) NOT IN ('E','V') then do; /*Only N codes*/

    /*Drug Poisoning: All Drugs*/
	IF (960 <= substr(dx[i],1,3) <= 979) THEN do;
	drug_dx=drug_dx+1; *Check for any N code listed in the diagnosis fields;
	if drug_dx ge 1 then do; /*Number of drug codes*/
		primdx[i]=dx[i]; /*Listed drug codes*/
		end;
	end;

	IF substr(dx[i],1,5) IN (96500, 96502, 96509) THEN do;
	RXopioid_dx=RXopioid_dx+1; *Check for any N code listed in the diagnosis fields;
	end;

	IF substr(dx[i],1,5) IN (96501) THEN do;
	illopioid_dx=illopioid_dx+1; *Check for any N code listed in the diagnosis fields;
	end;

  /*Pharmaceutical Poisoning: Includes Prescription and Over-the-Counter Drug*/
	IF substr(dx[i],1,3) IN (960:964, 971:976, 978:979) or substr(dx[i],1,5) IN (96500, 96502, 96509) OR  substr(dx[i],1,4) IN (9651, 9654:9659, 9681:9684, 9686:9689, 9690:9695, 9698:9699, 9700:9701, 9709, 9770:9774) THEN do; *Check for any N code listed in the diagnosis fields;
	pharma_dx=pharma_dx+1; *Count the number of mentions of an N code listed in the diagnosis fields;
	end;

	/*Psychotropic agent*/
	IF substr(dx[i],1,3) IN (969) THEN do;
	nec_n=nec_n+1; *Check for any N code listed in the diagnosis fields;
	end;

	/*benzo*/
	IF substr(dx[i],1,4) IN (9694) THEN do;
	benzo_n=benzo_n+1; *Check for any N code listed in the diagnosis fields;
	end;

	/*psychostimulants*/
	IF substr(dx[i],1,4) IN (9697) THEN do;
	psycho_n=psycho_n+1; *Check for any N code listed in the diagnosis fields;
	end;

	end;
end;
/*At least one E-code is a drug poisoning*/
/*This is consistent with Svetla's definition*/
/*It provides the most sensitive method to reduce undercounts*/
drug_expression = prxparse('/E\d+/');   /*PERL EXPRESSION TO SEQUENTIALLY EXTRACT ONLY E-CODES FROM ANY DATASET WITH ICD CODES*/
start = 1;    /*SET START = 1 -----------------------------> TELLS SAS TO BEGIN SEARCHING AT THE FIRST E-CODE POSITION*/
stop = -1;  /*SET STOP = -1 -----------------------------> TELLS SAS TO STOP SEARCHING FOR AN E CODE AFTER IT READS A NON-CHARCTER BLANK (I.E. DELIMITER)*/
text = catx(",", of &contribudiag);/*TEXT ---------------> THE VARIABLES WITH ICD CODES SEPERATED BY ANY DELIMITER*/
/* Use PRXNEXT to find the first instance of the pattern, */     
/* then use DO WHILE to find all further instances.       */    
/* PRXNEXT changes the start parameter so that searching  */     
/* begins again after the last match.                     */    
/*This helps with processing E-codes where diagnosis codes may be in different columns more efficiently. It’s also more flexible to changes in searching for different diagnosis codes. This should be possible for any type of external injuries. Logically, it also makes more intuitive sense than a set of different ARRAYS*/
drug_mentions = 0; accident=0; suicide=0; homicide=0; undetermined=0; pharma=0; RXopioid=0; illopioid=0;psycho=0; nec=0; benzo=0;*/Start a counter;
array ICD9_ [207] $;
array drug_code_ecode [207] $;
do i = 1 to 207;
if text = '   ' then leave;
call prxnext(drug_expression, start, stop, text, position, length);    
	do while (position > 0);          
		ICD9_[i] = substr(text, position, length); 

		/*Drug Poisoning All Intents*/

		if substr(ICD9_[i], 2,3) IN (850:858) or substr(ICD9_[i],2,4) IN (9500:9505, 9620, 9800:9805) then DO; *Check for Any Mention Drug Ecodes;
		drug_mentions = drug_mentions+1; *Set up a counter for each valid ICD code that is a drug related external injury diagnosis code;	
		drug_code_ecode[i]=ICD9_[i]; *Strip the drug ICD code when there is a valid drug injury ICD code. This is used to check and make sure the code is processing correctly and to define the drug involved in the poisoning;
		end;

		/*Drug Poisoning: Unintentional*/
		IF substr(ICD9_[i], 2,3) IN (850:858) then do; 
			accident=accident+1; *Set up a counter for each valid ICD code that is an accidental drug related external injury diagnosis code;
				If accident ge 1 then do; 
				intent=1; *Accident intent;
			end;
		end;

		/*Drug Poisoning: Suicide*/
		if substr(ICD9_[i],2,4)  IN (9500:9505) then do;
		suicide=suicide+1; 
				If suicide ge 1 then do; *Set up a counter for each valid ICD code that is a suicide drug related external injury diagnosis code;
				intent=2; *Suicide intent;
			end;
		end;

		/*Drug Poisoning: Homicide*/
		if substr(ICD9_[i],2,4)  IN (9620) then do;
		homicide=homicide+1;  *Set up a counter for each valid ICD code that is a homicide drug related external injury diagnosis code;
				If homicide ge 1 then do; 
				intent=3; *Homicide intent;
			end;
		end;

		/*Drug Poisoning: Undetermined*/
		if substr(ICD9_[i],2,4)  IN (9800:9805)  then do;
		undetermined=undetermined+1; *Set up a counter for each valid ICD code that is an undetermined drug related external injury diagnosis code;
				If undetermined ge 1 then do; 
				intent=4; *Undetermined intent;
			end;
		end;

		/*Pharmaceutical Poisoning: Includes Prescription and Over-the-Counter Drug*/
/*For drug specific codes use any mention of a drug*/
		if substr(ICD9_[i],2,4) IN (8501:8509, 8540:8548, 8550:8559, 8580:8586, 9500:9503, 9801:9803) or substr(ICD9_[i],2,3) IN (851:853, 856:857) then do; 
		pharma=pharma+1; *Set up a counter for each valid ICD code that is a prescription drug related external injury diagnosis code. This will be used to defined the number of prescription drug poisoning;
		end;

		/*Prescription Opioid Poisoning*/
		if substr(ICD9_[i],2,4) IN (8501:8502) then do;
		RXopioid=RXopioid+1;
		end;

		/*Illicit Opioid Poisoning*/
		if substr(ICD9_[i],2,4) IN (8500) then do;
		illopioid=illopioid+1;
		end;

		/*Antidepressants, barbiturates and other antiepileptics, sedative-hypnotics, and psychotropic drugs not elsewhere classified*/
		if substr(ICD9_[i],2,3) IN (851:853) OR substr(ICD9_[i],2,4) IN (8540:8542, 8548, 8550, 9501:9503, 9801:9803) then do;
		NEC=NEC+1; 
		end;

		/*Benzo*/
		if substr(ICD9_[i],2,4) IN (8532) then do;
		benzo=benzo+1;
		end;

		/*Psychostimulants with abuse potential*/
		if substr(ICD9_[i],2,4) IN (8542) then do;
		psycho=psycho+1;
		end;

		/*Include this fix for a SAS bug with CALL PRXNEXT or else your PERL Expression will execute until the next Big Bang occurs (I.E. IT WON’T STOP)*/
		if start > stop then position = 0;     
		else           
		call prxnext(drug_expression, start, stop, text, position, length);    /*SAS RETURNS TO THE PERL EXPRESSION AND BEGINS SEARCHING FOR THE NEXT E-CODE IN THE TEXT VARIABLE */
end;
end;

if drug_dx ge 1 or drug_mentions GE 1 then drug_=1; /*Drug Poisoning*/
IF pharma ge 1 or pharma_dx ge 1 then pharma_=1; /*Pharmaceutical Poisoning*/
if nec_n ge 1 or nec ge 1 then nec_=1;		/*Antidepressants, barbiturates and other antiepileptics, sedative-hypnotics, and psychotropic drugs not elsewhere classified*/
if benzo_n ge 1 or benzo ge 1 then benzo_=1;	/*Benzo*/
if psycho_n ge 1 or psycho ge 1 then psycho_=1;	/*Psychostimulants with abuse potential*/

IF Rxopioid ge 1 or RXopioid_dx ge 1 then RXopioid_=1; /*Only Prescription Opioid*/
IF illopioid ge 1 or illopioid_dx ge 1 then illopioid_=1; /*Only Illicit Opioids*/
IF Rxopioid_ = 1 or illopioid_=1 then allopioid_=1; /*All Opioids*/

run;
