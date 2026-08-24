/*  oaa-next -- solvable and parameter-list tests  */

:- module(test_solvable, []).

:- use_module('../../src/agents/oaa_solvable').
:- use_module('../../src/icl/icl_params').

:- begin_tests(icl_params).

test(get_value) :-
    icl_get_param_value(from(X), [to(b), from(adam)]), X == adam.
test(get_value_absent, [fail]) :-
    icl_get_param_value(from(_), [to(b)]).
test(get_value_default) :-
    icl_get_param_value(blocking(X), [], true), X == true.
test(get_value_present_beats_default) :-
    icl_get_param_value(blocking(X), [blocking(false)], true), X == false.

%  Developer's Guide 4.3.6: a boolean parameter with value true may omit it.
test(boolean_shorthand) :-
    icl_param_expand([type(data), single_value, persistent], E),
    E == [type(data), single_value(true), persistent(true)].
test(shorthand_reads_same) :-
    icl_get_param_value(single_value(X), [type(data), single_value]),
    X == true.

test(set_replaces) :-
    icl_param_set(blocking(false), [blocking(true), reply(true)], P),
    icl_get_param_value(blocking(X), P), X == false,
    icl_get_param_value(reply(Y), P), Y == true.
test(set_appends) :-
    icl_param_set(blocking(false), [reply(true)], P),
    icl_get_param_value(blocking(X), P), X == false.

test(merge) :-
    icl_param_merge([blocking(false), priority(9)], [blocking(true)], P),
    icl_get_param_value(blocking(B), P), B == false,
    icl_get_param_value(priority(N), P), N == 9.

%  Defaults are stripped before a request goes on the wire, so a parameter
%  list does not survive a request verbatim.
test(strip_defaults) :-
    icl_param_strip_defaults([blocking(true), reply(true)],
                             [blocking(true), reply(none), priority(9)], S),
    \+ memberchk(blocking(true), S),
    memberchk(reply(none), S),
    memberchk(priority(9), S).
test(apply_defaults) :-
    icl_param_apply_defaults([blocking(true), reply(true)], [reply(none)], C),
    memberchk(blocking(true), C),
    memberchk(reply(none), C),
    \+ memberchk(reply(true), C).
test(strip_then_apply_restores) :-
    Defaults = [blocking(true), reply(true)],
    Original = [blocking(true), reply(none)],
    icl_param_strip_defaults(Defaults, Original, Wire),
    icl_param_apply_defaults(Defaults, Wire, Restored),
    icl_get_param_value(blocking(B), Restored), B == true,
    icl_get_param_value(reply(R), Restored), R == none.

:- end_tests(icl_params).


:- begin_tests(solvable).

%  Developer's Guide 5.1.5 lists these forms as equivalent.
test(shorthand_forms_all_equal) :-
    Forms = [ solvable(get_message(_N, _M), [], []),
              solvable(get_message(_N2, _M2), []),
              solvable(get_message(_N3, _M3)),
              get_message(_N4, _M4) ],
    maplist(solvable_normalize, Forms, [First|Rest]),
    forall(member(S, Rest), S =@= First).

test(normalize_keeps_params) :-
    solvable_normalize(solvable(last_message(_N), [type(data)], [write(true)]), S),
    solvable_type(S, data),
    solvable_permission(S, write(true)).

test(normalize_rejects_var, [fail]) :-
    solvable_normalize(_, _).
test(normalize_rejects_number, [fail]) :-
    solvable_normalize(42, _).

test(list_or_single) :-
    solvable_list(foo(_), [solvable(foo(_), [], [])]),
    solvable_list([foo(_), bar(_)], L), length(L, 2).

%  Defaults, Developer's Guide 5.1.3 and 5.1.4.
test(default_type_is_procedure) :-
    solvable_list(send(_,_), [S]), solvable_type(S, procedure).
test(default_utility_is_5) :-
    solvable_list(send(_,_), [S]), solvable_utility(S, 5).
test(default_permissions) :-
    solvable_list(send(_,_), [S]),
    solvable_permission(S, call(true)),
    solvable_permission(S, write(false)),
    solvable_permission(S, read(false)).

test(callback_read) :-
    solvable_normalize(solvable(send(_,_,_), [callback(send_mail)], []), S),
    solvable_callback(S, send_mail).
test(no_callback_for_data, [fail]) :-
    solvable_normalize(solvable(last(_), [type(data)], []), S),
    solvable_callback(S, _).

%  The mail agent's solvable list from Developer's Guide 5.1.1.
test(devguide_mail_agent_example) :-
    Spec = [ solvable(send(mail, _To, _Msg), [callback(send_mail)], []),
             solvable(last_message(_N), [type(data), single_value(true)], [write(true)]),
             solvable(get_message(_N2, _M2), [callback(get_mail)], []) ],
    solvable_list(Spec, [S1, S2, S3]),
    solvable_type(S1, procedure),
    solvable_type(S2, data),
    solvable_permission(S2, write(true)),
    solvable_param(S2, single_value(true)),
    solvable_callback(S3, get_mail).

:- end_tests(solvable).


:- begin_tests(solvable_matching).

%  Matching is unification against the goal template, and nothing else.
test(matches) :-
    solvable_list(solvable(send(mail, _To, _Msg), [callback(cb)], []), [S]),
    solvable_matches(send(mail, adam, hello), S).
test(no_match_functor, [fail]) :-
    solvable_list(send(mail, _, _), [S]),
    solvable_matches(deliver(mail, adam, hello), S).
test(no_match_constant, [fail]) :-
    solvable_list(send(mail, _, _), [S]),
    solvable_matches(send(fax, adam, hello), S).
test(no_match_arity, [fail]) :-
    solvable_list(send(mail, _, _), [S]),
    solvable_matches(send(mail, adam), S).

%  Permissions and parameters take no part in matching -- but call(false)
%  removes the solvable from consideration entirely (Developer's Guide 5.1.3).
test(call_false_blocks) :-
    solvable_normalize(solvable(send(mail,_,_), [], [call(false)]), S),
    \+ solvable_matches(send(mail, adam, hi), S).
test(utility_does_not_affect_matching) :-
    solvable_normalize(solvable(send(mail,_,_), [utility(0)], []), S),
    solvable_matches(send(mail, adam, hi), S).

test(matching_leaves_no_bindings) :-
    solvable_normalize(solvable(send(mail, To, _), [], []), S),
    solvable_matches(send(mail, adam, hi), S),
    var(To).

%  The event delivered to the provider is the unification result.
test(match_event) :-
    solvable_normalize(solvable(send(mail, _To, _Msg), [], []), S),
    solvable_match(send(mail, adam, hello), S, E),
    E == send(mail, adam, hello).
test(match_event_partial_goal) :-
    solvable_normalize(solvable(rating(_A, _R), [type(data)], []), S),
    solvable_match(rating(delta, _), S, E),
    E =@= rating(delta, _).

%  Optional typing, Developer's Guide 5.2.  Argspecs constrain matching.
test(argspec_accepts_conforming) :-
    solvable_normalize(
        solvable(square(_In, _Out),
                 [argspecs(in(number, true), out(number, true))], []), S),
    solvable_matches(square(4, _), S).
test(argspec_rejects_wrong_type) :-
    solvable_normalize(
        solvable(square(_In, _Out),
                 [argspecs(in(number, true), out(number, true))], []), S),
    \+ solvable_matches(square(foo, _), S).
test(argspec_rejects_missing_required) :-
    solvable_normalize(
        solvable(square(_In, _Out),
                 [argspecs(in(number, true), out(number, true))], []), S),
    \+ solvable_matches(square(_, _), S).
test(argspec_accepts_supertype) :-
    solvable_normalize(
        solvable(square(_In, _Out),
                 [argspecs(in(number, true), out(number, true))], []), S),
    solvable_matches(square(4.5, _), S).
test(argspec_out_must_be_var) :-
    solvable_normalize(
        solvable(square(_In, _Out),
                 [argspecs(in(number, true), out(number, true))], []), S),
    \+ solvable_matches(square(4, 16), S).
test(no_argspec_accepts_anything) :-
    solvable_list(square(_, _), [S]),
    solvable_matches(square(foo, bar), S).

:- end_tests(solvable_matching).
