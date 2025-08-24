/***********************************
* Test for calculate_mean macro
* Expected Result: Mean = 30
***********************************/

/* Create test data */
data work.test_data;
    input value;
    datalines;
10
20
30
40
50
;
run;

/* Load the macro */
%include "calculate_mean.sas";

/* Run the macro */
%calculate_mean(data=work.test_data, var=value, output=work.result);

/* Verify the result */
data _null_;
    set work.result;
    if mean_value = 30 then do;
        put "SUCCESS: TEST PASSED - Mean is correct (30)";
        call symputx('test_status', 'PASS');
    end;
    else do;
        put "ERROR: TEST FAILED - Mean is incorrect";
        put "ERROR: Expected: 30, Got: " mean_value;
        call symputx('test_status', 'FAIL');
    end;
run;

%put Test Status: &test_status;

/* Clean up */
proc datasets lib=work nolist;
    delete test_data result;
quit;