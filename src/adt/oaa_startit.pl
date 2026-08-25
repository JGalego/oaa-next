/*  oaa-next -- Start-It, the execution manager
 *
 *  Provenance: RECONSTRUCTED.
 *  Developer's Guide v2.3.2 section 3.4 and OAA v2.x FAQ section 2.6.
 *
 *  The Guide's account of what it is for: because of the heterogeneity of
 *  implementation languages, platforms and origins likely among the agents of
 *  a system, there is a fair amount of complexity in starting a system and
 *  keeping it running.  Start-It invokes each agent on the correct platform,
 *  ensures it connects to a facilitator, monitors it, and restarts it if it
 *  fails.
 *
 *  A community is described by a file of facts:
 *
 *      facilitator(Options).
 *      agent(Name, Command, Args).
 *
 *  Options and Args are lists of atoms passed through to the process.  The
 *  facilitator is started first and its address written to a setup file,
 *  because the Guide is explicit that a facilitator must be listening before
 *  any of its clients try to connect.
 */

:- module(oaa_startit,
          [ startit_main/0,
            startit_run/1,              % +CommunityFile
            startit_stop/0
          ]).

:- use_module(library(process)).
:- use_module('../runtime/oaa_config').

:- dynamic running/3.           % Name, PID, Spec
:- dynamic stopping/0.

startit_main :-
    current_prolog_flag(argv, Argv),
    (   member(File, Argv), exists_file(File)
    ->  startit_run(File)
    ;   format(user_error, "usage: oaa-startit <community-file>~n", []),
        halt(2)
    ).

%!  startit_run(+CommunityFile) is det.

startit_run(File) :-
    retractall(stopping),
    read_community(File, Facts),
    working_directory(Cwd, Cwd),
    start_facilitator(Facts, Cwd, Setup),
    forall(member(agent(Name, Cmd, Args), Facts),
           start_agent(Name, Cmd, Args, Cwd, Setup)),
    format("startit: community up; monitoring~n", []),
    supervise.

read_community(File, Facts) :-
    setup_call_cleanup(
        open(File, read, Stream),
        read_facts(Stream, Facts),
        close(Stream)).

read_facts(Stream, Facts) :-
    read_term(Stream, T, []),
    (   T == end_of_file
    ->  Facts = []
    ;   Facts = [T|Rest],
        read_facts(Stream, Rest)
    ).

start_facilitator(Facts, Cwd, Setup) :-
    (   member(facilitator(Options), Facts) -> true ; Options = [] ),
    atomic_list_concat([Cwd, '/setup.pl'], Setup),
    repo_script('/bin/facilitator.pl', Script),
    append(Options, ['-write_setup_file', Setup], FacArgs),
    launch(facilitator, swipl, [Script, '--'|FacArgs], Cwd,
           spec(swipl, [Script, '--'|FacArgs], Cwd)),
    wait_for_file(Setup, 100).

start_agent(Name, Cmd, Args, Cwd, _Setup) :-
    resolve_command(Cmd, Exe, Prefix),
    append(Prefix, Args, FullArgs),
    launch(Name, Exe, FullArgs, Cwd, spec(Exe, FullArgs, Cwd)).

%   A `.pl` command is run under swipl; anything else is executed directly,
%   which is how a community of agents written in different languages is
%   started by one manager.

resolve_command(Cmd, swipl, [Script, '--']) :-
    atom_concat(_, '.pl', Cmd), !,
    absolute_file_name(Cmd, Script).
resolve_command(Cmd, Cmd, []).

repo_script(Relative, Script) :-
    source_file(repo_script(_, _), File),
    file_directory_name(File, AdtDir),
    file_directory_name(AdtDir, SrcDir),
    file_directory_name(SrcDir, Root),
    atomic_list_concat([Root, Relative], Script).

launch(Name, Exe, Args, Cwd, Spec) :-
    catch(process_create(path(Exe), Args, [cwd(Cwd), process(PID)]),
          E,
          ( format(user_error, "startit: cannot start ~w: ~w~n", [Name, E]),
            fail )),
    assertz(running(Name, PID, Spec)),
    format("startit: started ~w~n", [Name]).

wait_for_file(_, 0) :- !,
    throw(error(facilitator_never_started, _)).
wait_for_file(File, N) :-
    (   exists_file(File), size_file(File, S), S > 0
    ->  true
    ;   sleep(0.1), N1 is N - 1, wait_for_file(File, N1)
    ).

%   Watch the agents and restart any that stop unexpectedly.  The Guide gives
%   this as Start-It's second job, and of equal importance to the first.

supervise :-
    (   stopping
    ->  true
    ;   sleep(1),
        forall(running(Name, PID, Spec), check(Name, PID, Spec)),
        supervise
    ).

check(Name, PID, Spec) :-
    (   process_wait(PID, Status, [timeout(0)]),
        Status \== timeout
    ->  format("startit: ~w exited (~w); restarting~n", [Name, Status]),
        retract(running(Name, PID, Spec)),
        Spec = spec(Exe, Args, Cwd),
        ignore(launch(Name, Exe, Args, Cwd, Spec))
    ;   true
    ).

startit_stop :-
    assertz(stopping),
    forall(retract(running(_, PID, _)),
           ( catch(process_kill(PID, term), _, true),
             catch(process_wait(PID, _, [timeout(2)]), _, true) )).
