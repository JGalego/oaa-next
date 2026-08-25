/*  oaa-next -- Facilitator: provider selection and delegation
 *
 *  Provenance: RECONSTRUCTED.
 *  Developer's Guide v2.3.2 sections 5.1.2, 5.1.4, 5.6, 6.3, 6.14;
 *  research/implementation-notes/facilitator.md section 4.
 */

:- module(fac_delegate,
          [ fac_candidates/3,           % +Goal, +Registry, -Candidates
            fac_order/2,                % +Candidates, -Ordered
            fac_select/5,               % +Goal, +Registry, +Params, +Requester, -Selected
            fac_meta_agents/3,          % +Registry, +Type, -Providers
            fac_dispatch_plan/4         % +Selected, +Params, -Mode, -Batch
          ]).

:- use_module('../icl/icl_term').
:- use_module('../icl/icl_params').
:- use_module('../agents/oaa_solvable').

/** <module> How the Facilitator chooses who solves a goal

The delegation sequence, in the order the Facilitator applies it:

  1. **Match by unification** against every connected agent's goal templates.
     Goal templates alone take part; permissions and parameters stay out.
  2. **Filter by argspecs**, honouring the ICL supertype hierarchy.
  3. **Order by utility**, descending; ties keep registration order, which is
     what "first-come, first-served" means for agents of equal utility.
  4. **Consult a prioritize meta-agent**, if one is registered, which may
     reorder the list.
  5. **Dispatch according to strategy** -- all candidates in parallel, or one
     at a time until the solution limit is met.
  6. **Collect and reply.**

Steps 1-3 and 5-6 are deterministic and must stay that way.  Step 4 is the
only place external judgement enters, and OAA defined it as optional and
fallible from the start: if no meta-agent returns anything usable, the
Facilitator's own ordering stands.  That is the seam an LLM attaches to, and
the reason the LLM extension needs no change to the Facilitator at all.

The registry is passed in as a list of

    agent(Id, Name, Solvables)

so that this module is a pure function of the community's state and can be
tested without a socket in sight.
*/

%!  fac_candidates(+Goal, +Registry, -Candidates) is det.
%
%   Every agent that can answer Goal, as candidate(Id, Solvable, Utility), in
%   registry order.  Matching leaves no bindings behind: the same goal is
%   tested against many templates and one candidate's bindings must not leak
%   into the next.

fac_candidates(Goal, Registry, Candidates) :-
    findall(candidate(Id, S, Utility),
            ( member(agent(Id, _Name, Solvables), Registry),
              member(S, Solvables),
              solvable_matches(Goal, S),
              solvable_utility(S, Utility)
            ),
            Candidates).

%!  fac_order(+Candidates, -Ordered) is det.
%
%   Highest utility first.  Within one utility, registry order is preserved,
%   so equal-utility agents are served first-come, first-served.

fac_order(Candidates, Ordered) :-
    number_list(Candidates, 0, Numbered),
    map_keys(Numbered, Keyed),
    keysort(Keyed, Sorted),
    values(Sorted, Ordered).

number_list([], _, []).
number_list([H|T], N, [N-H|R]) :-
    N1 is N + 1,
    number_list(T, N1, R).

%   keysort/2 is stable, so sorting on NegativeUtility-Position gives
%   descending utility with insertion order preserved inside each band.
map_keys([], []).
map_keys([Pos-candidate(Id, S, U)|T], [Key-candidate(Id, S, U)|R]) :-
    NegU is -U,
    Key = NegU-Pos,
    map_keys(T, R).

values([], []).
values([_-V|T], [V|R]) :- values(T, R).

%!  fac_select(+Goal, +Registry, +Params, +Requester, -Selected) is det.
%
%   The full selection: candidates, ordering, the reflexive rule, and
%   provider_limit.
%
%   reflexive defaults to true -- the requester is considered as a solver of
%   its own request, but only when the goal actually matches one of its own
%   solvables.  reflexive(false) removes it from consideration.

fac_select(Goal, Registry, Params, Requester, Selected) :-
    fac_candidates(Goal, Registry, Candidates0),
    icl_get_param_value(reflexive(Reflexive), Params, true),
    (   Reflexive == false
    ->  exclude(candidate_of(Requester), Candidates0, Candidates)
    ;   Candidates = Candidates0
    ),
    fac_order(Candidates, Ordered),
    apply_provider_limit(Ordered, Params, Selected).

candidate_of(Id, candidate(Id, _, _)).

apply_provider_limit(Ordered, Params, Selected) :-
    (   icl_get_param_value(provider_limit(N), Params),
        integer(N)
    ->  take(N, Ordered, Selected)
    ;   Selected = Ordered
    ).

take(N, _, []) :- N =< 0, !.
take(_, [], []) :- !.
take(N, [H|T], [H|R]) :-
    N1 is N - 1,
    take(N1, T, R).

%!  fac_meta_agents(+Registry, +Type, -Providers) is det.
%
%   Agents declaring a meta capability of the given type, in utility order.
%   Developer's Guide 5.6: meta(Type, +Goal, +Params, +FacInfo, -Result), with
%   Type one of lookup, prioritize, plan_query, execute_plan.
%
%   Several meta-agents may be able to contribute; they are themselves ordered
%   by expected utility and consulted in turn until one returns information
%   the Facilitator can use.

fac_meta_agents(Registry, Type, Providers) :-
    Probe = meta(Type, _Goal, _Params, _FacInfo, _Result),
    fac_candidates(Probe, Registry, Candidates),
    fac_order(Candidates, Providers).

%!  fac_dispatch_plan(+Selected, +Params, -Mode, -Batch) is det.
%
%   How to send the request out.
%
%     * parallel  -- every selected provider is asked at once and the
%                    solutions are collected into one reply.  This is the
%                    default, and what strategy(query) asks for.
%     * serial    -- providers are tried one at a time until the solution
%                    limit is met.  strategy(action) selects this, with a
%                    solution limit of 1, so that a request with a side effect
%                    -- sending a fax -- happens once rather than five times.
%
%   Batch is the set to contact now: all of them when parallel, the first
%   otherwise.

fac_dispatch_plan(Selected, Params, Mode, Batch) :-
    icl_get_param_value(parallel_ok(Parallel), Params, true),
    (   Parallel == false
    ->  Mode = serial,
        ( Selected = [First|_] -> Batch = [First] ; Batch = [] )
    ;   Mode = parallel,
        Batch = Selected
    ).
