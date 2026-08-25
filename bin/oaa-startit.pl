#!/usr/bin/env swipl
/*  oaa-next -- startit  */

:- use_module('../src/adt/oaa_startit').

:- initialization(run, main).

run :- startit_main.
