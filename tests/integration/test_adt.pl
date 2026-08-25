/*  oaa-next -- Agent Development Toolkit tests
 *
 *  The ADT is what a developer uses to build and run a community: a generator
 *  for new agents, a command-line way into a running one, an interactive
 *  interface, an execution manager, and a monitor.
 */

:- module(test_adt, []).

:- use_module(community).
:- use_module('../../src/adt/oaa_new_agent').

:- begin_tests(adt_generator).

%   Developer's Guide 9.1: the generated skeleton follows the documented
%   steps, and runs without further configuration.
test(generates_a_loadable_agent,
     [setup(tmp_file(agent, F)), cleanup(catch(delete_file(F), _, true))]) :-
    new_agent(widget, F, []),
    read_file_to_string(F, S, []),
    sub_string(S, _, _, _, "solvable(widget_greet"),
    sub_string(S, _, _, _, "oaa_agent_run(widget"),
    sub_string(S, _, _, _, "oaa_run"),
    %  It has to be syntactically valid Prolog, or the developer's first act
    %  is fixing our template.
    catch(once(read_terms(F, Terms)), _, fail),
    Terms \== [].

%   A generated agent starts with a shebang line, which a Prolog reader will
%   not accept; SWI-Prolog skips it only when loading a file as a script.
read_terms(File, Terms) :-
    setup_call_cleanup(
        open(File, read, S),
        ( skip_shebang(S), read_all(S, Terms) ),
        close(S)).

skip_shebang(S) :-
    peek_char(S, C),
    (   C == '#'
    ->  read_line_to_string(S, _)
    ;   true
    ).

read_all(S, Terms) :-
    read_term(S, T, []),
    (   T == end_of_file
    ->  Terms = []
    ;   Terms = [T|R],
        read_all(S, R)
    ).

:- end_tests(adt_generator).


:- begin_tests(adt_tools,
               [ setup(( start_community(['/examples/basic/square_agent.pl'], C),
                         nb_setval(adt, C) )),
                 cleanup(( nb_getval(adt, C), stop_community(C) )) ]).

%   The shell agent asks one question from the command line and leaves.
test(shell_answers_a_goal) :-
    nb_getval(adt, C),
    run_with_args(C, '/bin/oaa-shell.pl', ['square(9, X)'], Lines),
    memberchk("square(9,81)", Lines).

test(shell_reports_no_solution) :-
    nb_getval(adt, C),
    run_with_args(C, '/bin/oaa-shell.pl', ['nothing_provides_this(X)'], Lines),
    memberchk("no.", Lines).

%   can_solve is how an agent finds a peer, and the shell reaches it like any
%   other goal.
test(shell_can_query_the_registry) :-
    nb_getval(adt, C),
    run_with_args(C, '/bin/oaa-shell.pl', ['can_solve(square(1,_), A)'], Lines),
    Lines = [Line|_],
    once(sub_string(Line, _, _, _, "can_solve(square(")).

:- end_tests(adt_tools).

%   Running a tool with arguments, which run_program/3 does not cover.
run_with_args(community(Dir, _), Relative, Args, Lines) :-
    absolute_file_name('.', Here),
    file_directory_name(Here, _),
    community:repo_root(Root),
    atomic_list_concat([Root, Relative], Script),
    community:swipl_path(Swipl),
    append([Script, '--'], Args, Argv),
    process_create(Swipl, Argv,
                   [ cwd(Dir), stdout(pipe(Out)), stderr(null), process(PID) ]),
    read_string(Out, _, S),
    close(Out),
    process_wait(PID, _),
    split_string(S, "\n", " \t", L0),
    exclude(==(""), L0, Lines).

:- use_module(library(process)).
