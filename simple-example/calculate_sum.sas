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
        put "NOTE: Sum of &var = " sum_value;
    run;
    
    %put NOTE: Sum calculated successfully for &var in &data;
%mend calculate_sum;