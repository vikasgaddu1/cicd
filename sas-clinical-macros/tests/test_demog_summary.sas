/******************************************************************************
* Test: test_demog_summary
* Purpose: Unit tests for demographic summary macro
******************************************************************************/

/* Create test data */
data test_demog;
    input usubjid $ trt $ age sex $ race $;
    datalines;
001 A 45 M WHITE
002 A 52 F BLACK
003 B 38 M ASIAN
004 B 41 F WHITE
005 A 55 M WHITE
006 B 49 F BLACK
;
run;

/* Test 1: Basic functionality */
%demog_summary(
    indata=test_demog,
    outdata=test_demog_out,
    trtvar=trt,
    vars=age,
    stattype=CONT
);

/* Validate output exists */
%if not %sysfunc(exist(test_demog_out)) %then %do;
    %let status = FAIL;
    %let message = Output dataset not created;
    %return;
%end;

/* Test 2: Error handling - missing input */
%demog_summary(
    indata=,
    outdata=test_out2
);

/* Clean up */
proc datasets lib=work nolist;
    delete test_demog test_demog_out;
quit;