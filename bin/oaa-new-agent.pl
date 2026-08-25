#!/usr/bin/env swipl
/*  oaa-next -- new-agent  */

:- use_module('../src/adt/oaa_new_agent').

:- initialization(run, main).

run :- new_agent_main.
