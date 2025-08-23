/******************************************************************************
* Program: TEST_RUNNER.SAS
* Purpose: Automated test runner for SAS macros
* Author: Clinical Programming Team
* Date: 2025-01-23
******************************************************************************/

/* Set up test environment */
%let test_root = %sysget(CI_PROJECT_DIR);
%if &test_root= %then %let test_root = .;

/* Include macro library */
%include "&test_root/macros/*.sas";

/* Test results dataset */
data test_results;
    length test_name $50 test_desc $200 status $10 message $500 runtime 8;
    delete;
run;

/* Macro to run individual test */
%macro run_test(test_name=, test_desc=);
    %local start_time end_time runtime status message;
    
    %let start_time = %sysfunc(datetime());
    %let status = PASS;
    %let message = Test completed successfully;
    
    %put NOTE: Running test: &test_name;
    
    /* Execute test */
    %include "&test_root/tests/&test_name..sas" / nosource;
    
    %let end_time = %sysfunc(datetime());
    %let runtime = %sysevalf(&end_time - &start_time);
    
    /* Record result */
    data _temp_result;
        length test_name $50 test_desc $200 status $10 message $500 runtime 8;
        test_name = "&test_name";
        test_desc = "&test_desc";
        status = "&status";
        message = "&message";
        runtime = &runtime;
        test_datetime = datetime();
        format test_datetime datetime20.;
    run;
    
    proc append base=test_results data=_temp_result;
    run;
    
%mend run_test;

/* Main test execution */
%macro run_all_tests;
    
    %put NOTE: ========================================;
    %put NOTE: Starting SAS Macro Test Suite;
    %put NOTE: ========================================;
    
    /* Run individual tests */
    %run_test(test_name=test_demog_summary, test_desc=Test demographic summary macro);
    %run_test(test_name=test_ae_summary, test_desc=Test adverse event summary macro);
    %run_test(test_name=test_validate_data, test_desc=Test data validation macro);
    
    /* Generate test report */
    proc sql;
        select count(*) into :total_tests from test_results;
        select count(*) into :passed_tests from test_results where status='PASS';
        select count(*) into :failed_tests from test_results where status='FAIL';
    quit;
    
    %put NOTE: ========================================;
    %put NOTE: Test Results Summary;
    %put NOTE: Total Tests: &total_tests;
    %put NOTE: Passed: &passed_tests;
    %put NOTE: Failed: &failed_tests;
    %put NOTE: ========================================;
    
    /* Create detailed report */
    ods html file="&test_root/logs/test_report.html" style=statistical;
    
    title "SAS Macro Test Report";
    title2 "Generated: %sysfunc(datetime(), datetime20.)";
    
    proc print data=test_results noobs;
        var test_name test_desc status runtime message;
    run;
    
    ods html close;
    
    /* Export results for CI/CD */
    proc export data=test_results
        outfile="&test_root/logs/test_results.csv"
        dbms=csv replace;
    run;
    
    /* Set exit code for CI/CD */
    %if &failed_tests > 0 %then %do;
        %put ERROR: Tests failed. Exiting with error code 1;
        data _null_;
            abort abend 1;
        run;
    %end;
    
%mend run_all_tests;

/* Execute tests */
%run_all_tests;