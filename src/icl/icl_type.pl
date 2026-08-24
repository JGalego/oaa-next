/*  oaa-next -- Interagent Communication Language: type system
 *
 *  Provenance: RECONSTRUCTED.
 *  Hierarchy and matchmaking rules from the OAA Developer's Guide v2.3.2
 *  sections 4.3.4 and 5.2.  See research/implementation-notes/icl.md.
 */

:- module(icl_type,
          [ icl_type_of/2,              % +Value, -TypeKey
            icl_subtype/2,              % ?SubKey, ?SuperKey
            icl_type_key/2,             % ?TypeSpec, ?TypeKey
            icl_conforms/2,             % +Value, +TypeSpec
            icl_conforms_argspec/2,     % +Value, +ArgSpec
            icl_type_add/2,             % +SubKey, +SuperKey
            icl_type_remove/2,          % +SubKey, +SuperKey
            icl_type_edges/1            % -Edges
          ]).

/** <module> The ICL type hierarchy

    atomic
    |-- number
    |   |-- float
    |   +-- integer
    +-- string
        |-- atom
        |-- icldataq(_)
        +-- icldataq(_,_,_)

    compound
    |-- icldataq(_)          (also a subtype of string)
    |-- icldataq(_,_,_)      (also a subtype of string)
    +-- document
        |-- xml(XSDSpec, _Document)
        +-- mime(MimeType, _Document)

    list

Two properties of this hierarchy are easy to get wrong and are load-bearing:

  1. **It is not a tree.** `icldataq/1` and `icldataq/3` are subtypes of both
     `string` and `compound`.  A single-parent representation gives wrong
     matchmaking answers.

  2. **It is extensible at runtime.**  The historical Facilitator declares
     `icl_type(Type, SuperType)` as a *writable data solvable*, so the
     hierarchy can be added to while a community is running.  The edge
     relation here is therefore dynamic, not a static table.

Types are manipulated by *key*.  A key is either a plain atom (`integer`,
`atom`, `list`, ...) or Functor/Arity for the parametric types
(`icldataq/1`, `xml/2`, ...).  Keys let the hierarchy be stored and queried
without carrying the parameters around; conformance checks the parameters
separately.
*/

:- dynamic icl_type_edge/2.

%   Built-in edges.  These are seeded rather than compiled in so that they can
%   be extended, and in principle removed, at runtime.

builtin_edge(number,       atomic).
builtin_edge(string,       atomic).
builtin_edge(float,        number).
builtin_edge(integer,      number).
builtin_edge(atom,         string).
builtin_edge(icldataq/1,   string).
builtin_edge(icldataq/1,   compound).
builtin_edge(icldataq/3,   string).
builtin_edge(icldataq/3,   compound).
builtin_edge(document,     compound).
builtin_edge(xml/2,        document).
builtin_edge(xml/2,        compound).
builtin_edge(mime/2,       document).
builtin_edge(mime/2,       compound).

:- forall(builtin_edge(S, T), assertz(icl_type_edge(S, T))).

%!  icl_type_add(+SubKey, +SuperKey) is det.
%!  icl_type_remove(+SubKey, +SuperKey) is det.
%
%   Extend or retract the hierarchy at runtime.  This is what backs the
%   Facilitator's writable `icl_type/2` data solvable.

icl_type_add(Sub, Super) :-
    (   icl_type_edge(Sub, Super)
    ->  true
    ;   assertz(icl_type_edge(Sub, Super))
    ).

icl_type_remove(Sub, Super) :-
    retractall(icl_type_edge(Sub, Super)).

%!  icl_type_edges(-Edges) is det.
%
%   All current edges, as Sub-Super pairs.

icl_type_edges(Edges) :-
    findall(S-T, icl_type_edge(S, T), Edges).

%!  icl_type_key(?TypeSpec, ?TypeKey) is semidet.
%
%   Relate a type as written in a solvable declaration to its key.

icl_type_key(Spec, Key) :-
    nonvar(Spec), !,
    (   atom(Spec)
    ->  Key = Spec
    ;   compound(Spec)
    ->  functor(Spec, F, A), Key = F/A
    ;   fail
    ).
icl_type_key(Spec, Key) :-
    nonvar(Key),
    (   Key = F/A
    ->  functor(Spec, F, A)
    ;   Spec = Key
    ).

%!  icl_type_of(+Value, -TypeKey) is semidet.
%
%   The most specific type key of a bound Value.  Fails for an unbound
%   variable: an unbound argument has no type, which is why `argspecs` marks
%   optionality separately.

icl_type_of(V, _) :-
    var(V), !, fail.
icl_type_of(V, integer) :- integer(V), !.
icl_type_of(V, float)   :- float(V), !.
icl_type_of(V, list)    :- V == [], !.
icl_type_of(V, list)    :- V = [_|_], !.
icl_type_of(V, atom)    :-
    %  ICL's `atom` is the textual leaf -- the Developer's Guide describes its
    %  values as ordinary single-quoted strings.  A double-quoted literal,
    %  which this implementation carries as an SWI string object, is the same
    %  kind of thing and types the same way.
    ( atom(V) ; string(V) ), !.
icl_type_of(V, Key) :-
    compound(V),
    functor(V, F, A),
    (   parametric_type(F, A)
    ->  Key = F/A
    ;   Key = compound
    ).

parametric_type(icldataq, 1).
parametric_type(icldataq, 3).
parametric_type(xml, 2).
parametric_type(mime, 2).

%!  icl_subtype(?SubKey, ?SuperKey) is nondet.
%
%   True when SubKey is SuperKey or reaches it through the edge relation.
%   Reflexive and transitive.  Cycle-safe, because the hierarchy is writable
%   at runtime and nothing prevents a caller from creating one.

icl_subtype(K, K).
icl_subtype(Sub, Super) :-
    reaches(Sub, Super, [Sub]).

reaches(Sub, Super, Seen) :-
    icl_type_edge(Sub, Mid),
    \+ memberchk(Mid, Seen),
    (   Super = Mid
    ;   reaches(Mid, Super, [Mid|Seen])
    ).

%!  icl_conforms(+Value, +TypeSpec) is semidet.
%
%   True when Value satisfies TypeSpec.  An unbound TypeSpec places no
%   constraint, which is how the Developer's Guide defines a variable used in
%   a type position.
%
%   For parametric types the check has two parts: the type key must be a
%   subtype of the spec's key, and any *bound* arguments of the spec must
%   match the value.  That is what makes `mime('text/plain', _)` narrower than
%   `mime(_, _)`.

icl_conforms(_Value, Spec) :-
    var(Spec), !.
icl_conforms(Value, _Spec) :-
    var(Value), !, fail.
icl_conforms(Value, Spec) :-
    icl_type_key(Spec, SpecKey),
    icl_type_of(Value, ValueKey),
    once(icl_subtype(ValueKey, SpecKey)),
    (   compound(Spec)
    ->  subsumes_term(Spec, Value)
    ;   true
    ).

%!  icl_conforms_argspec(+Value, +ArgSpec) is semidet.
%
%   Check one goal argument against one `argspecs` entry.
%
%     * in(Type, Required)      -- fully instantiated, or a variable when
%                                  Required is false
%     * out(Type, Det)          -- a variable in a goal
%     * inout(Type, Det)        -- may be partially instantiated
%
%   Absent an `argspecs` declaration every argument is treated as
%   `inout(_, false)`; callers apply that default before reaching here.

icl_conforms_argspec(Value, in(Type, Required)) :- !,
    (   var(Value)
    ->  Required == false
    ;   icl_conforms(Value, Type)
    ).
icl_conforms_argspec(Value, out(_Type, _Det)) :- !,
    var(Value).
icl_conforms_argspec(Value, inout(Type, _Det)) :- !,
    (   var(Value)
    ->  true
    ;   icl_conforms(Value, Type)
    ).
icl_conforms_argspec(Value, Spec) :-
    %  A bare type in an argument position behaves as inout.
    icl_conforms_argspec(Value, inout(Spec, false)).
