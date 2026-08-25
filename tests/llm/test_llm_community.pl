/*  oaa-next -- an LLM agent in a live community
 *
 *  The point of these is negative as much as positive.  Nothing in the
 *  community is arranged around the LLM agent: the Facilitator selects it by
 *  unification like any provider, the client that asks does not know what is
 *  behind interpret/2, and the agents that end up doing the work never learn
 *  that a model was involved.
 */

:- module(test_llm_community, []).

:- use_module('../integration/community').

agents([ '/examples/basic/square_agent.pl',
         '/examples/basic/greet_agent.pl' ]).

start(H) :-
    agents(A),
    start_community(A, H),
    start_llm_agent(H).

%   The LLM agent needs OAA_MODE set, so it is started separately with that
%   argument rather than through the plain agent list.
start_llm_agent(community(Dir, PIDs)) :-
    community:repo_root(Root),
    community:swipl_path(Swipl),
    atomic_list_concat([Root, '/examples/llm/scripted_llm_agent.pl'], Script),
    process_create(Swipl, [Script, '--', '-oaa_mode', 'OAA_LLM'],
                   [cwd(Dir), process(PID), stdout(null), stderr(null)]),
    nb_setval(llm_pid, PID),
    b_setval(unused, PIDs),
    sleep(1.0).

stop(H) :-
    ( nb_current(llm_pid, PID)
    -> catch(process_kill(PID, term), _, true),
       catch(process_wait(PID, _, [timeout(2)]), _, true)
    ;  true ),
    stop_community(H).

:- use_module(library(process)).

:- begin_tests(llm_community,
               [ setup(( start(H), nb_setval(lc, H) )),
                 cleanup(( nb_getval(lc, H), stop(H) )) ]).

lines(Lines) :-
    nb_getval(lc, H),
    run_program(H, '/examples/llm/llm_client.pl', Lines).

%   A request in English reaches an agent that has never heard of English.
test(english_request_reaches_a_plain_agent) :-
    lines(Lines),
    once(( member(L, Lines),
           sub_string(L, _, _, _, "square the number 7"),
           sub_string(L, _, _, _, "square(7,49)") )).

%   Backtracking survives the journey: an agent whose callback succeeds three
%   times still yields three solutions.
test(multiple_solutions_survive) :-
    lines(Lines),
    once(( member(L, Lines),
           sub_string(L, _, _, _, "greet the world"),
           sub_string(L, _, _, _, "Greetings, world") )).

%   The model may write a compound goal, and the Facilitator decomposes it
%   across two agents exactly as it would one written by hand.  This is the
%   whole architecture working at once.
test(model_written_compound_goal_is_decomposed) :-
    lines(Lines),
    once(( member(L, Lines),
            sub_string(L, _, _, _, "square the number 3 and greet the world"),
           sub_string(L, _, _, _, "square(3,9)"),
           sub_string(L, _, _, _, "Hello, world") )).

%   A request nothing can serve gets an honest refusal rather than a
%   fabricated goal.
test(unservable_request_is_refused) :-
    lines(Lines),
    once(( member(L, Lines),
           sub_string(L, _, _, _, "something impossible"),
           sub_string(L, _, _, _, "could_not_interpret") )).

:- end_tests(llm_community).
