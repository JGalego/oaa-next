#!/usr/bin/env swipl
/*  oaa-next example -- asks a question two agents can answer  */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').

:- initialization(run, main).

run :-
    oaa_agent_start(oracle_client, [], []),
    await_capability(oracle(q, _), 50),
    %  strategy(action) asks one provider at a time, so whoever the
    %  Facilitator puts first is the one that answers.
    (   oaa_solve(oracle(q, A), [strategy(action)])
    ->  format("answered by: ~w~n", [A])
    ;   format("no answer~n", [])
    ),
    halt(0).

await_capability(_, 0) :- !, throw(oaa_error(capability_never_appeared)).
await_capability(Goal, N) :-
    (   oaa_solve(can_solve(Goal, _), [address(parent), time_limit(1)])
    ->  true
    ;   sleep(0.1), N1 is N - 1, await_capability(Goal, N1)
    ).
