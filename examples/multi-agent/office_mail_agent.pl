#!/usr/bin/env swipl
/*  oaa-next example -- the Office Assistant demo: the Electronic Mail Agent
 *
 *  Provenance: NEW / ILLUSTRATIVE, reconstructing the pattern documented in
 *  research/office-demo.md rather than any recovered source.  A writable
 *  data solvable standing in for an inbox: each incoming message is one
 *  clause, mail(From, about(Topic), Body), and "arrival" is nothing more
 *  than another agent calling oaa_AddData on it -- there is no separate
 *  mail-arrival event to invent.
 */

:- use_module('../../src/agents/oaa_run').

solvables([solvable(mail(_From, about(_Topic), _Body),
                    [type(data)], [write(true)])]).

:- initialization(run, main).
run :- solvables(S), oaa_agent_run(office_mail_agent, S, []).
