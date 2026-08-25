#!/usr/bin/env swipl
/*  oaa-next -- shell  */

:- use_module('../src/adt/oaa_shell').

:- initialization(run, main).

run :- shell_main.
