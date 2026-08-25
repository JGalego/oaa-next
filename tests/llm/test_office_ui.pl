/*  oaa-next -- the Office Assistant demo's HTTP front end, live
 *
 *  Exercises examples/multi-agent/office_ui_agent.pl the way a browser
 *  would: real HTTP requests against a running instance, not a Prolog-level
 *  call.  Confirms the bridge from browser action to oaa_Solve /
 *  oaa_AddTrigger / oaa_AddData actually works end to end, on top of the
 *  same community test_office_demo.pl already proves the underlying pattern
 *  in for the non-visual client.
 */

:- module(test_office_ui, []).

:- use_module('../integration/community').
:- use_module(library(process)).
:- use_module(library(http/http_open)).
:- use_module(library(http/http_client)).
:- use_module(library(http/json)).

agents([ '/examples/multi-agent/office_mail_agent.pl',
         '/examples/multi-agent/office_telephone_agent.pl' ]).

ui_port(23845).  % fixed, so the test can talk to it without parsing stdout

start(H) :-
    agents(A),
    start_community(A, H),
    start_llm_agent(H),
    start_ui_agent(H).

start_llm_agent(community(Dir, _PIDs)) :-
    community:repo_root(Root),
    community:swipl_path(Swipl),
    atomic_list_concat([Root, '/examples/llm/office_assistant.pl'], Script),
    process_create(Swipl, [Script, '--', '-oaa_mode', 'OAA_LLM'],
                   [cwd(Dir), process(PID), stdout(null), stderr(null)]),
    nb_setval(office_ui_llm_pid, PID),
    sleep(1.0).

start_ui_agent(community(Dir, _PIDs)) :-
    community:repo_root(Root),
    community:swipl_path(Swipl),
    ui_port(Port),
    atomic_list_concat([Root, '/examples/multi-agent/office_ui_agent.pl'],
                       Script),
    number_string(Port, PortStr),
    process_create(Swipl,
                   [Script, '--', '-office_ui_port', PortStr],
                   [cwd(Dir), process(PID), stdout(null), stderr(null)]),
    nb_setval(office_ui_pid, PID),
    sleep(1.0).

stop(H) :-
    ( nb_current(office_ui_pid, PID)
    -> catch(process_kill(PID, term), _, true),
       catch(process_wait(PID, _, [timeout(2)]), _, true)
    ;  true ),
    ( nb_current(office_ui_llm_pid, LlmPID)
    -> catch(process_kill(LlmPID, term), _, true),
       catch(process_wait(LlmPID, _, [timeout(2)]), _, true)
    ;  true ),
    stop_community(H).

url(Path, Url) :-
    ui_port(Port),
    format(atom(Url), "http://localhost:~w/~w", [Port, Path]).

post_json(Path, DataDict, ReplyDict) :-
    url(Path, Url),
    atom_json_dict(BodyAtom, DataDict, [as(atom)]),
    setup_call_cleanup(
        http_open(Url, Stream,
                  [ method(post),
                    request_header('content-type'='application/json'),
                    post(atom('application/json', BodyAtom)) ]),
        json_read_dict(Stream, ReplyDict),
        close(Stream)).

get_json(Path, ReplyDict) :-
    url(Path, Url),
    setup_call_cleanup(
        http_open(Url, Stream, []),
        json_read_dict(Stream, ReplyDict),
        close(Stream)).

:- begin_tests(office_ui,
               [ setup(( start(H), nb_setval(oui, H) )),
                 cleanup(( nb_getval(oui, H), stop(H) )) ]).

%   The page itself is served, and looks like the room it reconstructs --
%   the command bar carries the demo's own verbatim sentence.
test(index_page_carries_the_demo_sentence) :-
    url('', Url),
    setup_call_cleanup(
        http_open(Url, Stream, []),
        read_string(Stream, _, Html),
        close(Stream)),
    %  The page source has this HTML-escaped (&quot;), not as literal quote
    %  characters, so the check leaves the quoting out.
    once(sub_string(Html, _, _, _,
                    "When mail arrives for me about")),
    once(sub_string(Html, _, _, _, "get it to me by telephone")).

%   POSTing the sentence over HTTP installs the same trigger the
%   Prolog-level client does.
test(command_installs_trigger_over_http) :-
    post_json(command, _{text: "When mail arrives for me about \"security\" get it to me by telephone."},
              Reply),
    get_dict(ok, Reply, true),
    get_dict(result, Reply, Result),
    once(sub_string(Result, _, _, _, "trigger installed")),
    once(sub_string(Result, _, _, _, "about(security)")).

%   Mail matching the trigger, sent as a browser would via POST /mail, is
%   delivered; unrelated mail is not.  GET /state is how the browser (and
%   this test) observes it.
test(matching_mail_is_delivered_over_http) :-
    post_json(mail, _{from: "alice", topic: "security",
                      body: "Please rotate the shared credentials by Friday."},
              MailReply),
    get_dict(ok, MailReply, true),
    sleep(0.5),
    get_json(state, StateReply),
    get_dict(delivered, StateReply, Delivered),
    once(( member(D, Delivered),
           sub_string(D, _, _, _, "rotate the shared credentials") )).

test(unrelated_mail_is_not_delivered_over_http) :-
    post_json(mail, _{from: "bob", topic: "lunch",
                      body: "Want to grab lunch at noon?"}, MailReply),
    get_dict(ok, MailReply, true),
    sleep(0.5),
    get_json(state, StateReply),
    get_dict(delivered, StateReply, Delivered),
    \+ ( member(D, Delivered), sub_string(D, _, _, _, "lunch") ).

:- end_tests(office_ui).
