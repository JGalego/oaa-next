/*  oaa-next -- Interagent Communication Language: parser
 *
 *  Provenance: RECONSTRUCTED.
 *  Derived from the OAA Developer's Guide v2.3.2, the OAA Agent Library
 *  Reference Manual, and the OAA 2.3.2 ICL grammars.  Written independently;
 *  see research/licensing.md.
 */

:- module(icl_parse,
          [ icl_parse_term/2,           % +Text, -Term
            icl_parse_term/3,           % +Text, -Term, -Bindings
            icl_parse_terms/2,          % +Text, -Terms
            icl_parse_tokens/3          % +Tokens, -Term, -Rest
          ]).

:- use_module(icl_lex).
:- use_module(icl_ops).

/** <module> ICL parser

Parses ICL into native SWI-Prolog terms, which is what supplies unification --
the basis of OAA capability matching -- for free:

    | ICL              | representation                  |
    |------------------|---------------------------------|
    | atom             | Prolog atom                     |
    | integer, float   | Prolog integer, float           |
    | variable         | Prolog variable                 |
    | list             | Prolog list                     |
    | structure        | Prolog compound                 |
    | double-quoted    | SWI string object               |
    | icldataq(...)    | compound with functor icldataq  |
    | (A, B)           | ','(A, B)                       |
    | A ; B            | ';'(A, B)                       |

ICL has operators, with the precedence order and left associativity that
icl_ops.pl records.  The set is smaller than Prolog's -- there is no `is`, no
comparison chain, no `-->` -- so this parser reads a language of its own
rather than deferring to a Prolog reader.

Comma binds more loosely than every operator, and appears only inside a group,
a list or an argument list.  A conjunction is therefore written `(a, b)`; a
bare `a, b` at top level is a syntax error, exactly as the grammars have it.

One departure from the C grammar, following the Java one: a minus sign is
lexed as an operator and combined with a following numeric literal by the
parser.  The C grammar instead folds an optional sign into its number tokens,
which makes `1-2` lex as two integers and fail to parse.  The Java reading is
the coherent one.
*/

%!  icl_parse_term(+Text, -Term) is semidet.
%
%   Parse Text as a single ICL term.  A trailing period is optional.

icl_parse_term(Text, Term) :-
    icl_parse_term(Text, Term, _Bindings).

%!  icl_parse_term(+Text, -Term, -Bindings) is semidet.
%
%   As icl_parse_term/2, also unifying Bindings with Name=Var pairs for the
%   named variables in Term.  Anonymous variables are fresh and never listed.

icl_parse_term(Text, Term, Bindings) :-
    text_tokens(Text, Tokens),
    once(( phrase(term(1200, Term0, [], Vs), Tokens, Rest),
           ( Rest == [] -> true ; Rest == [end] ) )),
    Term = Term0,
    bindings(Vs, Bindings).

%!  icl_parse_terms(+Text, -Terms) is semidet.
%
%   Parse a period-terminated sequence of ICL terms, the form in which events
%   arrive on a connection.  Each term has its own variable scope.

icl_parse_terms(Text, Terms) :-
    text_tokens(Text, Tokens),
    parse_seq(Tokens, Terms).

parse_seq([], []) :- !.
parse_seq(Tokens, [T|Ts]) :-
    once(( phrase(term(1200, T0, [], _), Tokens, Rest0),
           (   Rest0 = [end|Rest0Tail]
           ->  Rest = Rest0Tail
           ;   Rest0 == []
           ->  Rest = []
           ;   fail
           ) )),
    T = T0,
    parse_seq(Rest, Ts).

%!  icl_parse_tokens(+Tokens, -Term, -Rest) is semidet.

icl_parse_tokens(Tokens, Term, Rest) :-
    once(phrase(term(1200, Term, [], _), Tokens, Rest0)),
    ( Rest0 = [end|Rest1] -> Rest = Rest1 ; Rest = Rest0 ).

text_tokens(Text, Tokens) :-
    (   is_list(Text)
    ->  Codes = Text
    ;   text_to_string(Text, S),
        string_codes(S, Codes)
    ),
    icl_tokens(Codes, Tokens).

bindings([], []).
bindings([Name-Var|T], [Name=Var|T2]) :-
    bindings(T, T2).

% ------------------------------------------------------------------- grammar
%
%   Operator precedence parsing.  term(MaxPriority, -Term, +VarsIn, -VarsOut)
%   reads a primary and then as many infix operators as the priority ceiling
%   allows, threading the variable-name map so that repeated names within one
%   term denote one variable.

term(MaxP, T, V0, V) -->
    primary(LeftP, Left, V0, V1),
    infix_seq(MaxP, LeftP, Left, T, V1, V).

infix_seq(MaxP, LeftP, Left, T, V0, V) -->
    [op(Op)],
    { icl_op(Op, P, Type),
      P =< MaxP,
      operand_limits(Type, P, LeftMax, RightMax),
      LeftP =< LeftMax },
    %  An operator that fits the ceiling must be taken: precedence climbing
    %  has no reason to prefer a shorter parse, and leaving the choice open
    %  would make the parser nondeterministic on every operator it reads.
    !,
    term(RightMax, Right, V0, V1),
    { Combined =.. [Op, Left, Right] },
    infix_seq(MaxP, P, Combined, T, V1, V).
infix_seq(_MaxP, _LeftP, T, T, V, V) -->
    [].

%   yfx accepts an equal priority on the left and demands a lower one on the
%   right, which is what makes iteration left-associative.  xfy is the mirror,
%   and comma is the only one of those.

operand_limits(yfx, P, P, R) :- R is P - 1.
operand_limits(xfy, P, L, P) :- L is P - 1.
operand_limits(xfx, P, L, R) :- L is P - 1, R is P - 1.

% ------------------------------------------------------------------ primaries

primary(0, T, V0, V) -->
    [int(N)], !, { T = N, V = V0 }.
primary(0, T, V0, V) -->
    [float(N)], !, { T = N, V = V0 }.
primary(0, T, V0, V) -->
    [str(S)], !, { T = S, V = V0 }.

%   A sign directly in front of a numeric literal makes a negative literal,
%   as the Java grammar's unaryExpression rule does.
primary(0, T, V0, V) -->
    [op(-), int(N)], !, { T is -N, V = V0 }.
primary(0, T, V0, V) -->
    [op(-), float(N)], !, { T is -N, V = V0 }.
primary(0, T, V0, V) -->
    [op(+), int(N)], !, { T = N, V = V0 }.
primary(0, T, V0, V) -->
    [op(+), float(N)], !, { T = N, V = V0 }.

primary(0, T, V0, V) -->
    [atom(A), open_ct], !, arglist(Args, V0, V), { T =.. [A|Args] }.
primary(0, T, V0, V) -->
    [atom(A)], !, { T = A, V = V0 }.
primary(0, T, V0, V) -->
    [var(Name)], !, { var_for(Name, T, V0, V) }.

%   A group carries comma-separated members, so it parses at comma priority
%   and yields a conjunction.  Braces behave the same way, wrapped in {}/1.
primary(0, T, V0, V) -->
    open_paren, !,
    { icl_comma_priority(CommaP) },
    term(CommaP, T, V0, V),
    close_paren.
primary(0, T, V0, V) -->
    [punct(0'[)], !, list_body(T, V0, V).
primary(0, T, V0, V) -->
    [punct(0'{)], !, curly_body(T, V0, V).

%   A prefix operator applied to an expression.
primary(P, T, V0, V) -->
    [op(Op)],
    { icl_prefix_op(Op, P, fy) },
    term(P, Arg, V0, V),
    { T =.. [Op, Arg] }, !.

%   An operator atom standing alone, with nothing to apply it to.
primary(P, T, V0, V) -->
    [op(Op)], !,
    { T = Op, V = V0,
      ( icl_op(Op, P0, _) -> P = P0 ; P = 0 ) }.

open_paren  --> [open_ct], !.
open_paren  --> [punct(0'()].
close_paren --> [punct(0'))].

%   Argument lists and list elements sit below comma priority, so the commas
%   between them belong to the enclosing construct rather than to a term.

arglist([A|As], V0, V) -->
    term(1200, A, V0, V1),
    arglist_rest(As, V1, V).

arglist_rest(As, V0, V) -->
    [op(',')], !, arglist(As, V0, V).
arglist_rest([], V, V) -->
    close_paren.

list_body([], V, V) -->
    [punct(0'])], !.
list_body([H|T], V0, V) -->
    term(1200, H, V0, V1),
    list_rest(T, V1, V).

list_rest(T, V0, V) -->
    [op(',')], !, list_body2(T, V0, V).
list_rest(T, V0, V) -->
    [punct(0'|)], !, term(1200, T, V0, V), [punct(0'])].
list_rest([], V, V) -->
    [punct(0'])].

list_body2([H|T], V0, V) -->
    term(1200, H, V0, V1),
    list_rest(T, V1, V).

curly_body('{}', V, V) -->
    [punct(0'})], !.
curly_body('{}'(T), V0, V) -->
    { icl_comma_priority(CommaP) },
    term(CommaP, T, V0, V),
    [punct(0'})].

%   var_for(+Name, -Var, +VarsIn, -VarsOut).  '_' is always fresh and is never
%   recorded, so two anonymous variables never unify by name.

var_for('_', _Fresh, V, V) :- !.
var_for(Name, Var, V0, V) :-
    (   memberchk(Name-Existing, V0)
    ->  Var = Existing, V = V0
    ;   Var = _Fresh, V = [Name-Var|V0]
    ).
