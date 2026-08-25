# Agents

The OAA agent library defines what an agent is. The Developer's Guide uses
that definition, and `src/agents/` provides the
library: connect, register, declare solvables, request services, answer
requests, maintain data, disconnect. Nothing about being an agent requires
implementing any of that yourself.

## The library's shape

| Module | Responsibility |
|---|---|
| `oaa_agent.pl` | Connection, registration, `oaa_Solve`, data maintenance and event dispatch; the library surface most agent code calls |
| `oaa.pl` | OAA 2.3.2 mixed-case source-compatibility facade, including the complete historical public export surface |
| `oaa_solvable.pl` | Solvable normalization, matching, permission and parameter lookup |
| `oaa_data.pl` | The data store behind data solvables |
| `oaa_trigger.pl` | Trigger installation, condition matching, firing |
| `oaa_time.pl` | ICL date/time conversion for time triggers |
| `oaa_run.pl` | The convenience layer most agents actually call: `oaa_agent_start/3`, the main loop |

`fac.pl` uses this library too. A Facilitator is a client of the same API,
not a separate implementation.

## Minimal agent

```prolog
:- use_module('../../src/agents/oaa_run').

run :-
    oaa_agent_start(square_agent,
                    [solvable(square(In, Out), [], [])], []),
    oaa_agent_loop.

:- initialization(run, main).
```

`oaa_agent_start/3` connects, registers the given solvables, and installs
the default event handler; `oaa_agent_loop/0` runs the library's main loop,
dispatching incoming goals to whatever the agent's own code registered as
callbacks (`app_do_event`, or a solvable's own `callback` parameter).

## Requesting services

`oaa_solve/2` is the one entry point for asking anything of the community,
whether the answer comes from a procedure or from data. The Developer's Guide
§4.3.3 also defines `oaa_Solve` as covering both. It behaves like
Prolog's `call/1`: it can fail, succeed once, or backtrack over solutions
from every matching agent, and the requester never learns which agent
answered unless it asks for that explicitly via `get_address` /
`get_satisfiers`.

Advice parameters shape the request without changing its meaning:
`address`, `solution_limit`, `provider_limit`, `blocking`, `reply`,
`parallel_ok`, `time_limit`, and more. The full set is in
[`api-reference.md`](api-reference.md) and
[`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md).
Three combinations are common enough to have names: `strategy(query)` is
`parallel_ok(true)`; `strategy(action)` is `parallel_ok(false),
solution_limit(1)`; `strategy(inform)` is `parallel_ok(true), reply(none)`.

## Maintaining data

`oaa_add_data/2`, `oaa_remove_data/2` and `oaa_replace_data/3` route the
same way `oaa_solve/2` does: with an `address` they go to the named agent;
without one, the Facilitator treats the clause as a goal and finds agents
providing a matching writable data solvable. See [`data.md`](data.md).

## Callbacks

The library calls back into agent code at fixed points, never the reverse,
so that an agent's own predicates stay in charge of what happens:
`app_do_event` for events the library doesn't handle itself,
`app_setup_trigger` when a task trigger is installed, `on_connect` /
`on_disconnect` for connection lifecycle, plus the internal
`trigger_solve` / `trigger_interpret` / `trigger_route` /`on_receive` hooks
that wire trigger actions and comm-trigger observation into the library.
Callbacks are registered module-qualified (`oaa_register_callback/2` is a
meta-predicate) precisely so a callback runs in the module that defined it,
not in the library module that stored it.

## Connecting and registering, the two steps

`com_Connect(parent, [], Address, ActualAddress)` opens the transport
connection; `oaa_Register(ConnId, Name, Solvables, Params)` performs the
historical handshake if `com_Connect` was called directly, then declares what
the agent offers. The handshake exchanges `ev_connect/1` and `ev_connected/1`
inside the wire's `event/2` envelope and assigns the client's full OAA address.
Keeping connection and registration separate (rather than one combined call)
preserves the historical two-step (Developer's Guide §9.1) and allows a
direct-connect listener to be opened between them.

New code may instead use lower-case `oaa_agent_start/3`; it performs the same
handshake, registration, and `ev_ready/1` transition. See
[`classic-compatibility.md`](classic-compatibility.md) for the complete
historical surface and compatibility boundary.

## The event loop

`oaa_MainLoop` polls the queue of arrived events and dispatches: events the
library itself understands (`ev_solve`, `ev_update_data`,
`ev_update_trigger`, `ev_connected`, `ev_reply_declared`, …) are handled without the agent ever
seeing them; anything else reaches `app_do_event`. Events carry a priority
(1–10, default 5); an event with priority above the one currently being
waited on interrupts, everything else queues for the outer loop
(Developer's Guide §5.5). See [`communication.md`](communication.md) for the
transport underneath this.
