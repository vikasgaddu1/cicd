/***********************************
* Macro: calculate_mean
* Purpose: Calculate mean of a variable
* Author: Vikas Gaddu
* Date: 2025
***********************************/

%macro calculate_mean(data=, var=, output=);
    /* Check if dataset exists */
    %if not %sysfunc(exist(&data)) %then %do;
        %put ERROR: Dataset &data does not exist;
        %return;
    %end;
    
    /* Calculate mean */
    proc means data=&data mean noprint;
        var &var;
        output out=&output mean=mean_value;
    run;
    
    /* Display result */
    data _null_;
        set &output;
        put "NOTE: Mean of &var = " mean_value;
    run;
    
    %put NOTE: Mean calculated successfully for &var in &data;
%mend calculate_mean;