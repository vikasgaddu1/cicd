/******************************************************************************
---
name: demog_summary
description: Create demographic summary statistics for clinical trials
category: summary_statistics
tags: [demographics, clinical, statistics, CDISC]
version: 1.0.0
author: Clinical Programming Team
date: 2025-01-23
parameters:
  - name: indata
    type: dataset
    required: true
    description: Input dataset containing demographic data
    example: work.adsl
  - name: outdata
    type: dataset
    required: true
    description: Output dataset for summary statistics
    example: work.demog_stats
  - name: trtvar
    type: variable
    required: false
    default: trt
    description: Treatment variable name for grouping
    example: trtgrp
  - name: vars
    type: variable_list
    required: true
    description: Space-separated list of variables to summarize
    example: age height weight bmi
  - name: stattype
    type: option
    required: false
    default: BOTH
    values: [CONT, CAT, BOTH]
    description: Type of statistics to generate (continuous, categorical, or both)
    example: CONT
returns:
  - type: dataset
    description: Summary statistics dataset with treatment groups
examples:
  - code: |
      %demog_summary(
        indata=adsl,
        outdata=demog_stats,
        trtvar=trt01p,
        vars=age height weight,
        stattype=CONT
      );
    description: Generate continuous variable summaries by treatment group
---
******************************************************************************/

%macro demog_summary(
    indata=,        /* Input dataset */
    outdata=,       /* Output dataset */
    trtvar=trt,     /* Treatment variable */
    vars=,          /* Variables to summarize */
    stattype=BOTH   /* CONT, CAT, or BOTH */
);

    %if &indata= %then %do;
        %put ERROR: Input dataset required;
        %return;
    %end;

    %if &outdata= %then %do;
        %put ERROR: Output dataset required;
        %return;
    %end;

    %put NOTE: Starting demographic summary for &indata;
    
    /* Check if dataset exists */
    %if not %sysfunc(exist(&indata)) %then %do;
        %put ERROR: Dataset &indata does not exist;
        %return;
    %end;

    /* Get total N by treatment */
    proc sql noprint;
        create table _trt_n as
        select &trtvar, count(*) as _n
        from &indata
        group by &trtvar;
    quit;

    /* Process continuous variables */
    %if &stattype=CONT or &stattype=BOTH %then %do;
        proc means data=&indata n mean std min max median q1 q3;
            class &trtvar;
            var &vars;
            output out=_cont_stats;
        run;
    %end;

    /* Process categorical variables */
    %if &stattype=CAT or &stattype=BOTH %then %do;
        proc freq data=&indata;
            tables &trtvar*(&vars) / nocol nopercent;
            output out=_cat_stats;
        run;
    %end;

    /* Combine results */
    data &outdata;
        set %if &stattype=CONT or &stattype=BOTH %then _cont_stats;
            %if &stattype=CAT or &stattype=BOTH %then _cat_stats;
        ;
    run;

    /* Clean up temporary datasets */
    proc datasets lib=work nolist;
        delete _trt_n _cont_stats _cat_stats;
    quit;

    %put NOTE: Demographic summary completed. Output saved to &outdata;

%mend demog_summary;