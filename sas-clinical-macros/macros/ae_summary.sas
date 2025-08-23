/******************************************************************************
---
name: ae_summary
description: Summarize adverse events for safety analysis in clinical trials
category: safety_analysis
tags: [adverse_events, safety, clinical, CDISC, ADAE]
version: 1.0.0
author: Clinical Programming Team
date: 2025-01-23
parameters:
  - name: indata
    type: dataset
    required: true
    description: Input adverse event dataset (ADAE format)
    example: work.adae
  - name: outdata
    type: dataset
    required: true
    description: Output dataset containing AE summary statistics
    example: work.ae_stats
  - name: trtvar
    type: variable
    required: false
    default: trt
    description: Treatment variable for grouping AE summaries
    example: trta
  - name: subjid
    type: variable
    required: false
    default: usubjid
    description: Unique subject identifier variable
    example: subjid
  - name: aeterm
    type: variable
    required: false
    default: aedecod
    description: Adverse event term variable (preferred term)
    example: aept
  - name: aesev
    type: variable
    required: false
    default: aesev
    description: Adverse event severity/grade variable
    example: aeser
  - name: aerel
    type: variable
    required: false
    default: aerel
    description: Adverse event relationship to treatment variable
    example: aerelnst
returns:
  - type: dataset
    description: AE summary with counts and percentages by treatment group
examples:
  - code: |
      %ae_summary(
        indata=adae,
        outdata=ae_summary,
        trtvar=trta,
        aeterm=aedecod,
        aesev=aetoxgr
      );
    description: Generate AE summary with toxicity grades
---
******************************************************************************/

%macro ae_summary(
    indata=,          /* Input AE dataset */
    outdata=,         /* Output summary dataset */
    trtvar=trt,       /* Treatment variable */
    subjid=usubjid,   /* Subject ID variable */
    aeterm=aedecod,   /* AE term variable */
    aesev=aesev,      /* AE severity variable */
    aerel=aerel       /* AE relationship variable */
);

    %if &indata= %then %do;
        %put ERROR: Input dataset required;
        %return;
    %end;

    %if &outdata= %then %do;
        %put ERROR: Output dataset required;
        %return;
    %end;

    %put NOTE: Starting AE summary for &indata;

    /* Get subject counts by treatment */
    proc sql noprint;
        create table _subj_counts as
        select &trtvar, 
               count(distinct &subjid) as n_subjects
        from &indata
        group by &trtvar;
    quit;

    /* Overall AE summary */
    proc sql;
        create table _ae_overall as
        select &trtvar,
               &aeterm,
               count(distinct &subjid) as n_subjects_ae,
               count(*) as n_events
        from &indata
        group by &trtvar, &aeterm
        order by &trtvar, n_events desc;
    quit;

    /* AE by severity */
    %if %sysfunc(varnum(%sysfunc(open(&indata)), &aesev)) > 0 %then %do;
        proc sql;
            create table _ae_severity as
            select &trtvar,
                   &aeterm,
                   &aesev,
                   count(distinct &subjid) as n_subjects,
                   count(*) as n_events
            from &indata
            group by &trtvar, &aeterm, &aesev;
        quit;
    %end;

    /* AE by relationship */
    %if %sysfunc(varnum(%sysfunc(open(&indata)), &aerel)) > 0 %then %do;
        proc sql;
            create table _ae_related as
            select &trtvar,
                   &aeterm,
                   &aerel,
                   count(distinct &subjid) as n_subjects,
                   count(*) as n_events
            from &indata
            where upcase(&aerel) in ('RELATED', 'POSSIBLY RELATED', 'PROBABLY RELATED')
            group by &trtvar, &aeterm, &aerel;
        quit;
    %end;

    /* Combine all summaries */
    data &outdata;
        merge _subj_counts 
              _ae_overall
              %if %sysfunc(exist(_ae_severity)) %then _ae_severity;
              %if %sysfunc(exist(_ae_related)) %then _ae_related;
        ;
        by &trtvar;
        
        /* Calculate percentages */
        pct_subjects = (n_subjects_ae / n_subjects) * 100;
        format pct_subjects 5.1;
    run;

    /* Clean up */
    proc datasets lib=work nolist;
        delete _subj_counts _ae_overall _ae_severity _ae_related;
    quit;

    %put NOTE: AE summary completed. Output saved to &outdata;

%mend ae_summary;