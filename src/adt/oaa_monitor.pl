/*  oaa-next -- the Monitor agent
 *
 *  Provenance: RECONSTRUCTED.
 *  OAA v2.x FAQ section 2.6: "Monitor: graphically displays and records an
 *  agent community and their communications."
 *
 *  The historical Monitor drew the community; this one writes it to a
 *  terminal.  That is a modernization of the presentation, not of the
 *  mechanism: what it watches, and how it learns it, are unchanged.
 *
 *  Both halves of its job use ordinary OAA facilities and nothing else.  The
 *  community roster is a query against the Facilitator's agent_data/6 data
 *  solvable; the traffic is a communication trigger installed on the
 *  Facilitator, which is exactly what the Developer's Guide describes comm
 *  triggers as being for -- "whenever a solution to a goal is returned from
 *  the facilitator, send the result to the presentation manager to be
 *  displayed to the user".
 */

:- module(oaa_monitor,
          [ monitor_main/0
          ]).

:- use_module('../icl/icl_term').
:- use_module('../agents/oaa_run').
:- use_module('../agents/oaa_agent').
:- use_module('../agents/oaa_trigger').
:- use_module('../runtime/oaa_event').

solvables([ solvable(monitor_event(_Direction, _Peer, _Event),
                     [callback(oaa_monitor:show_event)], []) ]).

monitor_main :-
    solvables(S),
    oaa_agent_start(monitor, S, [timeout(1.0)]),
    watch_traffic,
    oaa_register_callback(app_idle, oaa_monitor:show_roster),
    format("monitor: watching the community~n~n", []),
    oaa_agent_loop.

%   Ask the Facilitator to report its traffic.  The trigger's condition binds
%   the peer and the event, and the action carries them back here.

watch_traffic :-
    oaa_add_trigger(comm,
                    event(Peer, Content, _P),
                    oaa_Solve(monitor_event(observed, Peer, Content), []),
                    [address(parent), recurrence(whenever)]).

show_event(monitor_event(_Direction, Peer, Event), _Params) :-
    icl_term_string(Event, Str),
    format("  ~w  ~w~n", [Peer, Str]).

%   The roster is a query like any other.  Printing it only when it changes
%   keeps an idle community quiet.

:- dynamic last_roster/1.

show_roster :-
    findall(Id-Name, connected_agent(Id, Name), Agents0),
    msort(Agents0, Agents),
    (   last_roster(Agents)
    ->  true
    ;   retractall(last_roster(_)),
        assertz(last_roster(Agents)),
        print_roster(Agents)
    ).

connected_agent(Id, Name) :-
    oaa_solve(agent_data(Id, _Type, ready, _Solvables, Name, _Info),
              [address(parent), time_limit(5)]).

print_roster(Agents) :-
    format("community:~n", []),
    forall(member(Id-Name, Agents), format("  ~w  ~w~n", [Id, Name])),
    nl.
