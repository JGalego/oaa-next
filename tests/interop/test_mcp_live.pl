/*  oaa-next -- the MCP bridge against a live community
 *
 *  An MCP client reaching agents that have never heard of MCP.
 */

:- module(test_mcp_live, []).

:- use_module('../integration/community').
:- use_module(library(process)).
:- use_module(library(http/json)).

agents([ '/examples/basic/square_agent.pl',
         '/examples/basic/greet_agent.pl' ]).

%!  mcp_exchange(+Handle, +Requests, -Replies) is det.
%
%   Speak JSON-RPC to the bridge over its stdio transport, one message a line.

mcp_exchange(community(Dir, _), Requests, Replies) :-
    community:repo_root(Root),
    community:swipl_path(Swipl),
    atomic_list_concat([Root, '/bin/oaa-mcp-server.pl'], Script),
    process_create(Swipl, [Script, '--'],
                   [ cwd(Dir), stdin(pipe(In)), stdout(pipe(Out)),
                     stderr(null), process(PID) ]),
    forall(member(R, Requests),
           ( atom_json_dict(Line, R, [as(atom), width(0)]),
             format(In, "~w~n", [Line]) )),
    flush_output(In),
    close(In),
    read_string(Out, _, S),
    close(Out),
    process_wait(PID, _),
    split_string(S, "\n", " ", Lines0),
    exclude(==(""), Lines0, Lines),
    findall(D, ( member(L, Lines), atom_json_dict(L, D, []) ), Replies).

:- begin_tests(mcp_live,
               [ setup(( agents(A), start_community(A, C), nb_setval(mcp, C) )),
                 cleanup(( nb_getval(mcp, C), stop_community(C) )) ]).

exchange(Requests, Replies) :-
    nb_getval(mcp, C),
    mcp_exchange(C, Requests, Replies).

%   The community's capabilities appear as MCP tools, described by schemas
%   built from the solvables' own declarations.
test(community_capabilities_appear_as_tools) :-
    exchange([ json{jsonrpc: "2.0", id: 1, method: "initialize", params: json{}},
               json{jsonrpc: "2.0", id: 2, method: "tools/list"} ],
             Replies),
    member(R, Replies),
    get_dict(id, R, 2),
    get_dict(result, R, Result),
    get_dict(tools, Result, Tools),
    findall(N, ( member(T, Tools), get_dict(name, T, N) ), Names),
    memberchk("square", Names),
    memberchk("greet", Names).

%   A tool call becomes an ICL goal, is delegated, and the answer comes back.
test(tool_call_reaches_an_agent) :-
    exchange([ json{jsonrpc: "2.0", id: 1, method: "tools/call",
                    params: json{name: "square",
                                 arguments: json{arg1: 6}}} ],
             [R]),
    get_dict(result, R, Result),
    get_dict(content, Result, [Block|_]),
    get_dict(text, Block, Text),
    once(sub_string(Text, _, _, _, "square(6,36)")).

%   An ICL goal may have several solutions; a tool call has one result, so the
%   bridge reports them all rather than choosing.
test(several_solutions_are_all_reported) :-
    exchange([ json{jsonrpc: "2.0", id: 1, method: "tools/call",
                    params: json{name: "greet",
                                 arguments: json{arg1: "world"}}} ],
             [R]),
    get_dict(result, R, Result),
    get_dict(structuredContent, Result, SC),
    get_dict(solutions, SC, Solutions),
    length(Solutions, 3).

%   An unbound argument is how a caller asks for a value rather than
%   supplying one, and it survives the translation.
test(omitted_argument_is_the_one_asked_for) :-
    exchange([ json{jsonrpc: "2.0", id: 1, method: "tools/call",
                    params: json{name: "square",
                                 arguments: json{arg1: 9}}} ],
             [R]),
    get_dict(result, R, Result),
    get_dict(structuredContent, Result, SC),
    get_dict(solutions, SC, [S|_]),
    get_dict(square, S, [9, 81]).

test(unknown_tool_is_reported_as_an_error) :-
    exchange([ json{jsonrpc: "2.0", id: 1, method: "tools/call",
                    params: json{name: "no_such_tool", arguments: json{}}} ],
             [R]),
    get_dict(result, R, Result),
    get_dict(isError, Result, true).

:- end_tests(mcp_live).
