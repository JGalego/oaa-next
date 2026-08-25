/*  oaa-next -- conformance against the historical record
 *
 *  These assert behaviours the original system is documented or observed to
 *  have, rather than behaviours this implementation happens to produce.  Each
 *  cites its source.
 *
 *  A number are transcriptions of SRI's own conformance tests, which ship in
 *  the recovered distribution under src/oaatest/ as XML files in a test
 *  language of their own ("OTML").  Those are the closest thing to an
 *  executable specification that survives, and they exercise the wire format
 *  directly -- which is how the arity of ev_data_updated was settled here.
 */

:- module(test_conformance, []).

:- use_module('../integration/community').
:- use_module('../../src/icl/icl_term').
:- use_module('../../src/icl/icl_type').
:- use_module('../../src/agents/oaa_solvable').

:- begin_tests(icl_conformance).

%   Developer's Guide 5.1.5 lists these as equivalent spellings of one
%   solvable.  Every library procedure taking a solvable list accepts any.
test(all_shorthand_forms_are_one_solvable) :-
    Forms = [ solvable(get_message(_A, _B), [], []),
              solvable(get_message(_C, _D), []),
              solvable(get_message(_E, _F)),
              get_message(_G, _H) ],
    maplist(solvable_normalize, Forms, [First|Rest]),
    forall(member(S, Rest), S =@= First).

%   Developer's Guide 4.3.6: a boolean parameter with value true may omit it.
test(boolean_shorthand_is_the_same_declaration) :-
    solvable_normalize(solvable(d(_), [type(data), single_value, persistent], []), A),
    solvable_normalize(solvable(d(_), [type(data), single_value(true),
                                       persistent(true)], []), B),
    solvable_param(A, single_value(X)), solvable_param(B, single_value(Y)),
    X == Y, X == true.

%   Developer's Guide 5.2: an argspec of number accepts an integer or a float,
%   because the type hierarchy's supertype relations are respected.
test(supertypes_are_respected_in_matchmaking) :-
    icl_conforms(3, number),
    icl_conforms(3.5, number),
    icl_conforms(3, atomic),
    \+ icl_conforms(foo, number).

%   research/implementation-notes/icl.md: the hierarchy is a lattice, not a
%   tree.  A single-parent representation gives wrong answers here.
test(icldataq_descends_from_two_parents) :-
    once(icl_subtype(icldataq/1, string)),
    once(icl_subtype(icldataq/1, compound)).

%   From SRI's oaatest corpus (test/data/vars.otml): variables may be named
%   with a leading underscore and are distinct from the anonymous variable.
test(underscore_names_are_ordinary_variables) :-
    icl_parse_term("lala(_1, _X, _1)", T),
    T = lala(A, B, C),
    var(A), var(B), var(C),
    A == C,
    A \== B.

%   From oaatest (samples/test2/employee_db): an event may be split across
%   lines wherever whitespace is allowed.
test(events_may_span_lines) :-
    icl_parse_term("oaa_Solve(\n  manager('Adam Cheyer', [], _),\n  [blocking(false)]\n  )", T),
    T = oaa_Solve(manager('Adam Cheyer', [], _), [blocking(false)]).

%   From oaatest (samples/test3/qambig.otml): floats appear in goals.
test(floats_in_goals) :-
    icl_parse_term("ev_solve(_, foo(3.0), _)", T),
    T = ev_solve(_, foo(F), _),
    float(F).

:- end_tests(icl_conformance).


:- begin_tests(wire_conformance,
               [ setup(( start_community(['/examples/multi-agent/data_agent.pl'], C),
                         nb_setval(cf, C) )),
                 cleanup(( nb_getval(cf, C), stop_community(C) )) ]).

lines(Lines) :-
    nb_getval(cf, C),
    run_program(C, '/examples/multi-agent/data_client.pl', Lines).

%   Transcribed from SRI's samples/test2/system/fac/data.otml.  Two facts are
%   added; a query returns both; removing one by exact value leaves the other;
%   removing by an unbound pattern takes the first match, and a further query
%   returns nothing.
test(data_lifecycle_matches_the_historical_test) :-
    lines(Lines),
    memberchk("added: 2", Lines),
    memberchk("after removing 1093: [foo(33)]", Lines),
    memberchk("after removing foo(_): []", Lines).

%   Same file: agent_host/3 is a solvable the facilitator answers.
test(facilitator_answers_agent_host) :-
    lines(Lines),
    memberchk("agent_host answered", Lines).

%   The reply to a data update carries six arguments, as the historical
%   parallel.otml expects: ev_data_updated(Id, Mode, Clause, ...).
test(data_update_reply_has_six_arguments) :-
    lines(Lines),
    memberchk("ev_data_updated arity: 6", Lines).

:- end_tests(wire_conformance).
