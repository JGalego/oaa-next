#!/usr/bin/env swipl
/*  oaa-next example -- asking across a facilitator hierarchy
 *
 *  This client is attached to a node facilitator.  One of the capabilities it
 *  asks for lives in its own community; the other lives above, in the root
 *  facilitator's community.
 *
 *  The difference between them is the propagate parameter.  Nothing
 *  propagates by default -- the Developer's Guide gives up/1 and down/1a
 *  default of false -- so a goal this community cannot satisfy simply fails
 *  unless the requester asks for it to be referred upward.
 */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').

:- initialization(run, main).

run :-
    oaa_agent_start(hierarchy_client, [], []),
    await_capability(square(1, _), 60),

    (   oaa_solve(square(4, S), [])
    ->  format("local community: square(4) = ~w~n", [S])
    ;   format("local community: no solution~n", [])
    ),

    %  Without propagation, a capability held only above is out of reach.
    (   oaa_solve(greet(world, _), [time_limit(2)])
    ->  format("unpropagated: unexpectedly solved~n", [])
    ;   format("unpropagated: no solution, as expected~n", [])
    ),

    %  With it, the node facilitator refers the goal to its parent.
    (   oaa_solve(greet(world, G), [propagate([up(true)]), time_limit(10)])
    ->  format("propagated up: ~w~n", [G])
    ;   format("propagated up: no solution~n", [])
    ),
    halt(0).

await_capability(_, 0) :- !, throw(oaa_error(capability_never_appeared)).
await_capability(Goal, N) :-
    (   oaa_solve(can_solve(Goal, _), [address(parent), time_limit(1)])
    ->  true
    ;   sleep(0.1), N1 is N - 1, await_capability(Goal, N1)
    ).
