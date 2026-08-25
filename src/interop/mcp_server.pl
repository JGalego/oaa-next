/*  oaa-next -- interoperability: serving an OAA community over MCP
 *
 *  Provenance: INTEROPERABILITY ADAPTER.
 */

:- module(mcp_server,
          [ mcp_server_main/0,
            mcp_handle/2,               % +Request, -Response
            mcp_tools/1                 % -Tools
          ]).

:- use_module(library(http/json)).
:- use_module('../icl/icl_term').
:- use_module('../agents/oaa_run').
:- use_module('../agents/oaa_agent').
:- use_module('../agents/oaa_solvable').
:- use_module(icl_json).

/** <module> An OAA community as an MCP server

Presents the capabilities of an OAA community as MCP tools, so that an MCP
client can reach agents that have never heard of MCP.

This is an adapter and is meant to look like one.  Inside the community
nothing changes: this bridge is an ordinary OAA agent that asks the
Facilitator what is available and delegates with oaa_Solve like anything else.
The translation happens at the edge, and only at the edge.

What is lost in translation is worth naming.  An MCP tool call is one call
with named arguments and one result.  An ICL goal can carry unbound variables
in any position, backtrack over several solutions, and be a conjunction the
Facilitator takes apart.  A tool call cannot express any of that, so the
bridge reports all solutions in its result and leaves the richer forms to
callers who speak ICL.

Protocol: JSON-RPC 2.0 over stdio, one message per line.
*/

protocol_version("2025-06-18").

mcp_server_main :-
    oaa_agent_start(mcp_bridge, [], []),
    set_stream(user_input, encoding(utf8)),
    set_stream(user_output, encoding(utf8)),
    serve_loop.

serve_loop :-
    read_line_to_string(user_input, Line),
    (   Line == end_of_file
    ->  true
    ;   Line == ""
    ->  serve_loop
    ;   handle_line(Line),
        serve_loop
    ).

handle_line(Line) :-
    catch(( atom_json_dict(Line, Request, [as(atom)]),
            mcp_handle(Request, Response) ),
          E,
          error_response(E, Response)),
    (   Response == none
    ->  true                    % a notification wants no reply
    ;   %  MCP's stdio transport is one message per line, so the reply must
        %  not be pretty-printed.
        atom_json_dict(Out, Response, [as(atom), width(0)]),
        format("~w~n", [Out]),
        flush_output
    ).

error_response(E, json{jsonrpc: "2.0", id: null,
                       error: json{code: -32603, message: Msg}}) :-
    message_to_codes(E, Msg).

message_to_codes(E, Msg) :-
    ( catch(term_string(E, Msg), _, fail) -> true ; Msg = "internal error" ).

%!  mcp_handle(+Request, -Response) is det.
%
%   The JSON-RPC surface.  Kept as a pure function of the request so that it
%   can be tested without a pipe.

mcp_handle(Request, Response) :-
    get_dict(method, Request, Method),
    ( get_dict(id, Request, Id) -> true ; Id = none ),
    ( get_dict(params, Request, Params) -> true ; Params = json{} ),
    (   Id == none
    ->  %  A notification: act, answer nothing.
        ignore(catch(mcp_method(Method, Params, _), _, true)),
        Response = none
    ;   dispatch(Method, Params, Id, Response)
    ).

dispatch(Method, Params, Id, Response) :-
    catch(( mcp_method(Method, Params, Result)
          -> Outcome = ok(Result)
          ;  Outcome = not_found ),
          E,
          Outcome = failed(E)),
    outcome_response(Outcome, Id, Response).

outcome_response(ok(Result), Id,
                 json{jsonrpc: "2.0", id: Id, result: Result}).
outcome_response(not_found, Id,
                 json{jsonrpc: "2.0", id: Id,
                      error: json{code: -32601,
                                  message: "method not found"}}).
outcome_response(failed(E), Id,
                 json{jsonrpc: "2.0", id: Id,
                      error: json{code: -32603, message: Msg}}) :-
    message_to_codes(E, Msg).

mcp_method("initialize", _Params, Result) :- !,
    protocol_version(V),
    Result = json{ protocolVersion: V,
                   capabilities: json{tools: json{}},
                   serverInfo: json{name: "oaa-next", version: "0.1"} }.
mcp_method("notifications/initialized", _Params, json{}) :- !.
mcp_method("ping", _Params, json{}) :- !.
mcp_method("tools/list", _Params, json{tools: Tools}) :- !,
    mcp_tools(Tools).
mcp_method("tools/call", Params, Result) :- !,
    get_dict(name, Params, Name),
    ( get_dict(arguments, Params, Args) -> true ; Args = json{} ),
    call_tool(Name, Args, Result).

%!  mcp_tools(-Tools) is det.
%
%   Every capability the community currently offers, as a tool schema.  The
%   bridge's own solvables and the Facilitator's bookkeeping are left out:
%   neither is a capability a client came here for.

mcp_tools(Tools) :-
    findall(Schema,
            ( community_solvable(S),
              solvable_to_schema(S, Schema) ),
            Tools).

community_solvable(S) :-
    ( oaa_local_id(Me) -> true ; Me = -1 ),
    oaa_solve(agent_data(Id, _T, ready, Solvables, _N, _I),
              [address(parent), time_limit(10)]),
    Id \== Me,
    member(S, Solvables),
    S = solvable(Goal, _, _),
    \+ internal_goal(Goal),
    solvable_type(S, procedure).

internal_goal(G) :-
    functor(G, Name, _),
    memberchk(Name, [agent_data, agent_host, agent_location, agent_version,
                     facilitator_data, can_solve, icl_type, data,
                     agent_listener, oaa_trigger, meta]).

%   A tool call becomes an ICL goal: the named arguments are placed by the
%   schema's argument order, and anything the caller left out becomes an
%   unbound variable -- which is how a caller asks for a value rather than
%   supplying one.

call_tool(Name, Args, Result) :-
    atom_string(Functor, Name),
    (   tool_arity(Functor, Arity, Names)
    ->  build_goal(Functor, Arity, Names, Args, Goal),
        solve_and_report(Goal, Result)
    ;   Result = json{ isError: true,
                       content: [json{type: "text",
                                      text: "no such capability"}] }
    ).

tool_arity(Functor, Arity, Names) :-
    community_solvable(S),
    S = solvable(Goal, _, _),
    functor(Goal, Functor, Arity),
    !,
    solvable_to_schema(S, Schema),
    get_dict(inputSchema, Schema, In),
    get_dict(properties, In, Props),
    dict_pairs(Props, _, Pairs),
    findall(N, member(N-_, Pairs), Names).

build_goal(Functor, Arity, Names, Args, Goal) :-
    length(GoalArgs, Arity),
    findall(I-Raw,
            ( nth1(I, Names, Key), get_dict(Key, Args, Raw) ),
            Supplied),
    %  bind_args rather than forall/2: forall is double-negated, so the
    %  bindings it makes are undone as it goes.
    bind_args(Supplied, GoalArgs),
    Goal =.. [Functor|GoalArgs].

bind_args([], _).
bind_args([I-Raw|T], GoalArgs) :-
    plain_json_to_icl(Raw, V),
    nth1(I, GoalArgs, V),
    bind_args(T, GoalArgs).

solve_and_report(Goal, Result) :-
    copy_term(Goal, Probe),
    findall(Probe, oaa_solve(Probe, [reflexive(false), time_limit(60)]),
            Solutions),
    (   Solutions == []
    ->  Result = json{ content: [json{type: "text", text: "no solution"}] }
    ;   findall(Line,
                ( member(S, Solutions), icl_term_string(S, Line) ),
                Lines),
        atomic_list_concat(Lines, '\n', Text),
        maplist(icl_to_plain_json, Solutions, Structured),
        Result = json{ content: [json{type: "text", text: Text}],
                       structuredContent: json{solutions: Structured} }
    ).
