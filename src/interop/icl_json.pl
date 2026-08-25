/*  oaa-next -- interoperability: ICL and JSON
 *
 *  Provenance: INTEROPERABILITY ADAPTER.
 *  Not part of OAA.  ICL is the architecture; this is a boundary layer for
 *  reaching systems that speak JSON.
 */

:- module(icl_json,
          [ icl_to_json/2,              % +Term, -Json
            json_to_icl/2,              % +Json, -Term
            icl_to_plain_json/2,        % +Term, -Json
            plain_json_to_icl/2,        % +Json, -Term
            solvable_to_schema/2        % +Solvable, -Schema
          ]).

:- use_module('../icl/icl_term').
:- use_module('../agents/oaa_solvable').

/** <module> Two mappings, for two different jobs

**Tagged** (`icl_to_json/2`, `json_to_icl/2`) is lossless.  Every ICL term
survives a round trip, variables and functors included, because each is
written with an explicit marker:

    42                  ->  42
    "text"              ->  "text"
    foo                 ->  {"$atom": "foo"}
    Var                 ->  {"$var": "_G1"}
    [a, b]              ->  [{"$atom":"a"}, {"$atom":"b"}]
    f(a, 1)             ->  {"$functor": "f", "$args": [{"$atom":"a"}, 1]}

Use it when the other side is another OAA installation, or a transport that
must not alter what it carries.

**Plain** (`icl_to_plain_json/2`, `plain_json_to_icl/2`) is natural JSON that
a tool consumer can read without knowing anything about ICL.  Atoms become
strings, compounds become objects keyed by functor.  It is lossy: an atom and
a string are the same thing coming back, and a variable becomes null.  Use it
at a boundary where the point is to be understood rather than to be exact.

Neither is a replacement for ICL.  A bridge that carried ICL as an opaque
string would give up the property the Developer's Guide names as the reason
for expressing request content in ICL at all -- that the Facilitator can see
into a request and decompose it.  These mappings exist so that a system
outside the community can take part, not so that the community can stop
speaking its own language.
*/

% ----------------------------------------------------------------- tagged

icl_to_json(T, J) :-
    var(T), !,
    copy_term(T, C),
    term_to_atom(C, A),
    J = json{'$var': A}.
icl_to_json(T, T) :- integer(T), !.
icl_to_json(T, T) :- float(T), !.
icl_to_json(T, T) :- string(T), !.
%   SWI-Prolog's empty list is neither an atom nor a compound, so it needs a
%   tag of its own or it comes back as the atom '[]', which is a different
%   term.
icl_to_json([], json{'$nil': true}) :- !.
icl_to_json(T, J) :-
    is_list(T), !,
    maplist(icl_to_json, T, J).
icl_to_json(T, json{'$atom': S}) :-
    atom(T), !,
    atom_string(T, S).
icl_to_json(T, json{'$functor': F, '$args': Args}) :-
    compound(T),
    T =.. [Name|As],
    atom_string(Name, F),
    maplist(icl_to_json, As, Args).

json_to_icl(J, T) :-
    is_dict(J), get_dict('$var', J, _), !,
    T = _Fresh.
json_to_icl(J, T) :-
    is_dict(J), get_dict('$nil', J, _), !,
    T = [].
json_to_icl(J, T) :-
    is_dict(J), get_dict('$atom', J, S), !,
    atom_string(T, S).
json_to_icl(J, T) :-
    is_dict(J), get_dict('$functor', J, F), get_dict('$args', J, Args), !,
    maplist(json_to_icl, Args, As),
    atom_string(Name, F),
    T =.. [Name|As].
json_to_icl(J, T) :-
    is_list(J), !,
    maplist(json_to_icl, J, T).
json_to_icl(J, J).

% ------------------------------------------------------------------ plain

icl_to_plain_json(T, null) :- var(T), !.
icl_to_plain_json(T, T) :- number(T), !.
icl_to_plain_json(T, T) :- string(T), !.
icl_to_plain_json([], []) :- !.
icl_to_plain_json(T, J) :- is_list(T), !, maplist(icl_to_plain_json, T, J).
icl_to_plain_json(T, S) :- atom(T), !, atom_string(T, S).
icl_to_plain_json(T, Json) :-
    compound(T),
    T =.. [Name|Args],
    maplist(icl_to_plain_json, Args, Js),
    %  Dict keys must be atoms; the functor already is one.
    dict_pairs(Json, json, [Name-Js]).

plain_json_to_icl(null, _Fresh) :- !.
plain_json_to_icl(J, J) :- number(J), !.
plain_json_to_icl(J, A) :- string(J), !, atom_string(A, J).
plain_json_to_icl(J, T) :- is_list(J), !, maplist(plain_json_to_icl, J, T).
plain_json_to_icl(J, T) :-
    is_dict(J), !,
    dict_pairs(J, _, [Key-Args]),
    ( is_list(Args) -> As = Args ; As = [Args] ),
    maplist(plain_json_to_icl, As, Ts),
    atom_string(Name, Key),
    T =.. [Name|Ts].
plain_json_to_icl(J, J).

% ------------------------------------------------------------- tool schema

%!  solvable_to_schema(+Solvable, -Schema) is det.
%
%   Describe a solvable as a JSON Schema object, so that a tool consumer can
%   call it.  Argument names come from `argnames` where the declaration has
%   one -- the parameter the Developer's Guide says exists purely for
%   documentation and display, and which turns out to be exactly what a tool
%   schema needs.  Types come from `argspecs` where present.

solvable_to_schema(Solvable, Schema) :-
    Solvable = solvable(Goal, _, _),
    Goal =.. [Name|Args],
    length(Args, Arity),
    arg_names(Solvable, Arity, Names),
    arg_types(Solvable, Arity, Types),
    findall(Key-Prop,
            ( nth1(I, Names, N),
              atom_string(Key, N),
              nth1(I, Types, Ty),
              json_type(Ty, Prop) ),
            Pairs),
    dict_pairs(Props, json, Pairs),
    required_names(Solvable, Names, Required),
    atom_string(Name, NameStr),
    Schema = json{ name: NameStr,
                   description: NameStr,
                   inputSchema: json{ type: "object",
                                      properties: Props,
                                      required: Required } }.

arg_names(Solvable, Arity, Names) :-
    (   solvable_named_args(Solvable, Given),
        length(Given, Arity)
    ->  Names = Given
    ;   numlist(1, Arity, Is),
        findall(N, ( member(I, Is), format(atom(N), "arg~w", [I]) ), Names)
    ).

solvable_named_args(solvable(_, Params, _), Names) :-
    member(P, Params),
    compound(P),
    functor(P, argnames, _),
    P =.. [argnames|Names0],
    maplist([A, S]>>atom_string(A, S), Names0, Names).

arg_types(Solvable, Arity, Types) :-
    (   solvable_arg_specs(Solvable, Specs),
        length(Specs, Arity)
    ->  Types = Specs
    ;   length(Types, Arity),
        maplist(=(any), Types)
    ).

solvable_arg_specs(solvable(_, Params, _), Specs) :-
    member(P, Params),
    compound(P),
    functor(P, argspecs, _),
    P =.. [argspecs|Specs].

json_type(in(Type, _), Prop) :- !, json_type(Type, Prop).
json_type(inout(Type, _), Prop) :- !, json_type(Type, Prop).
json_type(out(Type, _), Prop) :- !, json_type(Type, Prop).
json_type(integer, json{type: "integer"}) :- !.
json_type(float, json{type: "number"}) :- !.
json_type(number, json{type: "number"}) :- !.
json_type(string, json{type: "string"}) :- !.
json_type(atom, json{type: "string"}) :- !.
json_type(list, json{type: "array"}) :- !.
json_type(_, json{}).

%   Only `in` arguments marked required are required of a caller; an `out`
%   argument is what the caller is asking for.

required_names(Solvable, Names, Required) :-
    (   solvable_arg_specs(Solvable, Specs)
    ->  findall(N,
                ( nth1(I, Specs, in(_, true)), nth1(I, Names, N) ),
                Required)
    ;   Required = []
    ).
