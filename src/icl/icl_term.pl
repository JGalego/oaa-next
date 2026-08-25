/*  oaa-next -- Interagent Communication Language: terms
 *
 *  Provenance: RECONSTRUCTED.  See research/implementation-notes/icl.md.
 */

:- module(icl_term,
          [ icl_parse_term/2,
            icl_parse_term/3,
            icl_parse_terms/2,
            icl_write/1,
            icl_write/2,
            icl_write_event/2,
            icl_term_string/2,
            icl_term_string/3,

            icl_term_equal/2,           % +A, +B
            icl_term_variant/2,         % +A, +B
            icl_term_hash/2,            % +Term, -Hash
            icl_matches/2,              % +Goal, +Template
            icl_match/3,                % +Goal, +Template, -Bound
            icl_functor/3,              % +Term, -Name, -Arity
            icl_is_var/1,
            icl_is_ground/1,

            icl_disassemble_goal/4,     % +Full, ?Address, ?Goal, ?Params
            icl_assemble_goal/4         % ?Address, ?Goal, ?Params, -Full
          ]).

:- use_module(icl_parse).
:- use_module(icl_write).
:- reexport(icl_parse, [icl_parse_term/2, icl_parse_term/3, icl_parse_terms/2]).
:- reexport(icl_write, [icl_write/1, icl_write/2, icl_write_event/2,
                        icl_term_string/2, icl_term_string/3]).

/** <module> ICL term operations

The operations the rest of the system uses to compare and match ICL terms.

Identity here is structural.  A term has several valid printed forms,
differing in quoting, so comparing or hashing rendered strings gives wrong
answers.  Everything below works on term structure.
*/

%!  icl_term_equal(+A, +B) is semidet.
%
%   Structural identity.  Two distinct variables are not equal; the same
%   variable is equal to itself.

icl_term_equal(A, B) :-
    A == B.

%!  icl_term_variant(+A, +B) is semidet.
%
%   True when A and B are the same term up to a consistent renaming of
%   variables.  This is the right comparison for "is this the same goal",
%   where variable identity is an artefact of parsing rather than meaning.

icl_term_variant(A, B) :-
    A =@= B.

%!  icl_term_hash(+Term, -Hash) is det.
%
%   A hash that is stable across variable renaming and independent of printed
%   form, so that variant terms hash alike.

icl_term_hash(Term, Hash) :-
    variant_sha1(Term, Hash).

%!  icl_matches(+Goal, +Template) is semidet.
%
%   True when Goal unifies with Template, leaving both unbound.  The
%   Facilitator applies this test when selecting candidate solvers: it asks
%   the question of many templates in turn, and one candidate's bindings must
%   not leak into the next.

icl_matches(Goal, Template) :-
    \+ \+ Goal = Template.

%!  icl_match(+Goal, +Template, -Bound) is semidet.
%
%   Unify a fresh copy of Template with a fresh copy of Goal, yielding the
%   result in Bound.  Developer's Guide 5.1.2 defines the event delivered to a
%   solving agent as this unification; copying keeps repeated dispatch of one
%   goal to several providers independent.

icl_match(Goal, Template, Bound) :-
    copy_term(Goal-Template, G-T),
    G = T,
    Bound = G.

%!  icl_functor(+Term, -Name, -Arity) is semidet.
%
%   Name and arity of an ICL term.  Atoms have arity 0.  Fails for variables
%   and for numbers, which have no functor in the sense solvables use.

icl_functor(T, _, _) :-
    var(T), !, fail.
icl_functor(T, T, 0) :-
    atom(T), !.
icl_functor(T, Name, Arity) :-
    compound(T),
    functor(T, Name, Arity).

icl_is_var(T) :- var(T).

icl_is_ground(T) :- ground(T).

%!  icl_disassemble_goal(+Full, ?Address, ?Goal, ?Params) is det.
%
%   Split an ICL goal into its three parts.  The OAA Agent Library Reference
%   Manual gives the top-level structure of a goal as
%
%       Address:Goal::Params
%
%   with address and parameters both optional, so that every goal implicitly
%   carries all three components.  A missing parameter list reads as `[]` and
%   a missing address as `unknown`, again following the Reference Manual.
%
%   `:` and `::` share a priority and associate to the left, so the written
%   form parses as `::(:(Address, Goal), Params)`.

icl_disassemble_goal(Full, Address, Goal, Params) :-
    (   nonvar(Full), Full = ::(Left, P)
    ->  Params = P, Rest = Left
    ;   Params = [], Rest = Full
    ),
    (   nonvar(Rest), Rest = :(A, G)
    ->  Address = A, Goal = G
    ;   Address = unknown, Goal = Rest
    ).

%!  icl_assemble_goal(?Address, ?Goal, ?Params, -Full) is det.
%
%   The inverse.  An address of `unknown` and an empty parameter list are
%   both left out, so a goal that carries neither round-trips unchanged.

icl_assemble_goal(Address, Goal, Params, Full) :-
    (   Address == unknown
    ->  Base = Goal
    ;   Base = :(Address, Goal)
    ),
    (   Params == []
    ->  Full = Base
    ;   Full = ::(Base, Params)
    ).
