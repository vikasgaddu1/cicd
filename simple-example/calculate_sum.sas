/***********************************
* Macro: calculate_sum
* Purpose: Calculate sum of a variable
* Author: Vikas Gaddu
* Date: 2025
* TODO(human): Add validation for negative values if needed
***********************************/

%macro calculate_sum(data=, var=, output=);
    /* Check if dataset exists */
    %if not %sysfunc(exist(&data)) %then %do;
        %put ERROR: Dataset &data does not exist;
        %return;
    %end;
    
    /* Calculate sum */
    proc means data=&data sum noprint;
        var &var;
        output out=&output sum=sum_value;
    run;
    
    /* Display result */
    data _null_;
        set &output;
        if sum_value < 0 then do;
            put "ERROR: Sum of &var is negative";
            call symputx('test_status', 'FAIL');
        end;
        else do;
            put "NOTE: Sum of &var = " sum_value;
        end;
    run;
    
    %put NOTE: Sum calculated successfully for &var in &data;
    %put NOTE: Test Status: &test_status;
%mend calculate_sum;