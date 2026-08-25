#!/usr/bin/env swipl
/*  oaa-next example -- an agent providing a writable data solvable
 *
 *  Corresponds to the setup SRI's own conformance test for data solvables
 *  assumes (src/oaatest/samples/test2/system/fac/data.otml).
 */

:- use_module('../../src/agents/oaa_run').

solvables([solvable(foo(_X), [type(data)], [write(true)])]).

:- initialization(run, main).
run :- solvables(S), oaa_agent_run(data_agent, S, []).
