/*  oaa-next -- ICL operator table
 *
 *  Provenance: RECONSTRUCTED.
 *  Read off the operator-precedence chains in the OAA 2.3.2 ICL grammars --
 *  OaaPrologNetParse.g (ANTLR, Java library) and parser.g (PCCTS, C library),
 *  which define the same chain in the same order.
 */

:- module(icl_ops,
          [ icl_op/3,                   % ?Name, ?Priority, ?Type
            icl_prefix_op/3,            % ?Name, ?Priority, ?Type
            icl_operator_atom/1,        % ?Atom
            icl_comma_priority/1        % -Priority
          ]).

/** <module> ICL operators

Both shipped grammars build the same chain of expression rules, each level
iterating `(OP arg)*` over the level below it, so every infix operator is
left-associative:

    structure           : semiExpression      ((TURNSTILE) ...)*     :-
    semiExpression      : backslashExpression ((SEMI) ...)*          ;
    backslashExpression : equalsExpression    ((BACKSLASH) ...)*     \
    equalsExpression    : colonExpression     ((EQUAL) ...)*         =
    colonExpression     : plusMinusExpression ((COLON|DBL_COLON) ..)* : ::
    plusMinusExpression : multiplicative      ((PLUS|MINUS) ...)*    + -
    multiplicative      : unaryExpression     ((STAR|DIV) ...)*      * /

Priorities below are assigned to reproduce that order; the absolute numbers
carry no historical meaning, only their ranking does.

Comma sits outside the chain.  It appears only in `commaSeparatedStructs`,
which the group, list and argument-list rules use, and whose members are whole
`structure`s.  Comma therefore binds more loosely than every operator above,
and a conjunction has to be written inside a group: `(a, b)`, never a bare
`a, b`.  Comma is right-associative, following Prolog.

`Address:Goal::Params` is the top-level shape of an ICL goal, per the OAA
Agent Library Reference Manual's description of oaa_DisassembleGoal: address
and parameters are both optional, and every goal implicitly has all three
parts.  That shape is why `:` and `::` are in the table at all.
*/

%!  icl_op(?Name, ?Priority, ?Type) is nondet.
%
%   Infix operators.  Higher priority binds more loosely.  All are `yfx`:
%   left-associative, as the iterating grammar rules make them.

icl_op(',',  1300, xfy).        % group, list and argument separator
icl_op(:-,   1200, yfx).
icl_op(;,    1100, yfx).
icl_op(\,    1050, yfx).
icl_op(=,     700, yfx).
icl_op(::,    600, yfx).
icl_op(:,     600, yfx).
icl_op(+,     500, yfx).
icl_op(-,     500, yfx).
icl_op(*,     400, yfx).
icl_op(/,     400, yfx).

%!  icl_prefix_op(?Name, ?Priority, ?Type) is nondet.
%
%   The unary rule admits a signed number literal and a signed expression.

icl_prefix_op(+, 200, fy).
icl_prefix_op(-, 200, fy).

%!  icl_operator_atom(?Atom) is nondet.
%
%   Every atom the tokenizer should hand back as an operator rather than as a
%   plain symbolic atom.

icl_operator_atom(A) :- icl_op(A, _, _), A \== ','.
icl_operator_atom(A) :- icl_prefix_op(A, _, _).

icl_comma_priority(P) :- icl_op(',', P, _).
