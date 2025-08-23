/******************************************************************************
* Program: test_validate_data.sas
* Purpose: Unit tests for validate_data macro
* Author: CI/CD Pipeline
* Date: 2025
******************************************************************************/

%macro test_validate_data();
    %local status message test_start test_end;
    %let test_start = %sysfunc(datetime());
    %let status = PASS;
    %let message = ;
    
    /* Test 1: Valid demographics dataset */
    %put UNITTEST: Testing validate_data with valid demographics dataset;
    
    /* Create test demographics dataset */
    data work.test_dm;
        length usubjid $20 age 8 sex $1 race $20 country $3;
        input usubjid $ age sex $ race $ country $;
        datalines;
    STUDY001-001 45 M WHITE USA
    STUDY001-002 32 F BLACK USA
    STUDY001-003 67 M ASIAN JPN
    STUDY001-004 28 F WHITE CAN
    STUDY001-005 55 M OTHER BRA
    STUDY001-006 41 F WHITE USA
    STUDY001-007 38 M BLACK GBR
    STUDY001-008 52 F ASIAN CHN
    STUDY001-009 29 M WHITE USA
    STUDY001-010 61 F OTHER MEX
    ;
    run;
    
    /* Run validate_data macro */
    %validate_data(
        indata=work.test_dm,
        domain=DM,
        outdata=work.validate_dm_result
    );
    
    /* Check if validation report was created */
    %if not %sysfunc(exist(work.validate_dm_result)) %then %do;
        %let status = FAIL;
        %let message = validate_data did not create validation report;
        %goto exit_test;
    %end;
    
    /* Test 2: Dataset with missing required variables */
    %put UNITTEST: Testing validate_data with missing required variables;
    
    data work.test_dm_missing;
        set work.test_dm;
        if _n_ in (2, 5, 8) then usubjid = '';
        if _n_ in (3, 6) then age = .;
        if _n_ = 4 then sex = '';
    run;
    
    %validate_data(
        indata=work.test_dm_missing,
        domain=DM,
        outdata=work.validate_missing_result
    );
    
    /* Check that validation detected issues */
    %let issue_count = 0;
    %if %sysfunc(exist(work.validate_missing_result)) %then %do;
        data _null_;
            set work.validate_missing_result nobs=nobs;
            call symputx('issue_count', nobs);
            stop;
        run;
    %end;
    
    %if &issue_count = 0 %then %do;
        %put UNITTEST: WARNING - validate_data did not detect missing values;
    %end;
    
    /* Test 3: Invalid data types */
    %put UNITTEST: Testing validate_data with invalid data types;
    
    data work.test_dm_invalid;
        length usubjid $20 age $10 sex $1 race $20 country $3;
        input usubjid $ age $ sex $ race $ country $;
        datalines;
    STUDY001-001 FORTY-FIVE M WHITE USA
    STUDY001-002 32 F BLACK USA
    STUDY001-003 INVALID M ASIAN JPN
    ;
    run;
    
    %validate_data(
        indata=work.test_dm_invalid,
        domain=DM,
        outdata=work.validate_invalid_result
    );
    
    /* Test 4: Adverse Events domain validation */
    %put UNITTEST: Testing validate_data with AE domain;
    
    data work.test_ae;
        length usubjid $20 aeterm $100 aesev $20 aeser $1 aestdtc $10;
        input usubjid $ aeterm $ aesev $ aeser $ aestdtc $;
        datalines;
    STUDY001-001 HEADACHE MILD N 2024-01-15
    STUDY001-001 NAUSEA MODERATE Y 2024-01-20
    STUDY001-002 FATIGUE INVALID N 2024-02-01
    STUDY001-002 HEADACHE MILD X 2024-02-05
    STUDY001-003 DIZZINESS SEVERE Y INVALID-DATE
    ;
    run;
    
    %validate_data(
        indata=work.test_ae,
        domain=AE,
        outdata=work.validate_ae_result
    );
    
    /* Test 5: Laboratory domain validation */
    %put UNITTEST: Testing validate_data with LB domain;
    
    data work.test_lb;
        length usubjid $20 lbtestcd $8 lborres 8 lborresu $20 lbdtc $10;
        input usubjid $ lbtestcd $ lborres lborresu $ lbdtc $;
        datalines;
    STUDY001-001 HGB 14.5 g/dL 2024-01-15
    STUDY001-001 WBC 7.2 10^9/L 2024-01-15
    STUDY001-002 HGB -5 g/dL 2024-02-01
    STUDY001-002 WBC . 10^9/L 2024-02-01
    STUDY001-003 PLAT 250 10^9/L 2024-02-10
    ;
    run;
    
    %validate_data(
        indata=work.test_lb,
        domain=LB,
        outdata=work.validate_lb_result
    );
    
    /* Test 6: Custom validation rules */
    %put UNITTEST: Testing validate_data with custom rules;
    
    %validate_data(
        indata=work.test_dm,
        domain=DM,
        outdata=work.validate_custom_result,
        custom_rules=%str(
            if age < 18 or age > 100 then output;
            if sex not in ('M', 'F', 'U') then output;
            if country not in ('USA', 'CAN', 'JPN', 'GBR', 'CHN', 'BRA', 'MEX') then output;
        )
    );
    
    /* Test 7: Empty dataset handling */
    %put UNITTEST: Testing validate_data with empty dataset;
    
    data work.test_empty;
        length usubjid $20 age 8 sex $1;
        stop;
    run;
    
    %validate_data(
        indata=work.test_empty,
        domain=DM,
        outdata=work.validate_empty_result
    );
    
    /* Test 8: Performance test with larger dataset */
    %put UNITTEST: Testing validate_data performance;
    
    data work.test_large;
        length usubjid $20 age 8 sex $1 race $20 country $3;
        array races[4] $20 _temporary_ ('WHITE' 'BLACK' 'ASIAN' 'OTHER');
        array countries[7] $3 _temporary_ ('USA' 'CAN' 'JPN' 'GBR' 'CHN' 'BRA' 'MEX');
        
        do i = 1 to 10000;
            usubjid = cats('STUDY001-', put(i, z5.));
            age = 18 + int(ranuni(123) * 65);
            sex = ifc(ranuni(456) > 0.5, 'M', 'F');
            race = races[mod(i, 4) + 1];
            country = countries[mod(i, 7) + 1];
            
            /* Introduce some invalid data */
            if mod(i, 100) = 0 then usubjid = '';
            if mod(i, 150) = 0 then age = .;
            if mod(i, 200) = 0 then sex = 'X';
            
            output;
        end;
        drop i;
    run;
    
    %let perf_start = %sysfunc(datetime());
    
    %validate_data(
        indata=work.test_large,
        domain=DM,
        outdata=work.validate_large_result
    );
    
    %let perf_end = %sysfunc(datetime());
    %let perf_time = %sysevalf(&perf_end - &perf_start);
    
    %put UNITTEST: validate_data processed 10000 records in &perf_time seconds;
    
    %if %sysevalf(&perf_time > 30) %then %do;
        %put UNITTEST: WARNING - validate_data performance may be slow (>30 seconds);
    %end;
    
    /* Test 9: Cross-domain validation */
    %put UNITTEST: Testing validate_data cross-domain checks;
    
    /* Create related datasets for cross-validation */
    data work.test_dm_cross;
        length usubjid $20;
        input usubjid $;
        datalines;
    STUDY001-001
    STUDY001-002
    STUDY001-003
    ;
    run;
    
    data work.test_ae_cross;
        length usubjid $20 aeterm $100;
        input usubjid $ aeterm $;
        datalines;
    STUDY001-001 HEADACHE
    STUDY001-002 NAUSEA
    STUDY001-004 FATIGUE
    STUDY001-005 DIZZINESS
    ;
    run;
    
    %validate_data(
        indata=work.test_ae_cross,
        domain=AE,
        outdata=work.validate_cross_result,
        ref_data=work.test_dm_cross
    );
    
    %exit_test:
    
    /* Clean up test datasets */
    proc datasets library=work nolist;
        delete test_dm test_dm_missing test_dm_invalid test_dm_cross
               test_ae test_ae_cross test_lb test_empty test_large
               validate_:;
    quit;
    
    %let test_end = %sysfunc(datetime());
    %let test_duration = %sysevalf(&test_end - &test_start);
    
    /* Output test result */
    %put UNITTEST: validate_data test &status;
    %if &status = FAIL %then %put UNITTEST: FAIL - &message;
    %put UNITTEST: Test duration: &test_duration seconds;
    
    /* Set global test variables */
    %global test_validate_data_status test_validate_data_message;
    %let test_validate_data_status = &status;
    %let test_validate_data_message = &message;
    
%mend test_validate_data;

/* Execute the test */
%test_validate_data();