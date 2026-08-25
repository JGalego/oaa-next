/*  oaa-next -- Interagent Communication Language: parser
 *
 *  Provenance: RECONSTRUCTED.
 *  Derived from the OAA Developer's Guide v2.3.2 and observation of the OAA
 *  2.3.2 ICL grammars.  Written independently; see research/licensing.md.
 */

:- module(icl_parse,
          [ icl_parse_term/2,           % +Text, -Term
            icl_parse_term/3,           % +Text, -Term, -Bindings
            icl_parse_terms/2,          % +Text, -Terms
            icl_parse_tokens/3          % +Tokens, -Term, -Rest
          ]).

:- use_module(icl_lex).

/** <module> ICL parser

Parses the restricted term language described in
research/implementation-notes/icl.md.  ICL terms are represented as native
SWI-Prolog terms, which supplies unification -- the basis of OAA
capability matching -- for free:

    | ICL              | representation                  |
    |------------------|---------------------------------|
    | atom             | Prolog atom                     |
    | integer, float   | Prolog integer, float           |
    | variable         | Prolog variable                 |
    | list             | Prolog list                     |
    | structure        | Prolog compound                 |
    | double-quoted    | SWI string object               |
    | icldataq(...)    | compound with functor icldataq  |

There is no operator table.  `X is 1+2` and `a :- b` are syntax errors in ICL,
as they were in the historical grammars, where the operator tokens sit
commented out.

Having no operators to disambiguate against leads to two departures from a
standard Prolog reader:

  * A minus sign followed by a numeric literal always denotes a negative
    number, whether or not layout separates them.  Standard Prolog would read
    `- 1` as a compound.  ICL has no `-` operator for it to be, so the
    ambiguity does not arise.
  * A term may be written parenthesised for grouping, which yields the inner
    term unchanged.
*/

%!  icl_parse_term(+Text, -Term) is semidet.
%
%   Parse Text as a single ICL term.  A trailing period is optional.  Fails if
%   Text is not a well-formed ICL term.

icl_parse_term(Text, Term) :-
    icl_parse_term(Text, Term, _Bindings).

%!  icl_parse_term(+Text, -Term, -Bindings) is semidet.
%
%   As icl_parse_term/2, and additionally unify Bindings with a list of
%   Name=Var pairs for the named variables occurring in Term.  Anonymous
%   variables are always fresh and never appear in Bindings.

icl_parse_term(Text, Term, Bindings) :-
    text_tokens(Text, Tokens),
    parse_one(Tokens, Term, Bindings).

parse_one(Tokens, Term, Bindings) :-
    phrase(term(Term, [], Vs), Tokens, Rest),
    ( Rest == [] -> true ; Rest == [end] ),
    bindings(Vs, Bindings).

%!  icl_parse_terms(+Text, -Terms) is semidet.
%
%   Parse a period-terminated sequence of ICL terms.  This is the form in
%   which events arrive on a connection: successive terms, each closed by a
%   period.  Every term has its own variable scope.

icl_parse_terms(Text, Terms) :-
    text_tokens(Text, Tokens),
    parse_seq(Tokens, Terms).

parse_seq([], []) :- !.
parse_seq(Tokens, [T|Ts]) :-
    phrase(term(T, [], _), Tokens, Rest0),
    (   Rest0 = [end|Rest]
    ->  true
    ;   Rest0 == []
    ->  Rest = []
    ;   fail
    ),
    parse_seq(Rest, Ts).

%!  icl_parse_tokens(+Tokens, -Term, -Rest) is semidet.
%
%   Parse one term from an already-tokenized list, returning the tokens that
%   follow it.  Any terminating period is consumed.

icl_parse_tokens(Tokens, Term, Rest) :-
    phrase(term(Term, [], _), Tokens, Rest0),
    ( Rest0 = [end|Rest] -> true ; Rest = Rest0 ).

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
%   term(-Term, +VarsIn, -VarsOut) threads the variable-name map so that two
%   occurrences of the same name within one term denote the same variable.

term(T, V0, V) -->
    [int(N)], !, { T = N, V = V0 }.
term(T, V0, V) -->
    [float(N)], !, { T = N, V = V0 }.
term(T, V0, V) -->
    [atom(-), int(N)], !, { T is -N, V = V0 }.
term(T, V0, V) -->
    [atom(-), float(N)], !, { T is -N, V = V0 }.
term(T, V0, V) -->
    [str(S)], !, { T = S, V = V0 }.
term(T, V0, V) -->
    [atom(A), open_ct], !, arglist(Args, V0, V), { T =.. [A|Args] }.
term(T, V0, V) -->
    [atom(A)], !, { T = A, V = V0 }.
term(T, V0, V) -->
    [var(Name)], !, { var_for(Name, T, V0, V) }.
term(T, V0, V) -->
    open_paren, !, term(T, V0, V), close_paren.
term(T, V0, V) -->
    [punct(0'[)], !, list_body(T, V0, V).
term(T, V0, V) -->
    [punct(0'{)], !, curly_body(T, V0, V).

open_paren  --> [open_ct], !.
open_paren  --> [punct(0'()].
close_paren --> [punct(0'))].

%   arglist//3 assumes the opening parenthesis has been consumed.

arglist([A|As], V0, V) -->
    term(A, V0, V1),
    arglist_rest(As, V1, V).

arglist_rest(As, V0, V) -->
    [punct(0',)], !, arglist(As, V0, V).
arglist_rest([], V, V) -->
    close_paren.

%   list_body//3 assumes '[' has been consumed.

list_body([], V, V) -->
    [punct(0'])], !.
list_body([H|T], V0, V) -->
    term(H, V0, V1),
    list_rest(T, V1, V).

list_rest(T, V0, V) -->
    [punct(0',)], !, list_body2(T, V0, V).
list_rest(T, V0, V) -->
    [punct(0'|)], !, term(T, V0, V1), { V = V1 }, [punct(0'])].
list_rest([], V, V) -->
    [punct(0'])].

list_body2([H|T], V0, V) -->
    term(H, V0, V1),
    list_rest(T, V1, V).

%   curly_body//3 assumes '{' has been consumed.  '{}' is the atom '{}';
%   '{T}' is the compound '{}'(T), as in standard Prolog.

curly_body('{}', V, V) -->
    [punct(0'})], !.
curly_body('{}'(T), V0, V) -->
    term(T, V0, V),
    [punct(0'})].

%   var_for(+Name, -Var, +VarsIn, -VarsOut).  '_' is always a fresh variable
%   and is not recorded, so that two anonymous variables never unify by name.

var_for('_', _Fresh, V, V) :- !.
var_for(Name, Var, V0, V) :-
    (   memberchk(Name-Existing, V0)
    ->  Var = Existing, V = V0
    ;   Var = _Fresh, V = [Name-Var|V0]
    ).
