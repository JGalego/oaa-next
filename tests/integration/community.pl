/*  oaa-next -- harness for live multi-process community tests
 *
 *  An OAA agent is an ordinary software process, and each agent's
 *  declarations and data are its own.  Running a community inside one Prolog
 *  image would share state between agents and prove nothing about delegation,
 *  so these tests start real processes.
 */

:- module(community,
          [ start_community/2,          % +AgentScripts, -Handle
            stop_community/1,           % +Handle
            run_program/3               % +Handle, +Relative, -Lines
          ]).

:- use_module(library(process)).
:- use_module(library(filesex)).

repo_root(Root) :-
    source_file(repo_root(_), File),
    file_directory_name(File, TestDir),
    file_directory_name(TestDir, TestsDir),
    file_directory_name(TestsDir, Root).

swipl_path(Path) :-
    (   absolute_file_name(path(swipl), Path,
                           [access(execute), file_errors(fail)])
    ->  true
    ;   Path = '/usr/bin/swipl'
    ).

%!  start_community(+AgentScripts, -Handle) is det.
%
%   Start a Facilitator and the given agents, each in its own process, in a
%   fresh working directory.  The Facilitator writes its address to setup.pl
%   there, which is how the agents find it.

start_community(AgentScripts, community(Dir, PIDs)) :-
    repo_root(Root),
    tmp_file_stream(text, TmpFile, S), close(S), delete_file(TmpFile),
    make_directory(TmpFile),
    Dir = TmpFile,
    directory_file_path(Dir, 'setup.pl', Setup),
    spawn(Root, '/bin/facilitator.pl', ['-write_setup_file', Setup], Dir, FacPID),
    wait_for_file(Setup, 100),
    findall(PID,
            ( member(Script, AgentScripts),
              spawn(Root, Script, [], Dir, PID) ),
            AgentPIDs),
    PIDs = [FacPID|AgentPIDs],
    %  Long enough for the agents to connect and register; the programs run
    %  against the community wait for the capabilities they need.
    sleep(0.8).

spawn(Root, Relative, Args, Cwd, PID) :-
    atomic_list_concat([Root, Relative], Script),
    swipl_path(Swipl),
    process_create(Swipl, [Script, '--'|Args],
                   [ cwd(Cwd), process(PID), stdout(null), stderr(null) ]).

wait_for_file(_, 0) :- !, throw(error(facilitator_never_started, _)).
wait_for_file(File, N) :-
    (   exists_file(File), size_file(File, Size), Size > 0
    ->  true
    ;   sleep(0.1), N1 is N - 1, wait_for_file(File, N1)
    ).

stop_community(community(Dir, PIDs)) :-
    forall(member(PID, PIDs),
           ( catch(process_kill(PID, term), _, true),
             catch(process_wait(PID, _, [timeout(2)]), _, true) )),
    catch(delete_directory_and_contents(Dir), _, true).

%!  run_program(+Handle, +Relative, -Lines) is det.
%
%   Run a one-shot agent against the community and collect what it printed.

run_program(community(Dir, _), Relative, Lines) :-
    repo_root(Root),
    atomic_list_concat([Root, Relative], Script),
    swipl_path(Swipl),
    process_create(Swipl, [Script, '--'],
                   [ cwd(Dir), stdout(pipe(Out)), stderr(null), process(PID) ]),
    read_string(Out, _, S),
    close(Out),
    process_wait(PID, _Status),
    split_string(S, "\n", " \t", Lines0),
    exclude(==(""), Lines0, Lines).
