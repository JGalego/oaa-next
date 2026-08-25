/*  oaa-next -- Interagent Communication Language: writer
 *
 *  Provenance: RECONSTRUCTED.
 *  See research/implementation-notes/icl.md.
 */

:- module(icl_write,
          [ icl_write/1,                % +Term
            icl_write/2,                % +Stream, +Term
            icl_write_event/2,          % +Stream, +Term
            icl_term_string/2,          % +Term, -String
            icl_term_string/3,          % +Term, -String, +Options
            icl_atom_quoted/3           % +Atom, -String, +Mode
          ]).

:- use_module(icl_ops).

/** <module> ICL writer

Renders ICL terms in a form the ICL parser reads back.

The same term has several valid printed forms, differing in how atoms are
quoted.  The historical Java library arrived at this late and made the
distinction explicit with separate minimally-quoted, forced-quoted and
unquoted renderings; those modes are offered here.  ICL term equality and
hashing therefore work on structure and never on printed text -- see
icl_term.pl.

Options accepted by icl_term_string/3:

    quoted(Mode)   one of `minimal` (default), `forced`, `none`

Variables are rendered as `_G`N, numbered per term, so that a term containing
the same variable twice reads back with that sharing intact.
*/

%!  icl_write(+Term) is det.
%!  icl_write(+Stream, +Term) is det.
%
%   Write Term in minimally-quoted ICL syntax, without a terminating period.

icl_write(Term) :-
    icl_write(current_output, Term).

icl_write(Stream, Term) :-
    icl_term_string(Term, S),
    write(Stream, S).

%!  icl_write_event(+Stream, +Term) is det.
%
%   Write Term followed by the period that frames it on a connection, and
%   flush.  This is the wire form: a stream of period-terminated terms.

icl_write_event(Stream, Term) :-
    icl_term_string(Term, S),
    format(Stream, "~w.~n", [S]),
    flush_output(Stream).

%!  icl_term_string(+Term, -String) is det.
%!  icl_term_string(+Term, -String, +Options) is det.

icl_term_string(Term, String) :-
    icl_term_string(Term, String, []).

icl_term_string(Term, String, Options) :-
    option_quoted(Options, Mode),
    State = state(0, []),
    with_output_to(string(String), emit(Term, Mode, State)).

option_quoted(Options, Mode) :-
    (   memberchk(quoted(M), Options)
    ->  Mode = M
    ;   Mode = minimal
    ).

% ---------------------------------------------------------------- emit terms
%
%   emit(+Term, +MaxPriority, +Mode, +State) renders Term, wrapping it in
%   parentheses when its own priority exceeds what the context allows.  The
%   top level allows 1200, so a conjunction -- comma, at 1300 -- always comes
%   out parenthesised, which is right: a bare `a, b` is not a readable ICL
%   term.

emit(T, Mode, State) :-
    emit(T, 1200, Mode, State).

emit(T, _MaxP, _Mode, State) :-
    var(T), !,
    var_name(T, State, Name),
    write(Name).
emit(T, _MaxP, _Mode, _State) :-
    integer(T), !,
    write(T).
emit(T, _MaxP, _Mode, _State) :-
    float(T), !,
    write(T).
emit(T, _MaxP, _Mode, _State) :-
    string(T), !,
    emit_quoted(T, 0'").
emit(T, _MaxP, Mode, _State) :-
    atom(T), T \== [], !,
    icl_atom_quoted(T, S, Mode),
    write(S).
emit([], _MaxP, _Mode, _State) :- !,
    write('[]').
emit([H|T], _MaxP, Mode, State) :- !,
    write('['),
    emit(H, 1200, Mode, State),
    emit_tail(T, Mode, State),
    write(']').
emit({X}, _MaxP, Mode, State) :- !,
    write('{'),
    icl_comma_priority(CommaP),
    emit(X, CommaP, Mode, State),
    write('}').

%   Infix operators.
emit(T, MaxP, Mode, State) :-
    compound(T), functor(T, Op, 2),
    icl_op(Op, P, Type), !,
    operand_limits(Type, P, LeftMax, RightMax),
    arg(1, T, Left), arg(2, T, Right),
    ( P > MaxP -> write('(') ; true ),
    emit(Left, LeftMax, Mode, State),
    emit_operator(Op, Mode),
    emit(Right, RightMax, Mode, State),
    ( P > MaxP -> write(')') ; true ).

%   Prefix operators.
emit(T, MaxP, Mode, State) :-
    compound(T), functor(T, Op, 1),
    icl_prefix_op(Op, P, fy), !,
    arg(1, T, Arg),
    ( P > MaxP -> write('(') ; true ),
    icl_atom_quoted(Op, S, Mode), write(S), write(' '),
    emit(Arg, P, Mode, State),
    ( P > MaxP -> write(')') ; true ).

emit(T, _MaxP, Mode, State) :-
    compound(T), !,
    T =.. [F|Args],
    icl_atom_quoted(F, S, Mode),
    write(S), write('('),
    emit_args(Args, Mode, State),
    write(')').

%   The comma separator is written tight; every other operator is spaced, so
%   that a symbolic atom beside an operator cannot run into it and re-lex as
%   one longer symbol.

emit_operator(',', _Mode) :- !,
    write(',').
emit_operator(Op, Mode) :-
    icl_atom_quoted(Op, S, Mode),
    write(' '), write(S), write(' ').

operand_limits(yfx, P, P, R) :- R is P - 1.
operand_limits(xfy, P, L, P) :- L is P - 1.
operand_limits(xfx, P, L, R) :- L is P - 1, R is P - 1.

emit_args([A], Mode, State) :- !,
    emit(A, 1200, Mode, State).
emit_args([A|As], Mode, State) :-
    emit(A, 1200, Mode, State),
    write(','),
    emit_args(As, Mode, State).

emit_tail(T, Mode, State) :-
    var(T), !,
    write('|'),
    emit(T, 1200, Mode, State).
emit_tail([], _Mode, _State) :- !.
emit_tail([H|T], Mode, State) :- !,
    write(','),
    emit(H, 1200, Mode, State),
    emit_tail(T, Mode, State).
emit_tail(T, Mode, State) :-
    write('|'),
    emit(T, 1200, Mode, State).

% ------------------------------------------------------------ variable names
%
%   Variables are numbered on first sight and remembered for the rest of the
%   term, so that sharing survives a write/parse round trip.

var_name(Var, State, Name) :-
    State = state(N, Seen),
    (   lookup_var(Seen, Var, Name0)
    ->  Name = Name0
    ;   N1 is N + 1,
        atom_concat('_G', N1, Name),
        setarg(1, State, N1),
        setarg(2, State, [Var-Name|Seen])
    ).

lookup_var([V-N|T], Var, Name) :-
    (   V == Var
    ->  Name = N
    ;   lookup_var(T, Var, Name)
    ).

% ---------------------------------------------------------------- atom quoting

%!  icl_atom_quoted(+Atom, -String, +Mode) is det.
%
%   Render Atom according to Mode:
%
%     * `minimal` -- quote only when the unquoted form would not read back
%       as the same atom.
%     * `forced`  -- always quote.
%     * `none`    -- never quote.  The result may not be readable; this mode
%       exists for display and for building identifiers, matching the
%       historical library's unquoted rendering.

icl_atom_quoted(Atom, String, none) :- !,
    atom_string(Atom, String).
icl_atom_quoted(Atom, String, forced) :- !,
    with_output_to(string(String), emit_quoted(Atom, 0'')).
icl_atom_quoted(Atom, String, _Minimal) :-
    (   atom_needs_no_quotes(Atom)
    ->  atom_string(Atom, String)
    ;   with_output_to(string(String), emit_quoted(Atom, 0''))
    ).

atom_needs_no_quotes(Atom) :-
    atom_codes(Atom, Codes),
    Codes \== [],
    (   solo_atom(Codes)
    ->  true
    ;   Codes = [C|Cs],
        code_type(C, lower),
        forall(member(X, Cs), code_type(X, csym))
    ->  true
    ;   forall(member(X, Codes), symbol_code(X))
    ).

solo_atom(`[]`).
solo_atom(`{}`).
solo_atom(`!`).
solo_atom(`;`).

symbol_code(C) :- memberchk(C, `+-*/\\^<>=~:.?@#&$`).

%   emit_quoted(+Text, +Quote) writes Text between Quote characters, escaping
%   the quote itself, backslashes and the control characters that would
%   otherwise not survive a round trip.

emit_quoted(Text, Quote) :-
    atom_codes(Text, Codes),
    put_code(Quote),
    forall(member(C, Codes), emit_quoted_code(C, Quote)),
    put_code(Quote).

emit_quoted_code(C, Quote) :-
    C == Quote, !,
    put_code(0'\\), put_code(C).
emit_quoted_code(0'\\, _) :- !,
    put_code(0'\\), put_code(0'\\).
emit_quoted_code(C, _) :-
    escape_code(C, E), !,
    put_code(0'\\), put_code(E).
emit_quoted_code(C, _) :-
    put_code(C).

escape_code(0'\n, 0'n).
escape_code(0'\t, 0't).
escape_code(0'\r, 0'r).
escape_code(0'\b, 0'b).
escape_code(0'\f, 0'f).
escape_code(0'\v, 0'v).
