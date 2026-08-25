/*  oaa-next -- interoperability: presenting a community to A2A
 *
 *  Provenance: INTEROPERABILITY ADAPTER.
 */

:- module(a2a_bridge,
          [ a2a_agent_card/1,           % -Card
            a2a_handle/2,               % +Request, -Response
            a2a_skill/2                 % +Solvable, -Skill
          ]).

:- use_module('../icl/icl_term').
:- use_module('../agents/oaa_agent').
:- use_module('../agents/oaa_solvable').
:- use_module(icl_json).

/** <module> An OAA community as an A2A agent

A2A describes an agent to other agents with an Agent Card: who it is, where to
reach it, and what skills it has.  A community has exactly that information
already -- the Facilitator's registry is a list of who can do what -- so the
card is generated rather than written.

The comparison is worth making explicit, because the two designs solve the
same problem and disagree about where the knowledge lives.  An A2A agent
publishes its own card and a client reads cards to decide who to ask.  In OAA
an agent tells one Facilitator what it can do, and the Facilitator decides who
gets asked; the requester names a goal, not an agent.  A card here is that
registry projected outward for the benefit of systems that expect to choose
for themselves.

Like the MCP bridge, this is an edge translation.  Nothing inside the
community changes shape to accommodate it.
*/

%!  a2a_agent_card(-Card) is det.

a2a_agent_card(Card) :-
    findall(Skill,
            ( community_solvable(S), a2a_skill(S, Skill) ),
            Skills),
    ( oaa_name(Name) -> true ; Name = 'oaa-next' ),
    atom_string(Name, NameStr),
    Card = json{ name: NameStr,
                 description: "An Open Agent Architecture community, \c
reached through an A2A bridge. Skills are the capabilities its agents \c
currently declare.",
                 version: "0.1",
                 capabilities: json{ streaming: false,
                                     pushNotifications: false },
                 defaultInputModes: ["text/plain", "application/json"],
                 defaultOutputModes: ["text/plain", "application/json"],
                 skills: Skills }.

%!  a2a_skill(+Solvable, -Skill) is det.
%
%   One capability as an A2A skill.  The identifier is the goal template's
%   functor and arity, which is how OAA names a capability, so a skill id
%   round-trips back to the solvable it came from.

a2a_skill(Solvable, Skill) :-
    Solvable = solvable(Goal, _, _),
    functor(Goal, Name, Arity),
    format(atom(Id), "~w/~w", [Name, Arity]),
    icl_term_string(Goal, Template),
    atom_string(Name, NameStr),
    atom_string(Id, IdStr),
    format(atom(Desc), "ICL goal template: ~w", [Template]),
    atom_string(Desc, DescStr),
    Skill = json{ id: IdStr,
                  name: NameStr,
                  description: DescStr,
                  tags: ["oaa", "icl"] }.

community_solvable(S) :-
    ( oaa_local_id(Me) -> true ; Me = -1 ),
    oaa_solve(agent_data(Id, _T, ready, Solvables, _N, _I),
              [address(parent), time_limit(10)]),
    Id \== Me,
    member(S, Solvables),
    S = solvable(Goal, _, _),
    \+ internal_goal(Goal).

internal_goal(G) :-
    functor(G, Name, _),
    memberchk(Name, [agent_data, agent_host, agent_location, agent_version,
                     facilitator_data, can_solve, icl_type, data,
                     agent_listener, oaa_trigger, meta]).

%!  a2a_handle(+Request, -Response) is det.
%
%   The message endpoint.  A2A carries a message whose parts may be text or
%   structured data; an ICL goal may arrive either way, and the reply carries
%   the solutions back in both forms so that the caller can take whichever it
%   understands.

a2a_handle(Request, Response) :-
    get_dict(method, Request, Method),
    ( get_dict(id, Request, Id) -> true ; Id = null ),
    ( get_dict(params, Request, Params) -> true ; Params = json{} ),
    catch(( a2a_method(Method, Params, Result)
          -> Outcome = ok(Result)
          ;  Outcome = not_found ),
          E,
          Outcome = failed(E)),
    a2a_response(Outcome, Id, Response).

a2a_response(ok(Result), Id, json{jsonrpc: "2.0", id: Id, result: Result}).
a2a_response(not_found, Id,
             json{jsonrpc: "2.0", id: Id,
                  error: json{code: -32601, message: "method not found"}}).
a2a_response(failed(E), Id,
             json{jsonrpc: "2.0", id: Id,
                  error: json{code: -32603, message: Msg}}) :-
    ( catch(term_string(E, Msg), _, fail) -> true ; Msg = "internal error" ).

a2a_method("agent/getCard", _Params, Card) :- !,
    a2a_agent_card(Card).
a2a_method("message/send", Params, Result) :- !,
    get_dict(message, Params, Message),
    message_goal(Message, Goal),
    solve_for_a2a(Goal, Result).

%   A goal may arrive as ICL text or as a structured part.

message_goal(Message, Goal) :-
    get_dict(parts, Message, Parts),
    member(Part, Parts),
    (   get_dict(text, Part, Text),
        icl_parse_term(Text, Goal)
    ->  true
    ;   get_dict(data, Part, Data),
        plain_json_to_icl(Data, Goal)
    ),
    !.

solve_for_a2a(Goal, Result) :-
    copy_term(Goal, Probe),
    findall(Probe, oaa_solve(Probe, [reflexive(false), time_limit(60)]),
            Solutions),
    findall(Line, ( member(S, Solutions), icl_term_string(S, Line) ), Lines),
    atomic_list_concat(Lines, '\n', Text),
    maplist(icl_to_plain_json, Solutions, Structured),
    ( Solutions == [] -> State = "failed" ; State = "completed" ),
    Result = json{ kind: "task",
                   status: json{state: State},
                   artifacts: [ json{ name: "solutions",
                                      parts: [ json{kind: "text", text: Text},
                                               json{kind: "data",
                                                    data: json{solutions: Structured}} ] } ] }.
