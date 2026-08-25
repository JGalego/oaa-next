#!/usr/bin/env swipl
/*  oaa-next -- monitor  */

:- use_module('../src/adt/oaa_monitor').

:- initialization(run, main).

run :- monitor_main.
