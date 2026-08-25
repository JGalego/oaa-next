/*  oaa-next -- creating a new agent
 *
 *  Provenance: RECONSTRUCTED.
 *  Developer's Guide v2.3.2 section 9.1 lists the basic steps of implementing
 *  an agent; Martin, Cheyer & Lee's PAAM'96 paper describes the historical
 *  Agent Development Toolkit around them.
 *
 *  The generated skeleton follows those steps in order, so that a developer
 *  reading it meets the same sequence the Guide sets out: decide the
 *  solvables, define a callback for each procedure solvable, connect,
 *  register, run the event loop.
 */

:- module(oaa_new_agent,
          [ new_agent_main/0,
            new_agent/3                 % +Name, +File, +Options
          ]).

new_agent_main :-
    current_prolog_flag(argv, Argv),
    (   Argv = [NameArg|Rest]
    ->  atom_string(Name, NameArg),
        ( Rest = [F|_] -> atom_string(File, F)
        ; format(atom(File), "~w.pl", [Name]) ),
        new_agent(Name, File, []),
        format("wrote ~w~n", [File])
    ;   format(user_error, "usage: oaa-new-agent <name> [file]~n", []),
        halt(2)
    ),
    halt(0).

%!  new_agent(+Name, +File, +Options) is det.

new_agent(Name, File, _Options) :-
    src_dir(Src),
    skeleton(Name, Src, Text),
    setup_call_cleanup(
        open(File, write, S),
        write(S, Text),
        close(S)).

%   The skeleton points at the oaa-next source tree this generator was run
%   from, so a generated agent runs without any further configuration.

src_dir(Src) :-
    source_file(src_dir(_), File),
    file_directory_name(File, AdtDir),
    file_directory_name(AdtDir, Src).

skeleton(Name, Src, Text) :-
    format(atom(Text),
"#!/usr/bin/env swipl
/*  ~w -- an OAA agent
 *
 *  Built from the steps in the OAA Developer's Guide, section 9.1.
 */

:- use_module('~w/agents/oaa_run').
:- use_module('~w/agents/oaa_agent').

%   1.  Decide what services this agent provides.  A goal template, optional
%       parameters and optional permissions; the parameters name the callback
%       that implements it and may constrain the argument types.
solvables([ solvable(~w_greet(_Who, _Greeting),
                     [ callback(greet),
                       argspecs(in(string, true), out(string, true)) ],
                     []) ]).

%   2.  Implement each procedure solvable.  A callback receives the incoming
%       goal and a parameter list, and returns solutions by binding and by
%       backtracking -- succeeding more than once returns more than one
%       solution.
greet(~w_greet(Who, Greeting), _Params) :-
    format(atom(Greeting), \"Hello, ~~w\", [Who]).

%   3.  Connect, register and run the event loop.  The facilitator's address
%       comes from the command line, the environment or a setup file, in that
%       order, so nothing here names a host or a port.
:- initialization(run, main).

run :-
    solvables(S),
    oaa_agent_run(~w, S, []).
", [Name, Src, Src, Name, Name, Name]).
