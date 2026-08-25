/*  oaa-next -- Facilitator: compound goals
 *
 *  Provenance: RECONSTRUCTED.
 *  Developer's Guide v2.3.2 sections 4.3 and 5.6; ICL operator semantics from
 *  the OAA 2.3.2 grammars.  The Reference Manual defers compound-goal
 *  parameter handling to documentation that has not been recovered, so the
 *  execution semantics below follow the logic-programming reading the
 *  Developer's Guide points at throughout.
 */

:- module(fac_compound,
          [ is_compound_goal/1,         % +Goal
            goal_conjuncts/2,           % +Goal, -Conjuncts
            initial_branch/2,           % +Goal, -Branch
            branch_step/2,              % +Branch, -Action
            branch_advance/3            % +Branch, +Solutions, -Branches
          ]).

:- use_module('../icl/icl_term').
:- use_module('../icl/icl_params').

/** <module> Decomposing and executing compound goals

The Developer's Guide gives a reason for expressing request content in ICL
rather than in some embedded language: it lets the facilitator see into a
request, so that it can decompose a compound one and delegate the subrequests
individually.  This module is that decomposition.

A compound goal is a conjunction `(A, B)` or a disjunction `A ; B`, in either
case nested arbitrarily.  Execution is a breadth-first walk over *branches*:

    branch(Template, Conjuncts)

`Template` is one instance of the whole original goal.  `Conjuncts` are the
subgoals still to be solved, drawn from that same instance, so they share its
variables.  Solving a conjunct and binding it therefore binds the template
too, which is how `(p(X), q(X))` joins: the solutions of `p(X)` fix `X` before
`q(X)` is ever dispatched.

Branching copies.  When a conjunct returns several solutions, or a disjunction
splits, each successor gets its own copy of template and remaining conjuncts,
so that bindings taken in one branch cannot leak into a sibling.

The walk is driven from outside, one dispatch at a time, because a facilitator
that blocked while waiting on a subgoal would be waiting on an agent that may
be waiting on it.
*/

%!  is_compound_goal(+Goal) is semidet.
%
%   True when Goal needs decomposing.  Address and parameter wrappers are
%   stripped first: `agent:(a, b)::[p]` is compound.

is_compound_goal(Goal) :-
    nonvar(Goal),
    icl_disassemble_goal(Goal, _Address, Bare, _Params),
    nonvar(Bare),
    ( Bare = (_, _) -> true ; Bare = (_ ; _) ).

%!  goal_conjuncts(+Goal, -Conjuncts) is det.
%
%   Flatten a conjunction into a list, leaving everything else alone.  A
%   disjunction stays whole: it is a choice, not a sequence.

goal_conjuncts(Goal, Conjuncts) :-
    (   nonvar(Goal), Goal = (A, B)
    ->  goal_conjuncts(A, As),
        goal_conjuncts(B, Bs),
        append(As, Bs, Conjuncts)
    ;   Conjuncts = [Goal]
    ).

%!  initial_branch(+Goal, -Branch) is det.

initial_branch(Goal, branch(Goal, Conjuncts)) :-
    goal_conjuncts(Goal, Conjuncts).

%!  branch_step(+Branch, -Action) is det.
%
%   What to do next with a branch:
%
%     * `solution(Template)`          -- nothing left to solve
%     * `expand(Branches)`            -- a conjunction or disjunction opened up
%     * `dispatch(Goal, Params, Address)` -- an atomic subgoal to delegate
%
%   A subgoal may carry its own address and parameter list, which the
%   Developer's Guide allows in the nested parameter lists of a compound goal.

branch_step(branch(Template, []), solution(Template)) :- !.
branch_step(branch(Template, [C|Rest]), Action) :-
    icl_disassemble_goal(C, Address, Bare, Params),
    (   nonvar(Bare), Bare = (_, _)
    ->  goal_conjuncts(Bare, Inner),
        append(Inner, Rest, Conjuncts),
        Action = expand([branch(Template, Conjuncts)])
    ;   nonvar(Bare), Bare = (Left ; Right)
    ->  disjunct_branches(Template, Left, Right, Rest, Branches),
        Action = expand(Branches)
    ;   Action = dispatch(Bare, Params, Address)
    ).

%   Each arm of a disjunction gets an independent copy, so that bindings made
%   while exploring one cannot reach the other.

disjunct_branches(Template, Left, Right, Rest, [BL, BR]) :-
    copy_term(t(Template, Left, Rest), t(TL, L, RestL)),
    goal_conjuncts(L, LConj),
    append(LConj, RestL, ConjL),
    BL = branch(TL, ConjL),
    copy_term(t(Template, Right, Rest), t(TR, R, RestR)),
    goal_conjuncts(R, RConj),
    append(RConj, RestR, ConjR),
    BR = branch(TR, ConjR).

%!  branch_advance(+Branch, +Solutions, -Branches) is det.
%
%   Continue a branch whose head conjunct has come back with Solutions.  One
%   successor per solution; no solutions means the branch dies, which is how a
%   failing conjunct prunes everything after it.

branch_advance(branch(_Template, []), _Solutions, []) :- !.
branch_advance(branch(Template, [C|Rest]), Solutions, Branches) :-
    icl_disassemble_goal(C, _Address, Bare, _Params),
    findall(branch(T2, Rest2),
            ( member(Solution, Solutions),
              copy_term(t(Template, Bare, Rest), t(T2, Head2, Rest2)),
              Head2 = Solution ),
            Branches).
