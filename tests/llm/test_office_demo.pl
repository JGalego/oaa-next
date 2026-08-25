/*  oaa-next -- the Office Assistant demo, live
 *
 *  Regression coverage for examples/multi-agent/office_*.pl and
 *  examples/llm/office_assistant.pl.  Confirms the pattern documented in
 *  research/office-demo.md still works: a natural-language sentence --
 *  the screenshot's own command -- becomes an installed trigger that
 *  delivers matching mail through a different agent when it arrives, and
 *  leaves non-matching mail alone.
 */

:- module(test_office_demo, []).

:- use_module('../integration/community').
:- use_module(library(process)).

agents([ '/examples/multi-agent/office_mail_agent.pl',
         '/examples/multi-agent/office_telephone_agent.pl' ]).

start(H) :-
    agents(A),
    start_community(A, H),
    start_llm_agent(H).

%   The LLM agent needs OAA_MODE set, so it is started separately with that
%   argument rather than through the plain agent list -- same reason and
%   same pattern as test_llm_community.pl.
start_llm_agent(community(Dir, _PIDs)) :-
    community:repo_root(Root),
    community:swipl_path(Swipl),
    atomic_list_concat([Root, '/examples/llm/office_assistant.pl'], Script),
    process_create(Swipl, [Script, '--', '-oaa_mode', 'OAA_LLM'],
                   [cwd(Dir), process(PID), stdout(null), stderr(null)]),
    nb_setval(office_llm_pid, PID),
    sleep(1.0).

stop(H) :-
    ( nb_current(office_llm_pid, PID)
    -> catch(process_kill(PID, term), _, true),
       catch(process_wait(PID, _, [timeout(2)]), _, true)
    ;  true ),
    stop_community(H).

:- begin_tests(office_demo,
               [ setup(( start(H), nb_setval(od, H) )),
                 cleanup(( nb_getval(od, H), stop(H) )) ]).

lines(Lines) :-
    nb_getval(od, H),
    run_program(H, '/examples/multi-agent/office_client.pl', Lines).

%   The sentence from the demo screenshot installs a trigger naming the
%   documented condition and action.
test(sentence_installs_the_documented_trigger) :-
    lines(Lines),
    once(( member(L, Lines),
           sub_string(L, _, _, _, "trigger installed"),
           sub_string(L, _, _, _, "about(security)"),
           sub_string(L, _, _, _, "deliver_by_phone") )).

%   Mail about security is delivered by phone; mail about lunch is not --
%   the trigger's condition actually discriminates, not just installs.
test(only_matching_mail_is_delivered) :-
    lines(Lines),
    once(( member(L, Lines),
           sub_string(L, _, _, _, "delivered by phone"),
           sub_string(L, _, _, _, "rotate the shared credentials"),
           \+ sub_string(L, _, _, _, "lunch") )).

:- end_tests(office_demo).
