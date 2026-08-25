/*  oaa-next -- LLM extension: an OAA agent whose reasoning engine is an LLM
 *
 *  Provenance: NEW / LLM EXTENSION.
 */

:- module(llm_agent,
          [ llm_agent_main/0,
            llm_agent_solvables/1,      % -Solvables
            llm_interpret/3,            % +Request, +Params, -Result
                        llm_interpret_session/4,    % +Session, +Request, +Params, -Result
                        llm_reset_conversation/1,   % +Session
            community_capabilities/1,   % -Capabilities
            icl_from_reply/2            % +Text, -Goal
          ]).

:- use_module('../icl/icl_term').
:- use_module('../agents/oaa_run').
:- use_module('../agents/oaa_agent').
:- use_module(llm_config).
:- use_module(llm_provider).

:- dynamic conversation_history/2.

/** <module> An LLM-backed OAA agent

This is an ordinary OAA agent.  It connects with com_Connect, registers with
oaa_Register, declares solvables, answers requests through a callback and asks
for services with oaa_Solve.  Its reasoning engine happens to be a language
model, and nothing else in the community is arranged around that fact -- the
Facilitator selects it by unification against its goal template like any other
provider, and could not discover what is inside it if it tried.

What it adds is a route from a request in English to work done by agents that
have never heard of English.  It asks the Facilitator what the community can
do, puts that to the model as the available vocabulary, takes back an ICL
goal, and solves it the ordinary way.

The LLM never talks to the other agents.  It writes a goal; OAA delegates it.
That is the invariant worth protecting: an LLM in this position makes the
community more capable without becoming a route around it.
*/

llm_agent_solvables([ solvable(interpret(_, _, _),
                                                             [ callback(llm_agent:interpret_session_request),
                                                                 argspecs(in(_, true), in(string, true),
                                                                                    out(_, true)) ],
                                                             []),
                                            solvable(reset_conversation(_),
                                                             [ callback(llm_agent:reset_conversation_request),
                                                                 argspecs(in(_, true)) ],
                                                             []),
                                            solvable(interpret(_, _),
                               [ callback(llm_agent:interpret_request),
                                 argspecs(in(string, true), out(_, true)) ],
                               []),
                      solvable(propose_goal(_Proposal, _Goal),
                               [callback(llm_agent:propose_request)], []) ]).

%!  llm_agent_main is det.
%
%   Refuses to start unless the extension is enabled, rather than registering
%   and then answering nothing.

llm_agent_main :-
    llm_require_enabled,
    load_provider,
    llm_agent_solvables(S),
    oaa_agent_run(llm_agent, S, []).

%   Only the configured adapter is loaded.  An installation using one provider
%   never pulls in another's dependencies.

load_provider :-
    llm_provider_name(Name),
    provider_file(Name, Relative),
    (   llm_known_provider(Name, _)
    ->  true
    ;   source_file(llm_agent:llm_agent_main, Source),
        file_directory_name(Source, Dir),
        directory_file_path(Dir, Relative, File),
        use_module(File)
    ).

provider_file(anthropic, 'providers/llm_anthropic.pl').
provider_file(openai,    'providers/llm_openai.pl').
provider_file(scripted,  'providers/llm_scripted.pl').

% ----------------------------------------------------------------- callbacks

interpret_request(interpret(Request, Result), Params) :-
    llm_interpret(Request, Params, Result).

interpret_session_request(interpret(Session, Request, Result), Params) :-
    llm_interpret_session(Session, Request, Params, Result).

reset_conversation_request(reset_conversation(Session), _Params) :-
    llm_reset_conversation(Session).

propose_request(propose_goal(Request, Goal), _Params) :-
    community_capabilities(Caps),
    propose(Request, Caps, Goal).

%!  llm_interpret(+Request, +Params, -Result) is semidet.
%
%   Turn a request in English into work done by the community.

llm_interpret(Request, _Params, Result) :-
    community_capabilities(Caps),
    (   propose(Request, Caps, Goal)
    ->  solve_proposed(Goal, Result)
    ;   Result = could_not_interpret(Request)
    ).

%!  llm_interpret_session(+Session, +Request, +Params, -Result) is det.
%
%   Interpret Request with bounded dialogue history private to Session.  Calls
%   in one session are serialized so concurrent clients cannot interleave its
%   turns; unrelated sessions remain independent.

llm_interpret_session(Session, Request, _Params, Result) :-
    (   ground(Session)
    ->  true
    ;   throw(oaa_error(non_ground_conversation_session(Session)))
    ),
    session_mutex(Session, Mutex),
    with_mutex(Mutex, interpret_session_locked(Session, Request, Result)).

interpret_session_locked(Session, Request, Result) :-
    community_capabilities(Caps),
    session_history(Session, History),
    proposal_outcome(Request, Caps, History, Outcome, Reply),
    remember_turn(Session, History, Request, Reply),
    (   Outcome = goal(Goal)
    ->  solve_proposed(Goal, Result)
    ;   Result = could_not_interpret(Request)
    ).

%!  llm_reset_conversation(+Session) is det.

llm_reset_conversation(Session) :-
    retractall(conversation_history(Session, _)).

session_mutex(Session, Mutex) :-
    term_hash(Session, Hash),
    format(atom(Mutex), 'llm_conversation_~16r', [Hash]).

session_history(Session, History) :-
    ( conversation_history(Session, Stored) -> History = Stored ; History = [] ).

remember_turn(Session, History, Request, Reply) :-
    append(History,
           [message(user, Request), message(assistant, Reply)],
           Extended),
    keep_last_messages(12, Extended, Bounded),
    retractall(conversation_history(Session, _)),
    assertz(conversation_history(Session, Bounded)).

keep_last_messages(Max, Messages, Kept) :-
    length(Messages, Count),
    Drop is max(0, Count - Max),
    length(Prefix, Drop),
    append(Prefix, Kept, Messages).

%   Solving the proposed goal is an ordinary request.  reflexive(false) keeps
%   this agent from being offered its own goal back, which would loop.

solve_proposed(Goal, Result) :-
    copy_term(Goal, Probe),
    findall(Probe, oaa_solve(Probe, [reflexive(false), time_limit(60)]),
            Solutions),
    (   Solutions == []
    ->  Result = no_solution(Goal)
    ;   Result = solutions(Goal, Solutions)
    ).

%!  propose(+Request, +Capabilities, -Goal) is semidet.
%
%   Ask the model for an ICL goal and parse it.  A reply that is not
%   well-formed ICL is a failure, not something to repair by guesswork: a goal
%   the Facilitator cannot route is worse than an honest refusal.

propose(Request, Caps, Goal) :-
    proposal_outcome(Request, Caps, [], goal(Goal), _Reply).

proposal_outcome(Request, Caps, History, Outcome, Reply) :-
    system_prompt(Caps, System),
    text_to_string(Request, RequestStr),
    append([message(system, System)|History],
           [message(user, RequestStr)], Messages),
    llm_complete(Messages, [max_tokens(1024)], Response),
    llm_response_text(Response, Reply),
    (   icl_from_reply(Reply, Goal)
    ->  Outcome = goal(Goal)
    ;   Outcome = refusal
    ).

%   The capabilities are given to the model as the vocabulary it may use, in
%   the same ICL notation the community speaks, so that what it writes is
%   already in the language the Facilitator reads.

system_prompt(Caps, System) :-
    findall(Line,
            ( member(Cap, Caps),
              icl_term_string(Cap, Str),
              format(atom(Line), "  ~w", [Str]) ),
            Lines),
    atomic_list_concat(Lines, '\n', CapText),
    format(atom(System),
"You translate a user's request into a single Interagent Communication \c
Language goal for an Open Agent Architecture community.

ICL is a Prolog-like term language. A goal is a functor with arguments, for \c
example send(mail, 'Alice', 'hello'). Variables begin with a capital letter \c
and stand for values you want back. Conjunction is written (a, b) with the \c
parentheses; disjunction is a ; b.

These are the capabilities the community currently offers. Use only these:

~w

Names such as _G1 and _G2 in those signatures are variable placeholders. \
Preserve each capability's exact number of arguments: replace input \
placeholders with values from the request and leave output placeholders as \
fresh variables. For example, square(_G1,_G2) applied to 7 becomes \
square(7, Result). To use two capabilities, return a parenthesised \
conjunction such as (square(7, Result), greet(world, Greeting)).

Reply with the goal alone. No explanation or code fences. If no combination \
of the capabilities above can serve the request, reply with exactly: cannot",
           [CapText]),
    true.

%!  icl_from_reply(+Text, -Goal) is semidet.
%
%   Recover a goal from a model's reply.  Code fences and stray whitespace are
%   tolerated because they are a formatting habit rather than a change of
%   meaning; anything else that fails to parse is rejected.

icl_from_reply(Text, Goal) :-
    text_to_string(Text, S0),
    strip_fences(S0, S1),
    normalize_space(string(S2), S1),
    strip_trailing_period(S2, S),
    S \== "",
    S \== "cannot",
    icl_parse_term(S, Goal),
    \+ atom(Goal).

strip_trailing_period(In, Out) :-
    (   string_concat(Core, ".", In)
    ->  normalize_space(string(Out), Core)
    ;   Out = In
    ).

strip_fences(In, Out) :-
    split_string(In, "\n", "", Lines0),
    exclude([L]>>( string_concat("```", _, L) ), Lines0, Lines),
    atomic_list_concat(Lines, '\n', Atom),
    atom_string(Atom, Out).

%!  community_capabilities(-Capabilities) is det.
%
%   What the community can do, asked of the Facilitator the ordinary way.
%   This agent's own solvables are left out: offering them back to the model
%   invites a goal that routes straight to this agent again.

community_capabilities(Capabilities) :-
    ( oaa_local_id(Me) -> true ; Me = -1 ),
    findall(Goal,
            ( oaa_solve(agent_data(Id, _Type, ready, Solvables, _Name, _Info),
                        [address(parent), time_limit(10)]),
              Id \== Me,
              member(solvable(Goal, _, _), Solvables) ),
            Goals),
    exclude(internal_goal, Goals, Capabilities).

%   The facilitator's own bookkeeping solvables are not useful vocabulary.

internal_goal(G) :-
    functor(G, Name, _),
    memberchk(Name, [agent_data, agent_host, agent_location, agent_version,
                     facilitator_data, can_solve, icl_type, data,
                     agent_listener, oaa_trigger, meta]).
