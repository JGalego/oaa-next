#!/usr/bin/env swipl
/*  oaa-next example -- talking to a provider directly
 *
 *  direct_connect asks the Facilitator who can answer, then goes straight to
 *  that agent, so the message traffic bypasses the Facilitator while the
 *  choice of provider remains the Facilitator's.
 *
 *  Only a single provider with a listener qualifies; anything else falls back
 *  to the ordinary path, which is why the same call works either way.
 */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').

:- initialization(run, main).

run :-
    oaa_agent_start(direct_client, [], []),
    await_capability(echo(x, _), 60),
    (   oaa_solve(echo(hello, R), [direct_connect(true), provider_limit(1)])
    ->  format("direct: ~w~n", [R])
    ;   format("direct: no solution~n", [])
    ),
    (   oaa_solve(echo(again, R2), [])
    ->  format("relayed: ~w~n", [R2])
    ;   format("relayed: no solution~n", [])
    ),
    halt(0).

await_capability(_, 0) :- !, throw(oaa_error(capability_never_appeared)).
await_capability(Goal, N) :-
    (   oaa_solve(can_solve(Goal, _), [address(parent), time_limit(1)])
    ->  true
    ;   sleep(0.1), N1 is N - 1, await_capability(Goal, N1)
    ).
