#!/usr/bin/env swipl
/*  oaa-next example -- the Office Assistant demo: a graphical UI agent
 *
 *  Provenance: NEW / ILLUSTRATIVE.  Stands in for one of the "User
 *  Interface Agent(s)" boxes in the architecture diagram cited in
 *  research/office-demo.md, and its own HTTP surface stands in for the
 *  "laptop, web browser" access the demo page's own description names
 *  alongside the telephone and PDA.  It is an ordinary OAA agent first: it
 *  connects, registers, and turns browser actions into oaa_Solve /
 *  oaa_AddTrigger calls exactly as office_client.pl does by script.
 *  Nothing about the Facilitator, ICL, or the other agents changes because
 *  one requester happens to be a browser instead of a terminal.
 *
 *  Serves the visual reconstruction of the demo's own interface --
 *  office_ui/index.html, a hand-drawn recreation of the screenshot cited
 *  in research/office-demo.md, not a copy of it -- and bridges its three
 *  actions to the same running community office_client.pl talks to:
 *
 *    POST /command  {"text": "..."}         -> propose_goal, then install
 *                                              the trigger it returns
 *    POST /mail      {"from","topic","body"} -> oaa_AddData(mail(...))
 *    GET  /state                             -> what's been delivered so far
 *
 *  Run alongside office_mail_agent.pl, office_telephone_agent.pl and
 *  llm/office_assistant.pl (-oaa_mode OAA_LLM), then open
 *  http://localhost:<port>/ (printed on startup).
 */

:- use_module('../../src/runtime/oaa_config').
:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').
:- use_module('../../src/agents/oaa_trigger').
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_json)).
:- use_module(library(http/json)).

:- initialization(run, main).

:- dynamic office_ui_dir/1.

run :-
    oaa_agent_start(office_ui_agent, [], []),
    this_directory(Dir),
    assertz(office_ui_dir(Dir)),
    server_port(Port),
    %  One worker: every request that reaches this agent's own oaa_Solve /
    %  oaa_AddData / oaa_AddTrigger calls shares one TCP connection to the
    %  Facilitator, which is not safe for two request threads to drive at
    %  once.  A local demo has no need of concurrent requests to trade away
    %  for that.
    http_server(http_dispatch, [port(Port), workers(1)]),
    format("office_ui_agent: open http://localhost:~w/~n", [Port]),
    thread_get_message(_).  % serve forever; Ctrl-C to stop

%   -office_ui_port fixes the port (a test wants a known one to talk to);
%   left unbound, thread_httpd picks an ephemeral one, which is what an
%   interactive run wants -- it prints whichever it gets.
server_port(Port) :-
    ( oaa_resolve(office_ui_port, P), P \== 0 -> Port = P ; true ).

this_directory(Dir) :-
    source_file(run, File),
    file_directory_name(File, Dir).

:- http_handler(root(.), serve_index, []).
:- http_handler(root('command'), handle_command, [methods([post])]).
:- http_handler(root('mail'), handle_mail, [methods([post])]).
:- http_handler(root('state'), handle_state, [methods([get])]).

%   Read and written directly rather than through http_reply_file/3, which
%   refuses any path outside a location it was itself asked to serve from --
%   a safeguard against a request naming an arbitrary file, moot here since
%   Path never comes from the request.
serve_index(_Request) :-
    office_ui_dir(Dir),
    directory_file_path(Dir, 'office_ui/index.html', Path),
    read_file_to_string(Path, Html, [encoding(utf8)]),
    format("Content-type: text/html; charset=UTF-8~n~n"),
    format("~s", [Html]).

%   Same mapping office_client.pl uses: the proposal names the trigger to
%   install using the ICL spelling of the library call it maps to.
handle_command(Request) :-
    http_read_data(Request, Body, [json_object(dict)]),
    get_dict(text, Body, Text),
    catch(
        (   oaa_solve(propose_goal(Text, Goal), [time_limit(30)])
        ->  execute_proposal(Goal, ResultText),
            Reply = _{ok: true, result: ResultText}
        ;   Reply = _{ok: false, error: "office_assistant gave no proposal"}
        ),
        Error,
        ( format(atom(Msg), "~q", [Error]), Reply = _{ok: false, error: Msg} )
    ),
    reply_json_dict(Reply).

execute_proposal(oaa_AddTrigger(Type, Cond, Action, Params), ResultText) :- !,
    oaa_add_trigger(Type, Cond, Action, Params),
    format(atom(ResultText), "trigger installed: ~q",
           [oaa_trigger(Type, Cond, Action, Params)]).
execute_proposal(Goal, ResultText) :-
    format(atom(ResultText), "don't know how to install proposal: ~q", [Goal]).

%   Mail "arriving" is nothing more than this agent -- standing in for
%   whichever agent would actually be delivering it -- calling oaa_AddData
%   on the mail solvable, exactly as office_client.pl does.
handle_mail(Request) :-
    http_read_data(Request, Body, [json_object(dict)]),
    get_dict(from, Body, From),
    get_dict(topic, Body, Topic),
    get_dict(body, Body, MailBody),
    atom_string(FromAtom, From),
    atom_string(TopicAtom, Topic),
    oaa_add_data(mail(FromAtom, about(TopicAtom), MailBody), []),
    reply_json_dict(_{ok: true}).

%   What the browser polls to animate a delivery and the connection status.
%   Best-effort: the telephone agent may not have registered yet.
handle_state(_Request) :-
    (   catch(findall(T, oaa_solve(delivered(T),
                                   [address(name(office_telephone_agent)),
                                    time_limit(3)]),
                      Delivered),
              _, fail)
    ->  Connected = true
    ;   Delivered = [], Connected = false
    ),
    get_time(Now), format_time(atom(Clock), "%H:%M", Now),
    reply_json_dict(_{connected: Connected, delivered: Delivered,
                      clock: Clock}).
