/*  oaa-next -- the Debug agent
 *
 *  Provenance: RECONSTRUCTED.
 *  OAA v2.x FAQ section 2.6: "A generic user interface that lets a programmer
 *  send messages to the agent community using either ICL or natural
 *  language."
 *
 *  The historical Debug agent shipped in two builds, one in Java and one in C
 *  over FLTK, described as functionally equivalent.  This one is a terminal
 *  REPL, which is a deliberate modernization: the value was always in
 *  reaching the community by hand, not in the widgets.
 *
 *  Natural-language input is not implemented.  Historically it was passed to
 *  a natural-language agent in the community rather than parsed by Debug
 *  itself, so an OAA-shaped answer here is to let a community that has such
 *  an agent handle it -- which is what happens if you type a goal it declares.
 */

:- module(oaa_debug,
          [ debug_main/0,
            debug_loop/0
          ]).

:- use_module('../icl/icl_term').
:- use_module('../agents/oaa_run').
:- use_module('../agents/oaa_agent').
:- use_module('../runtime/oaa_event').

debug_main :-
    oaa_agent_start(oaa_debug, [], []),
    banner,
    debug_loop,
    halt(0).

banner :-
    format("oaa-next debug interface.  Type an ICL goal, or:~n"),
    format("  :agents          list the community~n"),
    format("  :solvables       list every declared capability~n"),
    format("  :triggers        list this agent's installed triggers~n"),
    format("  :quit~n~n").

debug_loop :-
    format("icl> "), flush_output,
    read_line_to_string(user_input, Line),
    (   Line == end_of_file ; Line == ":quit"
    ->  true
    ;   handle_line(Line),
        debug_loop
    ).

handle_line("") :- !.
handle_line(":agents") :- !,
    show(agent_data(Id, _Type, Status, _Solvables, Name, _Info),
         [Id, Name, Status], "~w  ~w  (~w)~n").
handle_line(":solvables") :- !,
    forall(oaa_solve(agent_data(Id, _, _, Solvables, Name, _),
                     [address(parent), time_limit(10)]),
           ( format("~w ~w:~n", [Id, Name]),
             forall(member(S, Solvables),
                    ( icl_term_string(S, Str), format("    ~w~n", [Str]) )) )).
handle_line(":triggers") :- !,
    forall(oaa_solve(oaa_trigger(T, C, A, _P, _I), [address(self)]),
           ( icl_term_string(t(T, C, A), Str), format("  ~w~n", [Str]) )).
handle_line(Line) :-
    (   icl_parse_term(Line, Goal)
    ->  ask(Goal)
    ;   format("not a well-formed ICL goal~n", [])
    ).

ask(Goal) :-
    findall(Goal, oaa_solve(Goal, [time_limit(30)]), Solutions),
    (   Solutions == []
    ->  format("no.~n", [])
    ;   forall(member(S, Solutions),
               ( icl_term_string(S, Str), format("  ~w~n", [Str]) ))
    ).

show(Pattern, Args, Format) :-
    forall(oaa_solve(Pattern, [address(parent), time_limit(10)]),
           format(Format, Args)).
