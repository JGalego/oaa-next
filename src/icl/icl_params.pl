/*  oaa-next -- ICL parameter lists
 *
 *  Provenance: RECONSTRUCTED.
 *  Developer's Guide v2.3.2 section 4.3.6.
 */

:- module(icl_params,
          [ icl_get_param_value/2,      % +Pattern, +Params
            icl_get_param_value/3,      % +Pattern, +Params, +Default
            icl_param_expand/2,         % +Params, -Expanded
            icl_param_set/3,            % +Param, +Params, -NewParams
            icl_param_merge/3,          % +Overrides, +Params, -Merged
            icl_param_strip_defaults/3, % +Defaults, +Params, -Stripped
            icl_param_apply_defaults/3  % +Defaults, +Params, -Complete
          ]).

/** <module> ICL parameter lists

Parameters are functors with arguments -- `type(data)`, `solution_limit(5)`.
These conventions from the Developer's Guide carry real weight:

  * A boolean parameter whose value is `true` may omit the value, so
    `[type(data), single_value, persistent]` and
    `[type(data), single_value(true), persistent(true)]` denote the same list.

  * Parameters sitting at their default value are normally stripped before a
    request goes to the Facilitator, to conserve bandwidth.

The second has a consequence worth stating: **a parameter list does not
survive a request verbatim**.  Anything reading a parameter must therefore
supply the default for an absent parameter rather than fail on it, which is
why icl_get_param_value/3 exists alongside icl_get_param_value/2.
*/

%!  icl_get_param_value(+Pattern, +Params) is semidet.
%
%   Retrieve a parameter by unifying Pattern against the list, as the
%   historical `icl_GetParamValue` did: given `from(Requestor)`, Requestor is
%   bound to the value of the `from` parameter.  Fails if absent.

icl_get_param_value(Pattern, Params) :-
    icl_param_expand(Params, Expanded),
    functor(Pattern, Name, Arity),
    functor(Probe, Name, Arity),
    memberchk(Probe, Expanded),
    Pattern = Probe.

%!  icl_get_param_value(+Pattern, +Params, +Default) is det.
%
%   As icl_get_param_value/2, but unify the pattern's argument with Default
%   when the parameter is absent.

icl_get_param_value(Pattern, Params, Default) :-
    (   icl_get_param_value(Pattern, Params)
    ->  true
    ;   arg(1, Pattern, Default)
    ).

%!  icl_param_expand(+Params, -Expanded) is det.
%
%   Rewrite the boolean shorthand: a bare atom P becomes P(true).

icl_param_expand([], []).
icl_param_expand([P|Ps], [Q|Qs]) :-
    (   atom(P)
    ->  Q =.. [P, true]
    ;   Q = P
    ),
    icl_param_expand(Ps, Qs).

%!  icl_param_set(+Param, +Params, -NewParams) is det.
%
%   Replace any existing parameter with the same name and arity, or append.

icl_param_set(Param, Params, NewParams) :-
    icl_param_expand(Params, Expanded),
    functor(Param, Name, Arity),
    functor(Probe, Name, Arity),
    exclude([X]>>(\+ \+ X = Probe), Expanded, Rest),
    append(Rest, [Param], NewParams).

%!  icl_param_merge(+Overrides, +Params, -Merged) is det.
%
%   Apply each of Overrides to Params, later overrides winning.

icl_param_merge([], Params, Params).
icl_param_merge([O|Os], Params, Merged) :-
    icl_param_set(O, Params, Params1),
    icl_param_merge(Os, Params1, Merged).

%!  icl_param_strip_defaults(+Defaults, +Params, -Stripped) is det.
%
%   Remove parameters that sit at their default value.  This is what the
%   historical libraries did before sending a request onward.

icl_param_strip_defaults(Defaults, Params, Stripped) :-
    icl_param_expand(Params, Expanded),
    icl_param_expand(Defaults, ExpandedDefaults),
    exclude([P]>>memberchk(P, ExpandedDefaults), Expanded, Stripped).

%!  icl_param_apply_defaults(+Defaults, +Params, -Complete) is det.
%
%   Add any default not already present.  The inverse of stripping, applied on
%   receipt.

icl_param_apply_defaults(Defaults, Params, Complete) :-
    icl_param_expand(Params, Expanded),
    icl_param_expand(Defaults, ExpandedDefaults),
    exclude([D]>>( functor(D, N, A), functor(Probe, N, A),
                   memberchk(Probe, Expanded) ),
            ExpandedDefaults, Missing),
    append(Expanded, Missing, Complete).
