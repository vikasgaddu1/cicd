/******************************************************************************
* Program: smoke_test.sas
* Purpose: Quick smoke test to verify deployment and basic functionality
* Author: CI/CD Pipeline
* Date: 2025
******************************************************************************/

%put NOTE: Starting smoke tests for SAS Clinical Macros;
%put NOTE: ============================================;

/* Set up macro path */
options mautosource sasautos=("&test_root/macros" %sysfunc(getoption(sasautos)));

/* Test 1: Verify macros are accessible */
%put NOTE: Test 1 - Verifying macro accessibility;

%macro check_macro_exists(macro_name);
    %if %sysmacexist(&macro_name) %then %do;
        %put NOTE: ✓ Macro &macro_name is available;
    %end;
    %else %do;
        %put ERROR: ✗ Macro &macro_name is NOT available;
        %abort;
    %end;
%mend;

%check_macro_exists(demog_summary);
%check_macro_exists(ae_summary);
%check_macro_exists(validate_data);

/* Test 2: Basic execution test */
%put NOTE: Test 2 - Testing basic macro execution;

/* Create minimal test data */
data work.smoke_test_dm;
    length usubjid $20 age 8 sex $1;
    usubjid = "TEST-001"; age = 35; sex = "M"; output;
    usubjid = "TEST-002"; age = 42; sex = "F"; output;
run;

/* Try to run demog_summary */
%demog_summary(
    indata=work.smoke_test_dm,
    outdata=work.smoke_test_result
);

/* Verify output was created */
%if %sysfunc(exist(work.smoke_test_result)) %then %do;
    %put NOTE: ✓ demog_summary executed successfully;
%end;
%else %do;
    %put ERROR: ✗ demog_summary failed to create output;
    %abort;
%end;

/* Test 3: Check SAS environment */
%put NOTE: Test 3 - Checking SAS environment;
%put NOTE: SAS Version: &sysvlong;
%put NOTE: Operating System: &sysscp &sysscpl;
%put NOTE: Date/Time: &sysdate &systime;

/* Test 4: Verify CAS connection (if applicable) */
%if %symexist(cas_session_name) %then %do;
    %put NOTE: Test 4 - Checking CAS connection;
    proc cas;
        session name=&cas_session_name;
        serverinfo result=si / all=true;
        
        if si.About.Version ne "" then do;
            put "NOTE: ✓ CAS connection successful";
            put "NOTE: CAS Version: " si.About.Version;
        end;
        else do;
            put "ERROR: ✗ CAS connection failed";
        end;
    quit;
%end;

/* Clean up */
proc datasets library=work nolist;
    delete smoke_test_:;
quit;

%put NOTE: ============================================;
%put NOTE: Smoke tests completed successfully;
%put NOTE: All critical components are operational;