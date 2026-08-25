/*  oaa-next -- end-to-end community test
 *
 *  The Phase 1 acceptance test: start a Facilitator and two agents as
 *  separate operating-system processes, have a fourth process solve goals it
 *  cannot answer itself, and observe the Facilitator discover, delegate,
 *  collect and return.
 *
 *  Separate processes are not incidental.  An OAA agent is an ordinary
 *  software process, and each agent's declarations and data are its own; a
 *  test that ran them all in one Prolog image would share state between
 *  agents and prove nothing about delegation.
 *
 *  No LLM is present, no LLM package is installed, and no credentials are
 *  configured.  That is the OAA_CLASSIC guarantee.
 */

:- module(test_community, []).

:- use_module(library(process)).
:- use_module(library(filesex)).

:- dynamic proc/2.              % Name, PID
:- dynamic workdir/1.

repo_root(Root) :-
    source_file(repo_root(_), File),
    file_directory_name(File, TestDir),
    file_directory_name(TestDir, TestsDir),
    file_directory_name(TestsDir, Root).

swipl_path(Path) :-
    (   absolute_file_name(path(swipl), Path, [access(execute), file_errors(fail)])
    ->  true
    ;   Path = '/usr/bin/swipl'
    ).

% --------------------------------------------------------------- lifecycle

start_community :-
    repo_root(Root),
    tmp_file_stream(text, TmpFile, S), close(S), delete_file(TmpFile),
    make_directory(TmpFile),
    retractall(workdir(_)),
    assertz(workdir(TmpFile)),
    directory_file_path(TmpFile, 'setup.pl', Setup),

    spawn(fac, [Root, '/bin/facilitator.pl'], ['-write_setup_file', Setup], TmpFile),
    wait_for_file(Setup, 100),

    spawn(square, [Root, '/examples/basic/square_agent.pl'], [], TmpFile),
    spawn(greet,  [Root, '/examples/basic/greet_agent.pl'],  [], TmpFile),
    spawn(sensor, [Root, '/examples/multi-agent/sensor_agent.pl'], [], TmpFile),
    %  Agents need a moment to connect and register; the client waits for the
    %  capabilities it needs, so this only has to be long enough to avoid
    %  racing the facilitator's accept.
    sleep(0.5).

spawn(Name, PathParts, Args, Cwd) :-
    atomic_list_concat(PathParts, Script),
    swipl_path(Swipl),
    process_create(Swipl, [Script, '--'|Args],
                   [ cwd(Cwd), process(PID),
                     stdout(null), stderr(null) ]),
    assertz(proc(Name, PID)).

wait_for_file(_, 0) :- !, throw(error(facilitator_never_started, _)).
wait_for_file(File, N) :-
    (   exists_file(File),
        size_file(File, Size), Size > 0
    ->  true
    ;   sleep(0.1),
        N1 is N - 1,
        wait_for_file(File, N1)
    ).

stop_community :-
    forall(retract(proc(_, PID)),
           ( catch(process_kill(PID, term), _, true),
             catch(process_wait(PID, _, [timeout(2)]), _, true) )),
    (   retract(workdir(Dir))
    ->  catch(delete_directory_and_contents(Dir), _, true)
    ;   true
    ).

%   Run a one-shot agent and capture what it prints.
run_client(Lines) :-
    run_program('/examples/basic/client.pl', Lines).

run_program(Relative, Lines) :-
    repo_root(Root),
    atomic_list_concat([Root, Relative], Script),
    workdir(Cwd),
    swipl_path(Swipl),
    process_create(Swipl, [Script, '--'],
                   [ cwd(Cwd), stdout(pipe(Out)), stderr(null),
                     process(PID) ]),
    read_string(Out, _, S),
    close(Out),
    process_wait(PID, _Status),
    split_string(S, "\n", " \t", Lines0),
    exclude(==(""), Lines0, Lines).

% -------------------------------------------------------------------- tests

:- begin_tests(community, [setup(start_community), cleanup(stop_community)]).

%   Given an agent advertises a capability, when another agent requests it,
%   then the Facilitator discovers and delegates, and the answer comes back.
test(delegates_and_returns) :-
    run_client(Lines),
    memberchk("square(7) = 49", Lines).

%   A callback that succeeds several times yields several solutions, and the
%   requester backtracks over them exactly as it would over a local call.
test(multiple_solutions) :-
    run_client(Lines),
    memberchk("greet solutions: 3", Lines),
    memberchk("Hello, world", Lines),
    memberchk("Good day, world", Lines),
    memberchk("Greetings, world", Lines).

%   A goal no agent can solve fails, rather than hanging or erroring.
test(unsolvable_goal_fails) :-
    run_client(Lines),
    memberchk("unsolvable goal failed, as it should", Lines).

%   A data solvable declared on the facilitator with address(parent) is a
%   blackboard: one agent writes it, another reads it, and neither knows the
%   other exists.  Developer's Guide 5.2 and 7.7.
%   A compound goal is one request the Facilitator takes apart and delegates
%   piece by piece.  Variables shared between conjuncts join them, so a
%   conjunct that depends on an earlier one is dispatched only after that one
%   has returned.  Developer's Guide 4.3.
test(compound_goal_chains_through_two_delegations) :-
    run_program('/examples/multi-agent/compound_client.pl', Lines),
    memberchk("chained: 3 -> 9 -> 81", Lines).

test(compound_goal_spans_agents) :-
    run_program('/examples/multi-agent/compound_client.pl', Lines),
    memberchk("cross-agent pairs: 3", Lines).

test(disjunction_takes_both_branches) :-
    run_program('/examples/multi-agent/compound_client.pl', Lines),
    memberchk("disjunction: [25,36]", Lines).

%   An unsolvable conjunct prunes everything after it, rather than hanging.
test(failing_conjunct_prunes) :-
    run_program('/examples/multi-agent/compound_client.pl', Lines),
    memberchk("failing conjunct pruned the request", Lines).

test(blackboard_is_shared) :-
    run_program('/examples/multi-agent/reporter.pl', Lines),
    memberchk("observations: 2", Lines),
    memberchk("temperature = 21", Lines),
    memberchk("humidity = 40", Lines).

:- end_tests(community).
