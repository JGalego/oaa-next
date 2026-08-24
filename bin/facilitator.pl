#!/usr/bin/env swipl
/*  oaa-next -- run the Facilitator
 *
 *  Usage:
 *      swipl bin/facilitator.pl -- -oaa_listen "tcp(localhost,3333)" \
 *                                  -write_setup_file setup.pl
 *
 *  With no -oaa_listen the operating system assigns a port, which is then
 *  recorded by -write_setup_file for client agents to find.
 */

:- use_module('../src/facilitator/fac').

:- initialization(run, main).

run :-
    fac_main.
