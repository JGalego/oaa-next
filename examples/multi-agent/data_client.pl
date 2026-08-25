#!/usr/bin/env swipl
/*  oaa-next example -- the data-solvable lifecycle
 *
 *  Follows SRI's own conformance test for data solvables, step for step:
 *  add two facts, query, remove one by exact value, query, remove by an
 *  unbound pattern, query again.
 */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').
:- use_module('../../src/agents/oaa_trigger').
:- use_module('../../src/agents/oaa_data').
:- use_module('../../src/runtime/oaa_event').
:- use_module('../../src/icl/icl_term').

:- initialization(run, main).

run :-
    %  reply_seen/1 is a data solvable so that the comm trigger below has
    %  somewhere to record what it saw: a trigger action is an ICL term, and
    %  the store it writes to has to be declared like any other.
    oaa_agent_start(data_client,
                    [solvable(reply_seen(_), [type(data), private(true)],
                              [write(true)])],
                    []),
    await_capability(foo(_), 60),

    oaa_add_data(foo(1093), []),
    oaa_add_data(foo(33), []),
    findall(X, oaa_solve(foo(X), []), Added),
    length(Added, N),
    format("added: ~w~n", [N]),

    oaa_remove_data(foo(1093), []),
    findall(F1, oaa_solve(foo(F1), []), After1),
    report("after removing 1093", After1),

    %  An unbound pattern removes the first match, do_all being false.
    oaa_remove_data(foo(_), []),
    findall(F2, oaa_solve(foo(F2), []), After2),
    report("after removing foo(_)", After2),

    (   oaa_solve(agent_host(_, _, _), [address(parent), time_limit(5)])
    ->  format("agent_host answered~n", [])
    ;   format("agent_host did not answer~n", [])
    ),

    check_reply_arity,
    halt(0).

report(Label, Values) :-
    findall(foo(V), member(V, Values), Terms),
    icl_term_string(Terms, S),
    format("~w: ~w~n", [Label, S]).

%   The reply to a data update is observed directly, to pin its shape.  A
%   comm trigger is the way an agent watches its own traffic: the library
%   consumes this reply itself inside oaa_AddData, so a comm trigger is the
%   only place an application can see it go past.
check_reply_arity :-
    oaa_add_trigger(comm,
                    event(_From, ev_data_updated(A, B, C, D, E, F), _P),
                    oaa_AddData(reply_seen(ev_data_updated(A, B, C, D, E, F)),
                                [address(self)]),
                    [recurrence(when)]),
    oaa_add_data(foo(7), [reply(true)]),
    (   oaa_data_query(reply_seen(Reply))
    ->  functor(Reply, _, Arity),
        format("ev_data_updated arity: ~w~n", [Arity])
    ;   format("ev_data_updated arity: none seen~n", [])
    ).

await_capability(_, 0) :- !, throw(oaa_error(capability_never_appeared)).
await_capability(Goal, N) :-
    (   oaa_solve(can_solve(Goal, _), [address(parent), time_limit(1)])
    ->  true
    ;   sleep(0.1), N1 is N - 1, await_capability(Goal, N1)
    ).
