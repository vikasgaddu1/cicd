/***********************************
* Test for calculate_sum macro
* Expected Result: Sum = 60
***********************************/

/* Create test data */
data work.test_data;
    input value;
    datalines;
10
20
30
;
run;

/* Load the macro */
%include "calculate_sum.sas";

/* Run the macro */
%calculate_sum(data=work.test_data, var=value, output=work.result);

/* Verify the result */
data _null_;
    set work.result;
    if sum_value = 60 then do;
        put "SUCCESS: TEST PASSED - Sum is correct (60)";
        call symputx('test_status', 'PASS');
    end;
    else do;
        put "ERROR: TEST FAILED - Sum is incorrect";
        put "ERROR: Expected: 60, Got: " sum_value;
        call symputx('test_status', 'FAIL');
    end;
run;

%put Test Status: &test_status;

/* Test 2: Empty dataset handling */
data work.empty_data;
    input value;
    datalines;
;
run;

%calculate_sum(data=work.empty_data, var=value, output=work.result2);

/* Test 3: Negative values */
data work.negative_data;
    input value;
    datalines;
-10
20
-5
;
run;

%calculate_sum(data=work.negative_data, var=value, output=work.result3);

/* Clean up */
proc datasets lib=work nolist;
    delete test_data empty_data negative_data result result2 result3;
quit;