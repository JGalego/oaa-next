/*  oaa-next -- ICL test suite
 *
 *  Behavioural tests for the reconstructed ICL layer.  Where a test asserts
 *  something the historical system did, the Developer's Guide section is
 *  cited.
 */

:- module(test_icl, []).

:- use_module('../../src/icl/icl_term').
:- use_module('../../src/icl/icl_type').

:- begin_tests(icl_parse).

test(atom)        :- icl_parse_term("foo", T), T == foo.
test(quoted_atom) :- icl_parse_term("'an atom'", T), T == 'an atom'.
test(integer)     :- icl_parse_term("42", T), T == 42.
test(negative)    :- icl_parse_term("-42", T), T == -42.
test(float)       :- icl_parse_term("3.5", T), T == 3.5.
test(float_exp)   :- icl_parse_term("1.0e-3", T), T =:= 0.001.
test(neg_float)   :- icl_parse_term("-1.5e3", T), T =:= -1500.0.
test(struct)      :- icl_parse_term("solve(a,b)", T), T == solve(a,b).
test(nested)      :- icl_parse_term("f(g(h(1)))", T), T == f(g(h(1))).
test(empty_list)  :- icl_parse_term("[]", T), T == [].
test(list)        :- icl_parse_term("[a,b,c]", T), T == [a,b,c].
test(partial)     :- icl_parse_term("[a|T]", T), T = [a|Tail], var(Tail).
test(string)      :- icl_parse_term("icldataq(\"body\")", T), T = icldataq(S), string(S).
test(curly)       :- icl_parse_term("{a}", T), T == {a}.
test(group)       :- icl_parse_term("(a)", T), T == a.
test(trailing_dot):- icl_parse_term("foo(a).", T), T == foo(a).
test(comment)     :- icl_parse_term("% note\nfoo(a)", T), T == foo(a).

%  Variable scope: same name is the same variable within a term, '_' never is.
test(var_sharing) :-
    icl_parse_term("p(X,X)", p(A,B)), A == B.
test(anon_distinct) :-
    icl_parse_term("p(_,_)", p(A,B)), A \== B.
test(bindings) :-
    icl_parse_term("p(X,Y)", _, Bs),
    msort(Bs, Sorted), Sorted = ['X'=_, 'Y'=_].

%  ICL is a restricted term language.  These are valid Prolog and must NOT
%  parse -- the historical grammars have the operator tokens commented out.
%  research/implementation-notes/icl.md section 1.
test(reject_arith,   [fail]) :- icl_parse_term("X is 1+2", _).
test(reject_clause,  [fail]) :- icl_parse_term("a :- b", _).
test(reject_operator,[fail]) :- icl_parse_term("1 + 2", _).
test(reject_equals,  [fail]) :- icl_parse_term("a = b", _).
test(reject_junk,    [fail]) :- icl_parse_term("foo(a) bar", _).
test(reject_unclosed,[fail]) :- icl_parse_term("foo(a", _).

%  A stream of period-terminated terms is the wire form.
test(term_sequence) :-
    icl_parse_terms("a. f(1). [x,y].", Ts),
    Ts == [a, f(1), [x,y]].
test(sequence_scopes_vars) :-
    icl_parse_terms("p(X). q(X).", [p(A), q(B)]),
    A \== B.

:- end_tests(icl_parse).


:- begin_tests(icl_write).

test(round_trip_atom)    :- rt(foo).
test(round_trip_quoted)  :- rt('has space').
test(round_trip_struct)  :- rt(solve(a, b)).
test(round_trip_list)    :- rt([a,b,c]).
test(round_trip_empty)   :- rt([]).
test(round_trip_nums)    :- rt(f(-2, 3.5, -1.5)).
test(round_trip_string)  :- rt(icldataq("body text")).
test(round_trip_curly)   :- rt({a}).

test(round_trip_var) :-
    rt(solve(a, _X)).
test(round_trip_var_sharing) :-
    rt(p(Shared, Shared)).
test(round_trip_partial_list) :-
    rt([a,b|_T]).

%  A partial list must not be silently closed by writing it.
test(partial_list_not_bound) :-
    T = [a,b|Tail],
    icl_term_string(T, _),
    var(Tail).

test(minimal_quoting) :-
    icl_term_string(foo, S), S == "foo".
test(quotes_when_needed) :-
    icl_term_string('has space', S), S == "'has space'".
test(forced_quoting) :-
    icl_term_string(foo, S, [quoted(forced)]), S == "'foo'".
test(no_quoting) :-
    icl_term_string('has space', S, [quoted(none)]), S == "has space".

%  Printed form is not canonical: several renderings denote the same term.
test(printed_form_not_canonical) :-
    icl_term_string(foo, A, [quoted(minimal)]),
    icl_term_string(foo, B, [quoted(forced)]),
    A \== B,
    icl_parse_term(A, T1), icl_parse_term(B, T2),
    icl_term_equal(T1, T2).

rt(Term) :-
    icl_term_string(Term, S),
    icl_parse_term(S, Back),
    (   icl_term_variant(Back, Term)
    ->  true
    ;   format(user_error, "round trip failed: ~q -> ~w -> ~q~n", [Term, S, Back]),
        fail
    ).

:- end_tests(icl_write).


:- begin_tests(icl_type).

test(of_integer) :- icl_type_of(3, integer).
test(of_float)   :- icl_type_of(3.5, float).
test(of_atom)    :- icl_type_of(foo, atom).
test(of_list)    :- icl_type_of([a], list).
test(of_empty)   :- icl_type_of([], list).
test(of_dataq1)  :- icl_type_of(icldataq("x"), icldataq/1).
test(of_dataq3)  :- icl_type_of(icldataq(a,b,c), icldataq/3).
test(of_xml)     :- icl_type_of(xml(s,d), xml/2).
test(of_mime)    :- icl_type_of(mime(t,d), mime/2).
test(of_compound):- icl_type_of(f(1,2), compound).
test(of_var, [fail]) :- icl_type_of(_, _).

test(sub_reflexive)  :- once(icl_subtype(integer, integer)).
test(sub_int_number) :- once(icl_subtype(integer, number)).
test(sub_transitive) :- once(icl_subtype(integer, atomic)).
test(sub_atom_string):- once(icl_subtype(atom, string)).

%  The hierarchy is not a tree: icldataq has two parents.
test(dataq_is_string)   :- once(icl_subtype(icldataq/1, string)).
test(dataq_is_compound) :- once(icl_subtype(icldataq/1, compound)).
test(dataq_is_atomic)   :- once(icl_subtype(icldataq/1, atomic)).

test(not_sub_list,   [fail]) :- icl_subtype(list, atomic).
test(not_sub_int_str,[fail]) :- icl_subtype(integer, string).

%  Developer's Guide 5.2: an argspec of `number` accepts an integer or float.
test(conforms_supertype) :- icl_conforms(3, number).
test(conforms_atomic)    :- icl_conforms(3, atomic).
test(conforms_exact)     :- icl_conforms(3, integer).
test(conforms_fails, [fail]) :- icl_conforms(3, atom).
test(conforms_var_spec)  :- icl_conforms(3, _AnyType).
test(conforms_var_value, [fail]) :- icl_conforms(_, integer).

%  Parametric types narrow on their bound arguments.
test(conforms_mime_exact) :- icl_conforms(mime('text/plain', b), mime('text/plain', _)).
test(conforms_mime_any)   :- icl_conforms(mime('text/plain', b), mime(_, _)).
test(conforms_mime_wrong, [fail]) :- icl_conforms(mime(other, b), mime('text/plain', _)).

test(argspec_in_required)       :- icl_conforms_argspec(3, in(number, true)).
test(argspec_in_missing, [fail]):- icl_conforms_argspec(_, in(number, true)).
test(argspec_in_optional)       :- icl_conforms_argspec(_, in(number, false)).
test(argspec_out)               :- icl_conforms_argspec(_, out(number, false)).
test(argspec_out_bound, [fail]) :- icl_conforms_argspec(3, out(number, false)).
test(argspec_inout_var)         :- icl_conforms_argspec(_, inout(number, false)).
test(argspec_inout_bound)       :- icl_conforms_argspec(3, inout(number, false)).

%  The hierarchy is writable at runtime, as the Facilitator's icl_type/2 data
%  solvable makes it.
test(runtime_extension, [cleanup(icl_type_remove(celsius, number))]) :-
    \+ icl_subtype(celsius, number),
    icl_type_add(celsius, number),
    once(icl_subtype(celsius, number)),
    once(icl_subtype(celsius, atomic)).

:- end_tests(icl_type).


:- begin_tests(icl_match).

%  Developer's Guide 5.1.2: matching is unification of the goal against the
%  solvable's goal template.  The match is exact.
test(matches_exact)      :- icl_matches(send(mail, adam, hi), send(mail, _To, _Msg)).
test(matches_no, [fail]) :- icl_matches(send(fax, adam, hi), send(mail, _To, _Msg)).
test(matches_arity, [fail]) :- icl_matches(send(mail, adam), send(mail, _, _)).

%  Testing a match must not bind anything: the Facilitator asks many
%  templates in turn and one candidate's bindings must not leak into the next.
test(matching_does_not_bind) :-
    Template = send(mail, To, _Msg),
    icl_matches(send(mail, adam, hi), Template),
    var(To).

%  The event delivered to the solver is the result of the unification.
test(match_yields_bound_event) :-
    icl_match(send(mail, adam, hi), send(mail, _To, _Msg), Bound),
    Bound == send(mail, adam, hi).

test(match_leaves_goal_free) :-
    Goal = send(mail, adam, Msg),
    icl_match(Goal, send(mail, _, _), _),
    var(Msg).

test(hash_variant_invariant) :-
    icl_term_hash(p(_X, _Y), H1),
    icl_term_hash(p(_A, _B), H2),
    H1 == H2.
test(hash_distinguishes) :-
    icl_term_hash(p(a), H1),
    icl_term_hash(p(b), H2),
    H1 \== H2.
test(hash_respects_sharing) :-
    icl_term_hash(p(X, X), H1),
    icl_term_hash(p(_, _), H2),
    H1 \== H2.

test(functor_atom)   :- icl_functor(foo, foo, 0).
test(functor_struct) :- icl_functor(send(a,b,c), send, 3).
test(functor_var, [fail]) :- icl_functor(_, _, _).

:- end_tests(icl_match).
