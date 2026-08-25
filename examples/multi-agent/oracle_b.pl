#!/usr/bin/env swipl
/*  oaa-next example -- one of two agents offering the same capability  */

:- use_module('../../src/agents/oaa_run').

solvables([solvable(oracle(_Q, _A), [callback(answer), utility(9)], [])]).

answer(oracle(Q, A), _Params) :- A = from_b(Q).

:- initialization(run, main).
run :- solvables(S), oaa_agent_run(oracle_b, S, []).
