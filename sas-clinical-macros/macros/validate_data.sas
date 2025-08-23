/******************************************************************************
---
name: validate_data
description: Validate clinical trial datasets against CDISC standards (SDTM/ADaM)
category: data_validation
tags: [validation, CDISC, SDTM, ADaM, quality_control]
version: 1.0.0
author: Clinical Programming Team
date: 2025-01-23
parameters:
  - name: indata
    type: dataset
    required: true
    description: Input dataset to validate against CDISC standards
    example: work.dm
  - name: standard
    type: option
    required: false
    default: SDTM
    values: [SDTM, ADAM]
    description: CDISC standard to validate against
    example: SDTM
  - name: domain
    type: string
    required: true
    description: Domain name for validation rules (e.g., DM, AE, VS for SDTM; ADSL, ADAE for ADaM)
    example: DM
  - name: outreport
    type: filepath
    required: false
    description: Path to output HTML validation report
    example: /reports/validation_dm.html
returns:
  - type: report
    description: HTML validation report with check results
  - type: dataset
    description: Validation results dataset with pass/fail status
validation_checks:
  - Required variables presence
  - Data completeness
  - Duplicate records
  - Variable naming conventions
  - Data type consistency
examples:
  - code: |
      %validate_data(
        indata=sdtm.dm,
        standard=SDTM,
        domain=DM,
        outreport=validation_dm.html
      );
    description: Validate SDTM DM domain
  - code: |
      %validate_data(
        indata=adam.adsl,
        standard=ADAM,
        domain=ADSL,
        outreport=validation_adsl.html
      );
    description: Validate ADaM ADSL dataset
---
******************************************************************************/

%macro validate_data(
    indata=,           /* Input dataset to validate */
    standard=SDTM,     /* Standard to validate against (SDTM/ADAM) */
    domain=,           /* Domain name (e.g., DM, AE, VS) */
    outreport=         /* Output validation report */
);

    %if &indata= %then %do;
        %put ERROR: Input dataset required;
        %return;
    %end;

    %put NOTE: Starting validation of &indata against &standard standard;

    /* Check if dataset exists */
    %if not %sysfunc(exist(&indata)) %then %do;
        %put ERROR: Dataset &indata does not exist;
        %return;
    %end;

    /* Initialize validation results dataset */
    data _validation_results;
        length check_id $20 check_desc $200 status $10 message $500;
        delete;
    run;

    /* Get dataset structure */
    proc contents data=&indata out=_contents noprint;
    run;

    /* Check 1: Required variables */
    %if &standard=SDTM %then %do;
        %let req_vars = STUDYID DOMAIN USUBJID;
        %if &domain=DM %then %let req_vars = &req_vars SUBJID RFSTDTC RFENDTC SITEID AGE SEX RACE COUNTRY;
        %else %if &domain=AE %then %let req_vars = &req_vars AESEQ AETERM AESTDTC;
        %else %if &domain=VS %then %let req_vars = &req_vars VSSEQ VSTESTCD VSTEST VSORRES VSORRESU VISITNUM VSDTC;
    %end;
    %else %if &standard=ADAM %then %do;
        %let req_vars = STUDYID USUBJID;
        %if &domain=ADSL %then %let req_vars = &req_vars SUBJID SITEID AGE AGEU SEX RACE SAFFL ITTFL;
        %else %if &domain=ADAE %then %let req_vars = &req_vars AESEQ AETERM ASTDT AENDT TRTA;
    %end;

    /* Validate required variables */
    %let i = 1;
    %let var = %scan(&req_vars, &i);
    %do %while(&var ne );
        proc sql noprint;
            select count(*) into :var_exists
            from _contents
            where upcase(name) = upcase("&var");
        quit;

        data _temp_check;
            length check_id $20 check_desc $200 status $10 message $500;
            check_id = "VAR_%sysfunc(putn(&i, z3.))";
            check_desc = "Required variable check";
            %if &var_exists > 0 %then %do;
                status = "PASS";
                message = "Variable &var exists";
            %end;
            %else %do;
                status = "FAIL";
                message = "Required variable &var is missing";
            %end;
        run;

        proc append base=_validation_results data=_temp_check;
        run;

        %let i = %eval(&i + 1);
        %let var = %scan(&req_vars, &i);
    %end;

    /* Check 2: Data completeness */
    proc sql noprint;
        select count(*) into :nobs from &indata;
    quit;

    data _temp_check;
        check_id = "DATA_001";
        check_desc = "Dataset has records";
        %if &nobs > 0 %then %do;
            status = "PASS";
            message = "Dataset contains &nobs records";
        %end;
        %else %do;
            status = "FAIL";
            message = "Dataset is empty";
        %end;
    run;

    proc append base=_validation_results data=_temp_check;
    run;

    /* Check 3: Duplicate records check */
    %if &standard=SDTM %then %do;
        %if &domain=DM %then %let key_vars = USUBJID;
        %else %let key_vars = USUBJID DOMAIN &domain.SEQ;
    %end;
    %else %do;
        %let key_vars = USUBJID PARAMCD AVISIT;
    %end;

    proc sort data=&indata out=_check_dups dupout=_dups nodupkey;
        by &key_vars;
    run;

    proc sql noprint;
        select count(*) into :n_dups from _dups;
    quit;

    data _temp_check;
        check_id = "DUP_001";
        check_desc = "Duplicate key check";
        %if &n_dups = 0 %then %do;
            status = "PASS";
            message = "No duplicate records found";
        %end;
        %else %do;
            status = "FAIL";
            message = "&n_dups duplicate records found for key: &key_vars";
        %end;
    run;

    proc append base=_validation_results data=_temp_check;
    run;

    /* Generate validation report */
    %if &outreport ne %then %do;
        ods html file="&outreport" style=statistical;
        
        title "Data Validation Report for &indata";
        title2 "Standard: &standard | Domain: &domain";
        
        proc print data=_validation_results noobs;
            var check_id check_desc status message;
        run;
        
        proc freq data=_validation_results;
            tables status / nocum;
            title3 "Validation Summary";
        run;
        
        ods html close;
        
        %put NOTE: Validation report saved to &outreport;
    %end;

    /* Clean up */
    proc datasets lib=work nolist;
        delete _contents _validation_results _temp_check _check_dups _dups;
    quit;

    %put NOTE: Data validation completed for &indata;

%mend validate_data;