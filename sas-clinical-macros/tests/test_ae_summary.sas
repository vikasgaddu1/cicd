/******************************************************************************
* Program: test_ae_summary.sas
* Purpose: Unit tests for ae_summary macro
* Author: CI/CD Pipeline
* Date: 2025
******************************************************************************/

%macro test_ae_summary();
    %local status message test_start test_end;
    %let test_start = %sysfunc(datetime());
    %let status = PASS;
    %let message = ;
    
    /* Test 1: Basic functionality with valid AE data */
    %put UNITTEST: Testing ae_summary with valid dataset;
    
    /* Create test AE dataset */
    data work.test_ae;
        length usubjid $20 aeterm $100 aesev $20 aeser $1 aestdtc $10;
        input usubjid $ aeterm $ aesev $ aeser $ aestdtc $;
        datalines;
    STUDY001-001 HEADACHE MILD N 2024-01-15
    STUDY001-001 NAUSEA MODERATE Y 2024-01-20
    STUDY001-002 FATIGUE MILD N 2024-02-01
    STUDY001-002 HEADACHE MILD N 2024-02-05
    STUDY001-003 DIZZINESS SEVERE Y 2024-02-10
    STUDY001-003 NAUSEA MILD N 2024-02-15
    STUDY001-004 HEADACHE MODERATE N 2024-03-01
    STUDY001-004 FATIGUE MILD N 2024-03-05
    STUDY001-005 NAUSEA SEVERE Y 2024-03-10
    ;
    run;
    
    /* Run the ae_summary macro */
    %ae_summary(
        indata=work.test_ae,
        outdata=work.ae_summary_result,
        by_var=aesev
    );
    
    /* Check if output dataset was created */
    %if not %sysfunc(exist(work.ae_summary_result)) %then %do;
        %let status = FAIL;
        %let message = ae_summary did not create output dataset;
        %goto exit_test;
    %end;
    
    /* Check output structure */
    proc contents data=work.ae_summary_result noprint out=work._contents;
    run;
    
    %let nvars = 0;
    data _null_;
        set work._contents nobs=nobs;
        call symputx('nvars', nobs);
    run;
    
    %if &nvars = 0 %then %do;
        %let status = FAIL;
        %let message = ae_summary output dataset has no variables;
        %goto exit_test;
    %end;
    
    /* Test 2: Handle missing values */
    %put UNITTEST: Testing ae_summary with missing values;
    
    data work.test_ae_missing;
        set work.test_ae;
        if _n_ in (2, 5, 7) then aeterm = '';
        if _n_ in (3, 6) then aesev = '';
    run;
    
    %ae_summary(
        indata=work.test_ae_missing,
        outdata=work.ae_summary_missing,
        by_var=aesev
    );
    
    %if not %sysfunc(exist(work.ae_summary_missing)) %then %do;
        %let status = FAIL;
        %let message = ae_summary failed with missing values;
        %goto exit_test;
    %end;
    
    /* Test 3: Empty dataset handling */
    %put UNITTEST: Testing ae_summary with empty dataset;
    
    data work.test_ae_empty;
        length usubjid $20 aeterm $100 aesev $20 aeser $1 aestdtc $10;
        stop;
    run;
    
    %ae_summary(
        indata=work.test_ae_empty,
        outdata=work.ae_summary_empty,
        by_var=aesev
    );
    
    /* Test 4: Different by_var options */
    %put UNITTEST: Testing ae_summary with different grouping variables;
    
    %ae_summary(
        indata=work.test_ae,
        outdata=work.ae_summary_byterm,
        by_var=aeterm
    );
    
    %if not %sysfunc(exist(work.ae_summary_byterm)) %then %do;
        %let status = FAIL;
        %let message = ae_summary failed with by_var=aeterm;
        %goto exit_test;
    %end;
    
    %ae_summary(
        indata=work.test_ae,
        outdata=work.ae_summary_byser,
        by_var=aeser
    );
    
    %if not %sysfunc(exist(work.ae_summary_byser)) %then %do;
        %let status = FAIL;
        %let message = ae_summary failed with by_var=aeser;
        %goto exit_test;
    %end;
    
    /* Test 5: Performance test with larger dataset */
    %put UNITTEST: Testing ae_summary performance with larger dataset;
    
    data work.test_ae_large;
        length usubjid $20 aeterm $100 aesev $20 aeser $1 aestdtc $10;
        array terms[5] $100 _temporary_ ('HEADACHE' 'NAUSEA' 'FATIGUE' 'DIZZINESS' 'FEVER');
        array sevs[3] $20 _temporary_ ('MILD' 'MODERATE' 'SEVERE');
        array sers[2] $1 _temporary_ ('Y' 'N');
        
        do i = 1 to 1000;
            usubjid = cats('STUDY001-', put(i, z3.));
            do j = 1 to 3;
                aeterm = terms[mod(i*j, 5) + 1];
                aesev = sevs[mod(i+j, 3) + 1];
                aeser = sers[mod(i*j, 2) + 1];
                aestdtc = put(intnx('day', '01JAN2024'd, mod(i*j, 365)), yymmdd10.);
                output;
            end;
        end;
        drop i j;
    run;
    
    %let perf_start = %sysfunc(datetime());
    
    %ae_summary(
        indata=work.test_ae_large,
        outdata=work.ae_summary_large,
        by_var=aesev
    );
    
    %let perf_end = %sysfunc(datetime());
    %let perf_time = %sysevalf(&perf_end - &perf_start);
    
    %put UNITTEST: ae_summary processed 3000 records in &perf_time seconds;
    
    %if %sysevalf(&perf_time > 10) %then %do;
        %put UNITTEST: WARNING - ae_summary performance may be slow (>10 seconds);
    %end;
    
    %exit_test:
    
    /* Clean up test datasets */
    proc datasets library=work nolist;
        delete test_ae test_ae_missing test_ae_empty test_ae_large 
               ae_summary_: _contents;
    quit;
    
    %let test_end = %sysfunc(datetime());
    %let test_duration = %sysevalf(&test_end - &test_start);
    
    /* Output test result */
    %put UNITTEST: ae_summary test &status;
    %if &status = FAIL %then %put UNITTEST: FAIL - &message;
    %put UNITTEST: Test duration: &test_duration seconds;
    
    /* Set global test variables */
    %global test_ae_summary_status test_ae_summary_message;
    %let test_ae_summary_status = &status;
    %let test_ae_summary_message = &message;
    
%mend test_ae_summary;

/* Execute the test */
%test_ae_summary();