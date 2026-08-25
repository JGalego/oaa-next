#!/usr/bin/env swipl
/*  oaa-next example -- compound goals
 *
 *  A compound goal is one request that the Facilitator takes apart and
 *  delegates piece by piece.  The client writes what it wants; which agent
 *  answers which conjunct, and in what order, is the Facilitator's business.
 *
 *  The Developer's Guide gives this as the reason for expressing request
 *  content in ICL rather than in an opaque payload: the Facilitator can see
 *  into the request, decompose it, and delegate the subrequests individually.
 *
 *  Variables shared between conjuncts join them.  In `(square(3, A),
 *  square(A, B))` the first conjunct fixes A before the second is dispatched,
 *  so the two subgoals go out one after the other rather than together.
 */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').
:- use_module('../../src/icl/icl_term').

:- initialization(run, main).

run :-
    oaa_agent_start(compound_client, [], []),
    await_capability(square(1, _), 50),
    await_capability(greet(world, _), 50),

    %  A join: the second conjunct depends on the first.
    (   oaa_solve((square(3, A), square(A, B)), [])
    ->  format("chained: 3 -> ~w -> ~w~n", [A, B])
    ;   format("chained: no solution~n", [])
    ),

    %  A conjunction spanning two different agents.
    findall(N-G,
            oaa_solve((square(2, N), greet(world, G)), []),
            Pairs),
    length(Pairs, PairCount),
    format("cross-agent pairs: ~w~n", [PairCount]),

    %  A disjunction: either branch may supply solutions.
    findall(X, oaa_solve((square(5, X) ; square(6, X)), []), Xs),
    msort(Xs, Sorted),
    format("disjunction: ~w~n", [Sorted]),

    %  A conjunct nothing can solve prunes the whole request.
    (   oaa_solve((square(2, _), no_such_thing(_)), [time_limit(3)])
    ->  format("unexpected solution~n", [])
    ;   format("failing conjunct pruned the request~n", [])
    ),
    halt(0).

await_capability(_, 0) :- !, throw(oaa_error(capability_never_appeared)).
await_capability(Goal, N) :-
    (   oaa_solve(can_solve(Goal, _), [address(parent), time_limit(1)])
    ->  true
    ;   sleep(0.1), N1 is N - 1, await_capability(Goal, N1)
    ).
