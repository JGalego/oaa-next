/*  oaa-next -- running an agent
 *
 *  Provenance: RECONSTRUCTED.
 *  Developer's Guide v2.3.2 section 9.1, "Basic Steps".
 */

:- module(oaa_run,
          [ oaa_agent_start/3,          % +Name, +Solvables, +Options
            oaa_agent_run/3,            % +Name, +Solvables, +Options
            oaa_agent_loop/0
          ]).

:- use_module('../runtime/com_tcp').
:- use_module('../runtime/oaa_event').
:- use_module('../runtime/oaa_config').
:- use_module(oaa_agent).

/** <module> Starting an agent

The Developer's Guide lists the basic steps of implementing an agent: decide
the solvables, include the library, optionally override the default behaviours
and register callbacks, install any triggers, define a callback for each
procedure solvable, call com_Connect, call oaa_Register, and start the event
loop with oaa_MainLoop.

oaa_agent_start/3 performs the last three, which are the same for every agent.
Options:

  * address(tcp(Host, Port)) -- the facilitator; resolved from the command
    line, the environment and the setup file when absent
  * timeout(Seconds)         -- the polling delay that drives app_idle
*/

%!  oaa_agent_start(+Name, +Solvables, +Options) is det.
%
%   Connect and register, but do not enter the loop.  Useful when the caller
%   wants to drive the loop itself.

oaa_agent_start(Name, Solvables, Options) :-
    (   memberchk(address(Addr), Options)
    ->  true
    ;   oaa_facilitator_address(Addr)
    ->  true
    ;   throw(oaa_error(no_facilitator_address))
    ),
    oaa_connect([address(Addr)], _),
    (   memberchk(timeout(T), Options)
    ->  oaa_set_timeout(T)
    ;   true
    ),
    oaa_register(parent, Name, Solvables, []).

%!  oaa_agent_run(+Name, +Solvables, +Options) is det.
%
%   Connect, register and run the event loop until the agent disconnects.

oaa_agent_run(Name, Solvables, Options) :-
    oaa_agent_start(Name, Solvables, Options),
    (   memberchk(once(true), Options)
    ->  oaa_main_loop([handler(oaa_agent:oaa_handle_event), once(true)])
    ;   oaa_agent_loop
    ).

%!  oaa_agent_loop is det.
%
%   Run the event loop with the agent library's event handler installed.  An
%   agent that did its own setup -- declaring solvables on the facilitator,
%   installing triggers -- calls this instead of oaa_agent_run/3.

oaa_agent_loop :-
    oaa_main_loop([handler(oaa_agent:oaa_handle_event)]).
