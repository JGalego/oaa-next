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
            icl_is_ground/1
          ]).

:- use_module(icl_parse).
:- use_module(icl_write).
:- reexport(icl_parse, [icl_parse_term/2, icl_parse_term/3, icl_parse_terms/2]).
:- reexport(icl_write, [icl_write/1, icl_write/2, icl_write_event/2,
                        icl_term_string/2, icl_term_string/3]).

/** <module> ICL term operations

The operations the rest of the system uses to compare and match ICL terms.

The one rule that matters most here: **identity is structural, never
textual**.  A term has several valid printed forms, differing in quoting, so
comparing or hashing rendered strings gives wrong answers.  Everything below
works on term structure.
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
%   True when Goal unifies with Template, **without binding either**.  This is
%   the test the Facilitator applies when selecting candidate solvers: it must
%   ask the question of many templates in turn without one candidate's
%   bindings leaking into the next.

icl_matches(Goal, Template) :-
    \+ \+ Goal = Template.

%!  icl_match(+Goal, +Template, -Bound) is semidet.
%
%   Unify a *fresh copy* of Template with a fresh copy of Goal, yielding the
%   result in Bound.  The event delivered to a solving agent is exactly this
%   unification, per Developer's Guide section 5.1.2, and copying is what
%   keeps repeated dispatch of one goal to several providers independent.

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
