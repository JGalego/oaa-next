#!/usr/bin/env swipl
/*  oaa-next -- debug  */

:- use_module('../src/adt/oaa_debug').

:- initialization(run, main).

run :- debug_main.
