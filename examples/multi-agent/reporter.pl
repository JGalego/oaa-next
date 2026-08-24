#!/usr/bin/env swipl
/*  oaa-next example -- a blackboard reader
 *
 *  Reads a data solvable it never declared, written by an agent it has never
 *  heard of, through a facilitator neither of them named to the other.
 *
 *  Querying a data solvable looks exactly like calling a procedure solvable:
 *  both go through oaa_solve.  That equivalence is deliberate in OAA.
 */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').

:- initialization(run, main).

run :-
    oaa_agent_start(reporter, [], []),
    await_data(observation(_, _), 50),
    findall(S-V, oaa_solve(observation(S, V), []), Observations),
    length(Observations, N),
    format("observations: ~w~n", [N]),
    forall(member(S-V, Observations), format("  ~w = ~w~n", [S, V])),
    halt(0).

await_data(_, 0) :- !, throw(oaa_error(blackboard_never_appeared)).
await_data(Goal, N) :-
    (   oaa_solve(Goal, [time_limit(1)])
    ->  true
    ;   sleep(0.1), N1 is N - 1, await_data(Goal, N1)
    ).
