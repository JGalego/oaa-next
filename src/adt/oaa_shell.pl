/*  oaa-next -- the Shell agent
 *
 *  Provenance: RECONSTRUCTED.
 *  OAA v2.x FAQ section 2.6, which lists the shell agent among the support
 *  agents supplied with the distribution: "Send queries and messages to the
 *  agent community from the (Unix or DOS) command line."
 */

:- module(oaa_shell,
          [ shell_main/0,
            shell_solve/2               % +GoalText, +Options
          ]).

:- use_module('../icl/icl_term').
:- use_module('../agents/oaa_run').
:- use_module('../agents/oaa_agent').

/** <module> Command-line access to an agent community

Connects, asks one question, prints the answers and leaves.  Everything it
does an ordinary agent could do; the point is that a developer can do it
without writing one.
*/

shell_main :-
    current_prolog_flag(argv, Argv),
    (   goal_text(Argv, Text)
    ->  shell_solve(Text, Argv)
    ;   usage
    ),
    halt(0).

goal_text(Argv, Text) :-
    exclude(option_arg, Argv, Positional),
    Positional \== [],
    atomic_list_concat(Positional, ' ', Text).

option_arg(A) :- atom_concat('-', _, A), !.
option_arg(A) :- sub_atom(A, _, _, _, 'tcp('), !.

usage :-
    format(user_error,
           "usage: oaa-shell [-oaa_connect \"tcp(Host,Port)\"] <ICL goal>~n~c",
           [0'\n]).

%!  shell_solve(+GoalText, +Options) is det.

shell_solve(Text, _Options) :-
    (   icl_parse_term(Text, Goal)
    ->  true
    ;   format(user_error, "not a well-formed ICL goal: ~w~n", [Text]),
        halt(2)
    ),
    oaa_agent_start(oaa_shell, [], []),
    findall(Goal, oaa_solve(Goal, [time_limit(30)]), Solutions),
    (   Solutions == []
    ->  format("no.~n", [])
    ;   forall(member(S, Solutions),
               ( icl_term_string(S, Str), format("~w~n", [Str]) ))
    ).
