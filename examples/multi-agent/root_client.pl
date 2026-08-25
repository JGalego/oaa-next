#!/usr/bin/env swipl
/*  oaa-next example -- reaching down into a subordinate community
 *
 *  This client is attached to the root facilitator and asks for a capability
 *  that only an agent under the node facilitator provides.  No propagate
 *  parameter is needed: the node registered upward with everything its own
 *  clients can solve, so the root simply selects it as the provider.
 */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').

:- initialization(run, main).

run :-
    oaa_agent_start(root_client, [], []),
    (   oaa_solve(square(6, X), [time_limit(10)])
    ->  format("root asking downward: square(6) = ~w~n", [X])
    ;   format("root asking downward: no solution~n", [])
    ),
    halt(0).
