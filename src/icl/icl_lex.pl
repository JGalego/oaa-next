/*  oaa-next -- Interagent Communication Language: tokenizer
 *
 *  Provenance: RECONSTRUCTED.
 *  Behaviour derived from the OAA Developer's Guide v2.3.2 and from
 *  observation of the OAA 2.3.2 ICL grammars (ANTLR OaaPrologNetParse.g,
 *  PCCTS parser.g).  Written independently; see research/licensing.md.
 *
 *  ICL is a restricted term language, NOT full Prolog.  There is no operator
 *  table, no arithmetic, no clause syntax.  That restriction is enforced here
 *  and in icl_parse.pl, and is deliberate: a full Prolog reader would accept
 *  a strictly larger language than the historical system did.
 */

:- module(icl_lex,
          [ icl_tokens/2,               % +Codes, -Tokens
            icl_tokens/3                % +Codes, -Tokens, -Rest
          ]).

/** <module> ICL tokenizer

Token forms produced:

    punct(Char)     one of ( ) [ ] { } , | ! ;
    open_ct         an opening parenthesis with no preceding layout, i.e.
                    one that introduces an argument list
    atom(Atom)      unquoted or single-quoted atom
    var(Name)       variable name, as an atom; '_' is anonymous
    int(Integer)
    float(Float)
    str(String)     double-quoted text, as an SWI string object
    end             the clause terminator '.'

Whitespace and comments (% to end of line, and /* ... */) are skipped.
*/

%!  icl_tokens(+Codes, -Tokens) is semidet.
%
%   Tokenize a complete code list.  Fails if any input remains untokenized.

icl_tokens(Codes, Tokens) :-
    icl_tokens(Codes, Tokens, Rest),
    Rest == [].

%!  icl_tokens(+Codes, -Tokens, -Rest) is det.
%
%   Tokenize as much of Codes as forms valid tokens, leaving Rest.

icl_tokens(Codes, Tokens, Rest) :-
    phrase(tokens(Tokens), Codes, Rest).

tokens([T|Ts]) -->
    blanks(Sp),
    token(Sp, T),
    !,
    tokens(Ts).
tokens([]) -->
    blanks(_).

% ---------------------------------------------------------------- whitespace

%   blanks(-Seen) skips whitespace and comments, reporting whether any were
%   present.  The distinction matters for one token only: an opening
%   parenthesis that immediately follows a name introduces an argument list,
%   whereas one preceded by layout opens a grouped term.  Standard Prolog
%   readers make the same distinction.

blanks(true)  --> blank, !, blanks(_).
blanks(true)  --> comment, !, blanks(_).
blanks(false) --> [].

blank --> [C], { code_type(C, space) }.

comment --> "%", !, line_rest.
comment --> "/*", !, block_rest.

line_rest --> [0'\n], !.
line_rest --> [_], !, line_rest.
line_rest --> [].

block_rest --> "*/", !.
block_rest --> [_], !, block_rest.

% -------------------------------------------------------------------- tokens

token(_,  end)       --> ".", end_follows, !.
token(false, open_ct) --> "(", !.
token(_,  punct(C))  --> [C], { punct_code(C) }, !.
token(_,  str(S))    --> "\"", !, quoted_codes(0'", Cs), { string_codes(S, Cs) }.
token(_,  atom(A))   --> "'", !, quoted_codes(0'', Cs), { atom_codes(A, Cs) }.
token(_,  T)         --> number_token(T), !.
token(_,  var(V))    --> var_start(C), ident_rest(Cs), { atom_codes(V, [C|Cs]) }, !.
token(_,  atom(A))   --> lower(C), ident_rest(Cs), { atom_codes(A, [C|Cs]) }, !.
token(_,  atom(A))   --> symbol_chars(Cs), { Cs \== [], atom_codes(A, Cs) }.

%   A period terminates a term only when followed by whitespace, a comment or
%   end of input.  Otherwise it is part of a float or a symbolic atom.
end_follows, [C] --> [C], { code_type(C, space) }, !.
end_follows, [0'%] --> [0'%], !.
end_follows --> call(eos_).

eos_([], []).

punct_code(0'().
punct_code(0')).
punct_code(0'[).
punct_code(0']).
punct_code(0'{).
punct_code(0'}).
punct_code(0',).
punct_code(0'|).
punct_code(0'!).
punct_code(0';).

lower(C)     --> [C], { code_type(C, lower) }.
var_start(C) --> [C], { code_type(C, upper) ; C =:= 0'_ }.

ident_rest([C|Cs]) --> [C], { ident_code(C) }, !, ident_rest(Cs).
ident_rest([]) --> [].

ident_code(C) :- code_type(C, csym).

%   Symbolic atoms.  ICL has no operator table, so these are only ever read as
%   plain atoms -- which is what makes '=' or ':-' a parse error in term
%   position rather than an operator application.
symbol_chars([C|Cs]) --> [C], { symbol_code(C) }, !, symbol_chars(Cs).
symbol_chars([]) --> [].

symbol_code(C) :- memberchk(C, `+-*/\\^<>=~:.?@#&$`).

% ------------------------------------------------------------------- numbers

number_token(T) -->
    digits1(Ds),
    (   float_tail(Fs)
    ->  { append(Ds, Fs, Cs), number_codes(N, Cs), T = float(N) }
    ;   { number_codes(N, Ds), T = int(N) }
    ).

float_tail(Cs) -->
    ".", digit(D), digits(Ds),
    (   exponent(Es)
    ->  { append([0'., D|Ds], Es, Cs) }
    ;   { Cs = [0'., D|Ds] }
    ).
float_tail(Cs) -->
    exponent(Cs).

exponent([0'e|Cs]) -->
    ( "e" ; "E" ),
    (   sign(S)
    ->  { Cs = [S|Ds] }
    ;   { Cs = Ds }
    ),
    digit(D), digits(Ds0),
    { Ds = [D|Ds0] }.

sign(0'-) --> "-".
sign(0'+) --> "+".

digit(D) --> [D], { code_type(D, digit) }.

digits([D|Ds]) --> digit(D), !, digits(Ds).
digits([]) --> [].

digits1([D|Ds]) --> digit(D), digits(Ds).

% ------------------------------------------------------------ quoted content

%   quoted_codes(+Quote, -Codes) reads until the closing quote.  A doubled
%   quote character stands for itself, as in standard Prolog.

quoted_codes(Q, [Q|Cs]) --> [Q, Q], !, quoted_codes(Q, Cs).
quoted_codes(Q, Cs)     --> [Q], !, { Cs = [] }.
quoted_codes(Q, [C|Cs]) --> "\\", !, escape(C), quoted_codes(Q, Cs).
quoted_codes(Q, [C|Cs]) --> [C], quoted_codes(Q, Cs).

escape(0'\n) --> "n", !.
escape(0'\t) --> "t", !.
escape(0'\r) --> "r", !.
escape(0'\b) --> "b", !.
escape(0'\f) --> "f", !.
escape(0'\v) --> "v", !.
escape(0'\0) --> "0", !.
escape(0'\\) --> "\\", !.
escape(0'')  --> "'", !.
escape(0'")  --> "\"", !.
escape(C)    --> [C].
