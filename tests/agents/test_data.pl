/*  oaa-next -- data solvable tests  */

:- module(test_data, []).

:- use_module('../../src/agents/oaa_data').

:- begin_tests(oaa_data, [setup(oaa_data_clear), cleanup(oaa_data_clear)]).

test(add_and_query, [setup(oaa_data_clear)]) :-
    oaa_data_add(a1, rating(delta, 4), [], true),
    oaa_data_query(rating(delta, R)), R == 4.

%  New facts are appended, so a later query returns them last.
test(append_order, [setup(oaa_data_clear)]) :-
    oaa_data_add(a1, r(1), [], _),
    oaa_data_add(a1, r(2), [], _),
    oaa_data_add(a1, r(3), [], _),
    findall(X, oaa_data_query(r(X)), Xs),
    Xs == [1,2,3].

test(at_beginning_prepends, [setup(oaa_data_clear)]) :-
    oaa_data_add(a1, r(1), [], _),
    oaa_data_add(a1, r(2), [at_beginning(true)], _),
    findall(X, oaa_data_query(r(X)), Xs),
    Xs == [2,1].

%  Duplicates are allowed by default.
test(duplicates_allowed, [setup(oaa_data_clear)]) :-
    oaa_data_add(a1, r(1), [], _),
    oaa_data_add(a1, r(1), [], _),
    findall(X, oaa_data_query(r(X)), Xs),
    length(Xs, 2).

test(unique_values_refuses, [setup(oaa_data_clear)]) :-
    oaa_data_add(a1, r(1), [unique_values(true)], true),
    oaa_data_add(a1, r(1), [unique_values(true)], false),
    findall(X, oaa_data_query(r(X)), Xs),
    length(Xs, 1).

test(single_value_displaces, [setup(oaa_data_clear)]) :-
    oaa_data_add(a1, last(1), [single_value(true)], _),
    oaa_data_add(a1, last(2), [single_value(true)], _),
    findall(X, oaa_data_query(last(X)), Xs),
    Xs == [2].

%  Removal takes only the first unifying fact unless do_all is given.
test(remove_first_only, [setup(oaa_data_clear)]) :-
    oaa_data_add(a1, r(1), [], _), oaa_data_add(a1, r(2), [], _),
    oaa_data_remove(a1, r(_), [], Count), Count == 1,
    findall(X, oaa_data_query(r(X)), Xs),
    Xs == [2].

test(remove_all, [setup(oaa_data_clear)]) :-
    oaa_data_add(a1, r(1), [], _), oaa_data_add(a1, r(2), [], _),
    oaa_data_remove(a1, r(_), [do_all(true)], Count), Count == 2,
    findall(X, oaa_data_query(r(X)), Xs),
    Xs == [].

test(remove_nonexistent, [setup(oaa_data_clear)]) :-
    oaa_data_remove(a1, r(_), [], Count), Count == 0.

%  Replacement happens as a single operation.
test(replace, [setup(oaa_data_clear)]) :-
    oaa_data_add(a1, pos(car, 0, 0), [], _),
    oaa_data_replace(a1, pos(car, _, _), pos(car, 5, 9), [], true),
    findall(X-Y, oaa_data_query(pos(car, X, Y)), Ps),
    Ps == [5-9].

test(replace_nothing_matching, [setup(oaa_data_clear)]) :-
    oaa_data_replace(a1, pos(car, _, _), pos(car, 1, 1), [], Ok),
    Ok == false,
    findall(x, oaa_data_query(pos(car, _, _)), Ps),
    Ps == [].

%  Ownership is recorded transparently, is queryable, and is what removes an
%  agent's facts when it goes offline.  Developer's Guide 7.5.
test(ownership_recorded, [setup(oaa_data_clear)]) :-
    oaa_data_add(agent_a, task(1), [], _),
    oaa_data_add(agent_b, task(2), [], _),
    once(oaa_data_query(task(1), O1)), O1 == agent_a,
    once(oaa_data_query(task(2), O2)), O2 == agent_b.

test(query_by_owner, [setup(oaa_data_clear)]) :-
    oaa_data_add(agent_a, task(1), [], _),
    oaa_data_add(agent_b, task(2), [], _),
    findall(X, oaa_data_query(task(X), agent_a), Xs),
    Xs == [1].

test(offline_removes_owned_facts, [setup(oaa_data_clear)]) :-
    oaa_data_add(agent_a, task(1), [], _),
    oaa_data_add(agent_b, task(2), [], _),
    oaa_data_remove_owner(agent_a),
    findall(X, oaa_data_query(task(X)), Xs),
    Xs == [2].

test(remove_restricted_to_owner, [setup(oaa_data_clear)]) :-
    oaa_data_add(agent_a, task(1), [], _),
    oaa_data_add(agent_b, task(2), [], _),
    oaa_data_remove(anyone, task(_), [do_all(true), owner(agent_b)], Count),
    Count == 1,
    findall(X, oaa_data_query(task(X)), Xs),
    Xs == [1].

%  Facts of different solvables do not interfere.
test(solvables_are_separate, [setup(oaa_data_clear)]) :-
    oaa_data_add(a1, alpha(1), [], _),
    oaa_data_add(a1, beta(2), [], _),
    findall(X, oaa_data_query(alpha(X)), As), As == [1],
    findall(X, oaa_data_query(beta(X)), Bs), Bs == [2].

:- end_tests(oaa_data).
