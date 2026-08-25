#!/usr/bin/env swipl
/*  oaa-next example -- a time trigger and a delayed solution  */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').
:- use_module('../../src/agents/oaa_trigger').
:- use_module('../../src/agents/oaa_time').
:- use_module('../../src/runtime/oaa_event').

solvables([ solvable(wake_up(_Note), [callback(woken)], []) ]).

:- dynamic woken/0.
woken(wake_up(_Note), _Params) :- assertz(woken).

:- initialization(run, main).

run :-
    solvables(S),
    oaa_agent_start(timed_client, S, [timeout(0.1)]),
    await_capability(move_robot(r1, 1, 1), 60),

    %  A goal that takes time to answer still blocks like any other.
    (   oaa_solve(move_robot(r1, 100, 100), [time_limit(15)])
    ->  format("robot arrived~n", [])
    ;   format("robot did not arrive~n", [])
    ),

    %  A time trigger, addressed to the Alarm agent because no agent library
    %  implements time triggers itself.
    icl_date_now(Now),
    oaa_add_trigger(time,
                    time_expr(Now, Now, recurrence(0, 0)),
                    oaa_Solve(wake_up('time to go'), []),
                    [address(name(alarm))]),
    ( wait_woken(60) -> format("time trigger fired~n") ; format("time trigger did not fire~n") ),
    halt(0).

wait_woken(0) :- !, fail.
wait_woken(N) :-
    (   woken
    ->  true
    ;   oaa_agent_loop_once,
        N1 is N - 1,
        wait_woken(N1)
    ).

await_capability(_, 0) :- !, throw(oaa_error(capability_never_appeared)).
await_capability(Goal, N) :-
    (   oaa_solve(can_solve(Goal, _), [address(parent), time_limit(1)])
    ->  true
    ;   sleep(0.1), N1 is N - 1, await_capability(Goal, N1)
    ).
