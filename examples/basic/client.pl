#!/usr/bin/env swipl
/*  oaa-next example -- a client agent
 *
 *  Requests services it cannot perform itself.  It declares no solvables of
 *  its own, which the Developer's Guide explicitly allows: an agent with
 *  nothing to offer registers with the empty list.
 *
 *  Note that oaa_solve/2 is used exactly as call/1 would be: it blocks, it can
 *  fail, and it backtracks over multiple solutions.  Nothing in this file
 *  names an agent, a host or a port -- which is the point of delegation.
 */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').

:- initialization(run, main).

run :-
    oaa_agent_start(client, [], []),
    %  Probe with a representative goal rather than a wholly unbound one.  A
    %  solvable that declares argspecs(in(number, true), ...) requires its
    %  input to be instantiated, so can_solve(square(_, _), A) correctly
    %  matches nothing.  Asking about square(1, _) asks the real question.
    await_capability(square(1, _), 50),
    await_capability(greet(world, _), 50),

    (   oaa_solve(square(7, Sq), [])
    ->  format("square(7) = ~w~n", [Sq])
    ;   format("square: no solution~n", [])
    ),

    findall(G, oaa_solve(greet(world, G), []), Greetings),
    length(Greetings, N),
    format("greet solutions: ~w~n", [N]),
    forall(member(G, Greetings), format("  ~w~n", [G])),

    (   oaa_solve(no_such_capability(_), [time_limit(1)])
    ->  format("unexpected solution~n", [])
    ;   format("unsolvable goal failed, as it should~n", [])
    ),
    halt(0).

%   Wait until some agent in the community offers a capability.  Asking the
%   facilitator's can_solve solvable is the documented way to find out.
await_capability(_, 0) :- !,
    throw(oaa_error(capability_never_appeared)).
await_capability(Goal, N) :-
    (   oaa_solve(can_solve(Goal, _), [address(parent), time_limit(1)])
    ->  true
    ;   sleep(0.1),
        N1 is N - 1,
        await_capability(Goal, N1)
    ).
