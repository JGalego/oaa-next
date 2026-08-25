/*  oaa-next -- Facilitator delegation tests
 *
 *  These are the architectural scenarios from docs/roadmap/phase-1.md:
 *  they assert what the Facilitator does, leaving aside how it is written.
 */

:- module(test_delegate, []).

:- use_module('../../src/facilitator/fac_delegate').
:- use_module('../../src/agents/oaa_solvable').

%   A small community.  mail_a and mail_b both send mail; mail_b claims to do
%   it better.  fax sends faxes.  db answers a data solvable.
registry(R) :-
    solvable_list([solvable(send(mail, _, _), [callback(cb)], [])], MA),
    solvable_list([solvable(send(mail, _, _), [callback(cb), utility(9)], [])], MB),
    solvable_list([solvable(send(fax, _, _), [callback(cb)], [])], F),
    solvable_list([solvable(rating(_, _), [type(data)], [write(true)])], D),
    R = [ agent(1, mail_a, MA),
          agent(2, mail_b, MB),
          agent(3, fax,    F),
          agent(4, db,     D) ].

:- begin_tests(fac_selection).

%   Given an agent advertises capability X, when another agent requests X,
%   then the Facilitator discovers and delegates to that agent.
test(discovers_provider) :-
    registry(R),
    fac_select(send(fax, adam, doc), R, [], 99, Selected),
    Selected = [candidate(Id, _, _)],
    Id == 3.

test(no_provider_selects_nothing) :-
    registry(R),
    fac_select(telepathy(adam), R, [], 99, Selected),
    Selected == [].

test(unrelated_agents_not_selected) :-
    registry(R),
    fac_select(send(mail, adam, hi), R, [], 99, Selected),
    findall(I, member(candidate(I, _, _), Selected), Ids),
    msort(Ids, Sorted),
    Sorted == [1, 2].

%   Given multiple agents provide capability X, the Facilitator can select an
%   appropriate provider -- ordering by declared utility.
test(orders_by_utility) :-
    registry(R),
    fac_select(send(mail, adam, hi), R, [], 99, [First|_]),
    First = candidate(Id, _, U),
    Id == 2, U == 9.

%   Equal utility keeps registration order: first come, first served.
test(equal_utility_is_fifo) :-
    solvable_list([send(mail, _, _)], S),
    R = [agent(a, an_a, S), agent(b, a_b, S), agent(c, a_c, S)],
    fac_select(send(mail, x, y), R, [], 99, Selected),
    findall(I, member(candidate(I, _, _), Selected), Ids),
    Ids == [a, b, c].

test(provider_limit) :-
    registry(R),
    fac_select(send(mail, adam, hi), R, [provider_limit(1)], 99, Selected),
    length(Selected, 1),
    Selected = [candidate(2, _, _)].

%   reflexive defaults to true, so a requester that can solve its own goal is
%   considered; reflexive(false) removes it.
test(reflexive_default_includes_requester) :-
    registry(R),
    fac_select(send(mail, adam, hi), R, [], 1, Selected),
    memberchk(candidate(1, _, _), Selected).
test(reflexive_false_excludes_requester) :-
    registry(R),
    fac_select(send(mail, adam, hi), R, [reflexive(false)], 1, Selected),
    \+ memberchk(candidate(1, _, _), Selected),
    memberchk(candidate(2, _, _), Selected).

%   A data solvable is selected by the same matching as a procedure solvable:
%   calling one looks the same as calling the other.
test(data_solvable_selected_like_procedure) :-
    registry(R),
    fac_select(rating(delta, _), R, [], 99, Selected),
    Selected = [candidate(4, _, _)].

%   call(false) takes a solvable out of consideration entirely.
test(call_false_not_selected) :-
    solvable_list([solvable(hidden(_), [], [call(false)])], S),
    fac_select(hidden(x), [agent(1, a, S)], [], 99, Selected),
    Selected == [].

%   A private solvable never reaches the Facilitator, so it cannot appear in
%   a registry; this checks the agent-side filter is what excludes it, by
%   confirming the Facilitator would otherwise have matched it.
test(private_would_match_if_registered) :-
    solvable_list([solvable(secret(_), [private(true), callback(cb)], [])], S),
    fac_select(secret(x), [agent(1, a, S)], [], 99, Selected),
    Selected = [candidate(1, _, _)].

:- end_tests(fac_selection).


:- begin_tests(fac_dispatch).

%   Developer's Guide 6.14: strategy(query) fans out in parallel.
test(query_is_parallel) :-
    registry(R),
    fac_select(send(mail, a, b), R, [parallel_ok(true)], 99, Selected),
    fac_dispatch_plan(Selected, [parallel_ok(true)], Mode, Batch),
    Mode == parallel,
    length(Batch, 2).

%   strategy(action) means one provider at a time: sending a fax to several
%   fax agents at once would deliver several copies.
test(action_is_serial) :-
    registry(R),
    fac_select(send(mail, a, b), R, [parallel_ok(false)], 99, Selected),
    fac_dispatch_plan(Selected, [parallel_ok(false), solution_limit(1)], Mode, Batch),
    Mode == serial,
    Batch = [candidate(2, _, _)].

test(serial_with_no_providers) :-
    fac_dispatch_plan([], [parallel_ok(false)], serial, []).

test(default_is_parallel) :-
    registry(R),
    fac_select(send(mail, a, b), R, [], 99, Selected),
    fac_dispatch_plan(Selected, [], parallel, Batch),
    length(Batch, 2).

:- end_tests(fac_dispatch).


:- begin_tests(fac_meta).

%   Meta-agents are found by their meta/5 solvable and ordered by utility,
%   exactly like any other provider.  Developer's Guide 5.6.
test(finds_prioritize_meta_agent) :-
    solvable_list([solvable(meta(prioritize, _, _, _, _), [callback(cb)], [])], M),
    solvable_list([send(mail, _, _)], S),
    R = [agent(1, plain, S), agent(2, smart, M)],
    fac_meta_agents(R, prioritize, Providers),
    Providers = [candidate(2, _, _)].

test(no_meta_agent_is_empty) :-
    registry(R),
    fac_meta_agents(R, prioritize, Providers),
    Providers == [].

test(meta_types_are_distinct) :-
    solvable_list([solvable(meta(lookup, _, _, _, _), [callback(cb)], [])], M),
    R = [agent(1, finder, M)],
    fac_meta_agents(R, lookup, [_]),
    fac_meta_agents(R, prioritize, []).

test(meta_agents_ordered_by_utility) :-
    solvable_list([solvable(meta(prioritize,_,_,_,_), [callback(cb)], [])], M1),
    solvable_list([solvable(meta(prioritize,_,_,_,_), [callback(cb), utility(8)], [])], M2),
    R = [agent(1, first, M1), agent(2, better, M2)],
    fac_meta_agents(R, prioritize, [candidate(Id, _, _)|_]),
    Id == 2.

:- end_tests(fac_meta).


:- use_module('../../src/facilitator/fac_compound').
:- use_module('../../src/icl/icl_term').

:- begin_tests(fac_compound).

test(recognises_conjunction) :-
    icl_parse_term("(a, b)", G), is_compound_goal(G).
test(recognises_disjunction) :-
    icl_parse_term("(a ; b)", G), is_compound_goal(G).
test(atomic_is_not_compound, [fail]) :-
    icl_parse_term("send(mail, x)", G), is_compound_goal(G).
test(recognises_through_wrappers) :-
    icl_parse_term("agent : (a, b) :: [priority(9)]", G), is_compound_goal(G).

test(flattens_conjunction) :-
    icl_parse_term("(a, b, c)", G), goal_conjuncts(G, Cs), Cs == [a, b, c].
test(disjunction_stays_whole) :-
    icl_parse_term("(a ; b)", G), goal_conjuncts(G, Cs), Cs == [(a ; b)].

%   Shared variables join conjuncts: solving the first fixes the second.
test(solutions_propagate_bindings) :-
    icl_parse_term("(p(X), q(X))", G),
    initial_branch(G, B),
    branch_step(B, dispatch(Head, _, _)),
    Head =@= p(_),
    branch_advance(B, [p(1), p(2)], [B1, B2]),
    B1 = branch(_, [Next1|_]), Next1 == q(1),
    B2 = branch(_, [Next2|_]), Next2 == q(2).

%   Branches are independent: binding one cannot reach its sibling.
test(branches_do_not_share_bindings) :-
    icl_parse_term("(p(X), q(X))", G),
    initial_branch(G, B),
    branch_advance(B, [p(1), p(2)], [branch(T1, _), branch(T2, _)]),
    T1 == (p(1), q(1)),
    T2 == (p(2), q(2)).

%   No solutions kills the branch, which is how a failing conjunct prunes
%   everything that would have followed it.
test(no_solutions_prunes_branch) :-
    icl_parse_term("(p(X), q(X))", G),
    initial_branch(G, B),
    branch_advance(B, [], Branches),
    Branches == [].

test(disjunction_expands_to_two_branches) :-
    icl_parse_term("(a ; b)", G),
    initial_branch(G, B),
    branch_step(B, expand([branch(_, [L|_]), branch(_, [R|_])])),
    L == a, R == b.

test(exhausted_branch_is_a_solution) :-
    branch_step(branch(done(1), []), solution(done(1))).

%   A subgoal may carry its own address and parameters, the nested parameter
%   lists the Developer's Guide allows inside a compound goal.
test(subgoal_carries_address_and_params) :-
    icl_parse_term("(agent7 : p(X) :: [priority(9)], q(X))", G),
    initial_branch(G, B),
    branch_step(B, dispatch(Sub, Params, Address)),
    Sub =@= p(_),
    Address == agent7,
    Params == [priority(9)].

:- end_tests(fac_compound).
