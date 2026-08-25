/*  oaa-next -- harness for live multi-process community tests
 *
 *  An OAA agent is an ordinary software process, and each agent's
 *  declarations and data are its own.  Running a community inside one Prolog
 *  image would share state between agents and prove nothing about delegation,
 *  so these tests start real processes.
 */

:- module(community,
          [ start_community/2,          % +AgentScripts, -Handle
            start_hierarchy/3,          % +RootAgents, +NodeAgents, -Handle
            stop_community/1,           % +Handle
            run_program/3,              % +Handle, +Relative, -Lines
            run_program_at/4            % +Handle, +Which, +Relative, -Lines
          ]).

:- use_module(library(process)).
:- discontiguous stop_community/1.
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

%!  start_hierarchy(+RootAgents, +NodeAgents, -Handle) is det.
%
%   A root facilitator with a node facilitator beneath it, each with its own
%   agents.  A node facilitator is started by pointing it at a parent with
%   -oaa_connect; nothing else distinguishes it.

start_hierarchy(RootAgents, NodeAgents, hierarchy(Dir, PIDs, RootPort, NodePort)) :-
    repo_root(Root),
    tmp_file_stream(text, TmpFile, S), close(S), delete_file(TmpFile),
    make_directory(TmpFile),
    Dir = TmpFile,
    directory_file_path(Dir, 'root.pl', RootSetup),
    directory_file_path(Dir, 'node.pl', NodeSetup),

    spawn(Root, '/bin/facilitator.pl',
          ['-oaa_name', root, '-write_setup_file', RootSetup], Dir, RootPID),
    wait_for_file(RootSetup, 100),
    setup_port(RootSetup, RootPort),
    format(atom(RootAddr), "tcp(localhost,~w)", [RootPort]),

    spawn(Root, '/bin/facilitator.pl',
          ['-oaa_name', node, '-oaa_connect', RootAddr,
           '-write_setup_file', NodeSetup], Dir, NodePID),
    wait_for_file(NodeSetup, 100),
    setup_port(NodeSetup, NodePort),
    format(atom(NodeAddr), "tcp(localhost,~w)", [NodePort]),

    findall(P,
            ( member(Script, RootAgents),
              spawn(Root, Script, ['-oaa_connect', RootAddr], Dir, P) ),
            RootPIDs),
    findall(P,
            ( member(Script, NodeAgents),
              spawn(Root, Script, ['-oaa_connect', NodeAddr], Dir, P) ),
            NodePIDs),
    append([[RootPID, NodePID], RootPIDs, NodePIDs], PIDs),
    sleep(1.2).

setup_port(File, Port) :-
    read_file_to_string(File, S, []),
    split_string(S, ",", " ", Parts),
    last(Parts, PortPart),
    split_string(PortPart, ")", " ", [PortStr|_]),
    number_string(Port, PortStr).

stop_community(hierarchy(Dir, PIDs, _, _)) :- !,
    forall(member(PID, PIDs),
           ( catch(process_kill(PID, term), _, true),
             catch(process_wait(PID, _, [timeout(2)]), _, true) )),
    catch(delete_directory_and_contents(Dir), _, true).

%!  run_program_at(+Handle, +Which, +Relative, -Lines) is det.
%
%   Run a program attached to a named facilitator in a hierarchy.

run_program_at(hierarchy(Dir, _, RootPort, NodePort), Which, Relative, Lines) :-
    ( Which == root -> Port = RootPort ; Port = NodePort ),
    format(atom(Addr), "tcp(localhost,~w)", [Port]),
    repo_root(Root),
    atomic_list_concat([Root, Relative], Script),
    swipl_path(Swipl),
    process_create(Swipl, [Script, '--', '-oaa_connect', Addr],
                   [ cwd(Dir), stdout(pipe(Out)), stderr(null), process(PID) ]),
    read_string(Out, _, S),
    close(Out),
    process_wait(PID, _Status),
    split_string(S, "\n", " \t", Lines0),
    exclude(==(""), Lines0, Lines).
