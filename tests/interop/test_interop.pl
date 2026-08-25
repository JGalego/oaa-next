/*  oaa-next -- interoperability adapters
 *
 *  These are edge translations.  The tests check that the edge is faithful in
 *  both directions and, where it cannot be, that what is lost is lost
 *  deliberately.
 */

:- module(test_interop, []).

:- use_module('../../src/interop/icl_json').
:- use_module('../../src/interop/mcp_server').
:- use_module('../../src/interop/a2a_bridge').
:- use_module('../../src/icl/icl_term').
:- use_module('../../src/agents/oaa_solvable').

:- begin_tests(icl_json_tagged).

rt(Text) :-
    icl_parse_term(Text, T),
    icl_to_json(T, J),
    json_to_icl(J, Back),
    (   Back =@= T
    ->  true
    ;   format(user_error, "~w: ~q -> ~q~n", [Text, T, Back]), fail
    ).

%   The tagged mapping is lossless, variables and functors included.
test(atom)        :- rt("foo").
test(quoted_atom) :- rt("'has space'").
test(integer)     :- rt("42").
test(negative)    :- rt("-7").
test(float)       :- rt("3.5").
test(string)      :- rt("icldataq(\"body\")").
test(empty_list)  :- rt("[]").
test(list)        :- rt("[a, b, c]").
test(structure)   :- rt("send(mail, adam, hello)").
test(nested)      :- rt("f(g(h(1)), [a, b])").
test(variable)    :- rt("solve(a, B)").
test(conjunction) :- rt("(a, b)").
test(disjunction) :- rt("(a ; b)").

%   An atom and a string stay distinct through the tagged mapping.
test(atom_and_string_stay_distinct) :-
    icl_to_json(foo, A), icl_to_json("foo", B),
    A \== B,
    json_to_icl(A, X), json_to_icl(B, Y),
    atom(X), string(Y).

:- end_tests(icl_json_tagged).


:- begin_tests(icl_json_plain).

test(atom_becomes_a_string) :-
    icl_to_plain_json(foo, J), J == "foo".
test(number_stays_a_number) :-
    icl_to_plain_json(42, J), J == 42.
test(list_becomes_an_array) :-
    icl_to_plain_json([a, 1], J), J == ["a", 1].
test(compound_becomes_an_object) :-
    icl_to_plain_json(f(a, 1), J),
    get_dict(f, J, Args), Args == ["a", 1].
test(variable_becomes_null) :-
    icl_to_plain_json(_, J), J == null.

%   And it is lossy, deliberately: an atom and a string come back the same.
test(plain_mapping_is_lossy) :-
    icl_to_plain_json(foo, A),
    icl_to_plain_json("foo", B),
    A == B.

test(round_trips_structure_if_not_type) :-
    plain_json_to_icl(json{f: ["a", 1]}, T),
    T == f(a, 1).
test(null_becomes_a_variable) :-
    plain_json_to_icl(null, T), var(T).

:- end_tests(icl_json_plain).


:- begin_tests(tool_schemas).

schema(Spec, Schema) :-
    solvable_list([Spec], [S]),
    solvable_to_schema(S, Schema).

typed(solvable(square(_, _),
               [argnames(input, output),
                argspecs(in(number, true), out(number, true))], [])).

%   argnames exists in OAA purely for documentation and display, and turns out
%   to be exactly what a tool schema needs.
test(uses_declared_argument_names) :-
    typed(Spec), schema(Spec, Schema),
    get_dict(inputSchema, Schema, In),
    get_dict(properties, In, Props),
    get_dict(input, Props, _),
    get_dict(output, Props, _).

test(maps_icl_types_to_json_types) :-
    typed(Spec), schema(Spec, Schema),
    get_dict(inputSchema, Schema, In),
    get_dict(properties, In, Props),
    get_dict(input, Props, P),
    get_dict(type, P, T), T == "number".

%   Only required inputs are required of a caller; an output is what the
%   caller is asking for.
test(only_required_inputs_are_required) :-
    typed(Spec), schema(Spec, Schema),
    get_dict(inputSchema, Schema, In),
    get_dict(required, In, R),
    R == ["input"].

test(falls_back_to_positional_names) :-
    schema(solvable(anon(_, _), [], []), Schema),
    get_dict(inputSchema, Schema, In),
    get_dict(properties, In, Props),
    get_dict(arg1, Props, _),
    get_dict(arg2, Props, _).

:- end_tests(tool_schemas).


:- begin_tests(mcp_protocol).

%   The JSON-RPC surface is a pure function of the request, so it can be
%   checked without a pipe or a community.
test(initialize_declares_tools) :-
    mcp_handle(json{jsonrpc: "2.0", id: 1, method: "initialize",
                    params: json{}}, R),
    get_dict(result, R, Result),
    get_dict(capabilities, Result, Caps),
    get_dict(tools, Caps, _),
    get_dict(serverInfo, Result, Info),
    get_dict(name, Info, Name), Name == "oaa-next".

test(ping_answers) :-
    mcp_handle(json{jsonrpc: "2.0", id: 2, method: "ping"}, R),
    get_dict(result, R, _).

test(unknown_method_is_an_error) :-
    mcp_handle(json{jsonrpc: "2.0", id: 3, method: "no/such"}, R),
    get_dict(error, R, E),
    get_dict(code, E, C), C == -32601.

%   A notification carries no id and gets no reply.
test(notification_gets_no_reply) :-
    mcp_handle(json{jsonrpc: "2.0", method: "notifications/initialized"}, R),
    R == none.

test(reply_carries_the_request_id) :-
    mcp_handle(json{jsonrpc: "2.0", id: 99, method: "ping"}, R),
    get_dict(id, R, Id), Id == 99.

:- end_tests(mcp_protocol).


:- begin_tests(a2a_protocol).

test(skill_id_names_the_capability) :-
    solvable_list([solvable(square(_, _), [], [])], [S]),
    a2a_skill(S, Skill),
    get_dict(id, Skill, Id), Id == "square/2",
    get_dict(name, Skill, Name), Name == "square".

test(unknown_method_is_an_error) :-
    a2a_handle(json{jsonrpc: "2.0", id: 1, method: "no/such"}, R),
    get_dict(error, R, E),
    get_dict(code, E, C), C == -32601.

:- end_tests(a2a_protocol).
