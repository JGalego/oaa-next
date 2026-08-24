/*  oaa-next -- solvables
 *
 *  Provenance: RECONSTRUCTED.
 *  Developer's Guide v2.3.2 sections 4.3.1, 5.1 and 5.2.
 */

:- module(oaa_solvable,
          [ solvable_normalize/2,       % +Spec, -Solvable
            solvable_list/2,            % +SpecOrList, -Solvables
            solvable_goal/2,            % +Solvable, -GoalTemplate
            solvable_type/2,            % +Solvable, -Type
            solvable_utility/2,         % +Solvable, -Utility
            solvable_callback/2,        % +Solvable, -Callback
            solvable_param/2,           % +Solvable, ?Param
            solvable_permission/2,      % +Solvable, ?Permission
            solvable_is_private/1,      % +Solvable
            solvable_matches/2,         % +Goal, +Solvable
            solvable_match/3,           % +Goal, +Solvable, -Event
            solvable_default_params/1,  % -Defaults
            solvable_default_perms/1    % -Defaults
          ]).

:- use_module('../icl/icl_term').
:- use_module('../icl/icl_type').
:- use_module('../icl/icl_params').

/** <module> Solvables -- OAA capability declarations

A solvable is a capability declaration:

    solvable(GoalTemplate, Parameters, Permissions)

Shorthand forms drop trailing arguments, down to a bare goal template; all of
them normalize to the three-argument form, exactly as the historical libraries
did on receipt.

Matching is **unification of the goal against the goal template**.  Neither
permissions nor parameters take part.  That is the property most at risk of
being eroded by a "modernized" implementation, so it is stated here and tested
directly: OAA capability matching is exact and deterministic, never
similarity-based.
*/

%!  solvable_default_params(-Defaults) is det.
%
%   Parameter defaults.  Developer's Guide 5.1.4 and 5.1.5.

solvable_default_params([ type(procedure),
                          utility(5),
                          priority(5),
                          private(false),
                          single_value(false),
                          unique_values(false),
                          persistent(false),
                          bookkeeping(true)
                        ]).

%!  solvable_default_perms(-Defaults) is det.
%
%   Permission defaults: call(true), write(false), read(false).
%   Developer's Guide 5.1.3.

solvable_default_perms([call(true), write(false), read(false)]).

%!  solvable_normalize(+Spec, -Solvable) is semidet.
%
%   Accept any of the forms the Developer's Guide 5.1.5 lists and produce the
%   standard three-argument form:
%
%       solvable(Goal, Params, Perms)
%       solvable(Goal, Params)
%       solvable(Goal)
%       Goal

solvable_normalize(Spec, solvable(Goal, Params, Perms)) :-
    nonvar(Spec),
    (   Spec = solvable(G, P, Q)
    ->  Goal = G, Params = P, Perms = Q
    ;   Spec = solvable(G, P)
    ->  Goal = G, Params = P, Perms = []
    ;   Spec = solvable(G)
    ->  Goal = G, Params = [], Perms = []
    ;   Goal = Spec, Params = [], Perms = []
    ),
    %  A goal template must have a functor; a bare variable or a number is not
    %  a capability.
    icl_functor(Goal, _, _).

%!  solvable_list(+SpecOrList, -Solvables) is semidet.
%
%   Normalize a single solvable or a list of them.  The libraries accepted
%   either wherever a solvable list was expected.

solvable_list(Spec, Solvables) :-
    (   is_list(Spec)
    ->  maplist(solvable_normalize, Spec, Solvables)
    ;   solvable_normalize(Spec, S),
        Solvables = [S]
    ).

solvable_goal(solvable(Goal, _, _), Goal).

%!  solvable_param(+Solvable, ?Param) is semidet.
%
%   Read a parameter, falling back to its default.

solvable_param(solvable(_, Params, _), Param) :-
    solvable_default_params(Defaults),
    lookup_with_default(Params, Defaults, Param).

%!  solvable_permission(+Solvable, ?Permission) is semidet.

solvable_permission(solvable(_, _, Perms), Perm) :-
    solvable_default_perms(Defaults),
    lookup_with_default(Perms, Defaults, Perm).

%   lookup_with_default(+Given, +Defaults, ?Param)
%
%   Resolve a parameter against a declaration.  The default applies only when
%   the parameter is *absent*: a parameter present with a different value must
%   fail rather than silently fall through to the default, or a declared
%   call(false) would still read as call(true).

lookup_with_default(Given, Defaults, Param) :-
    functor(Param, Name, Arity),
    functor(Probe, Name, Arity),
    icl_param_expand(Given, Expanded),
    (   memberchk(Probe, Expanded)
    ->  Param = Probe
    ;   icl_param_expand(Defaults, ExpandedDefaults),
        memberchk(Probe, ExpandedDefaults),
        Param = Probe
    ).

solvable_type(S, Type) :-
    solvable_param(S, type(Type)).

solvable_utility(S, Utility) :-
    solvable_param(S, utility(Utility)).

%!  solvable_callback(+Solvable, -Callback) is semidet.
%
%   The callback named in the declaration.  Data and trigger solvables have
%   none: callbacks for data solvables are supplied by the library, and
%   trigger solvables have no need of one (Developer's Guide 5.3).

solvable_callback(S, Callback) :-
    solvable_param(S, callback(Callback)),
    Callback \== '$none'.

solvable_is_private(S) :-
    solvable_param(S, private(true)).

%!  solvable_matches(+Goal, +Solvable) is semidet.
%
%   True when Goal is a request this solvable answers.  Three conditions, in
%   the order the Facilitator applies them:
%
%     1. the goal unifies with the goal template (and only the template --
%        Developer's Guide 5.1.2);
%     2. the solvable is callable, i.e. permission call(true);
%     3. every argument conforms to the corresponding argspec, if the
%        declaration carries one.
%
%   No bindings are left behind: the caller may be testing many candidates.

solvable_matches(Goal, Solvable) :-
    Solvable = solvable(Template, _, _),
    icl_matches(Goal, Template),
    solvable_permission(Solvable, call(true)),
    argspecs_ok(Goal, Solvable).

argspecs_ok(Goal, Solvable) :-
    (   argspec_list(Solvable, Specs)
    ->  Goal =.. [_|Args],
        same_length(Args, Specs),
        maplist(icl_conforms_argspec, Args, Specs)
    ;   %  Absent argspecs, every argument is inout(_, false): any type,
        %  not required.  Developer's Guide 5.2.
        true
    ).

%   argspecs is written as one term whose arguments are the specs, so its
%   arity varies with the arity of the goal template:
%
%       argspecs(Spec1, Spec2, ..., SpecN)
%
%   It therefore has to be found by functor name rather than by name/arity.

argspec_list(solvable(_, Params, _), Specs) :-
    icl_param_expand(Params, Expanded),
    member(A, Expanded),
    compound(A),
    functor(A, argspecs, _),
    !,
    A =.. [argspecs|Specs].

%!  solvable_match(+Goal, +Solvable, -Event) is semidet.
%
%   The event to deliver to the providing agent: the result of unifying the
%   goal with a fresh copy of the goal template.  Developer's Guide 5.1.2.

solvable_match(Goal, Solvable, Event) :-
    solvable_matches(Goal, Solvable),
    Solvable = solvable(Template, _, _),
    icl_match(Goal, Template, Event).
