# Communication

Everything an agent or the Facilitator sends or receives is an ICL term
framed over TCP. The `com_`-prefixed module keeps the transport API separate
from the rest of the library (Developer's Guide §4.2). Historical OAA was
transport-independent by design, though TCP was the only implementation it
shipped. `oaa-next` keeps this boundary in `src/runtime/com_tcp.pl`.

## Framing

ICL terms are Prolog-like, ending in `.`, and the wire has to know where one
ends and the next begins without parsing the whole stream twice. `com_frame/3`
scans the byte stream for a period that ends a term. It tracks quote state so
a period inside a quoted string or atom doesn't end the term early, then
splits off complete terms as they arrive, leaving a remainder for the next
read. Terms may span multiple lines; only the trailing period, outside any
quote, ends one.

## Connections

`com_connect/3` opens a connection and returns the address that resulted
(useful when connecting to an unbound port); `com_listen_at/3` opens a
listener; `com_accept/2` accepts a pending connection on one. `com_send/2`
and `com_read/2` / `com_read_pending/2` move terms across an established
connection; `com_poll/3` waits across several connections at once and returns
those with input ready. The event loop's pump uses this operation.

The same module exports the OAA 2.3.2 names (`com_Connect/3,4`,
`com_ListenAt/3,4`, `com_SendData/2`, `com_SelectEvent/2`, connection-info,
address, wakeup and shutdown predicates) for unchanged classic Prolog agents.
See [`classic-compatibility.md`](classic-compatibility.md).

## The event queue

Incoming terms are enqueued (`oaa_enqueue/2,3`) with a priority taken from a
`priority/1` parameter, or 5 by default. They are dequeued by
the main loop in priority order, oldest first within a priority band
(`oaa_dequeue/3`). `oaa_pump/1` is one turn: poll every open connection for
up to a timeout, accept anything pending on a listener, move whatever
arrived onto the queue. `oaa_wait_for/3` layers a nested wait for one
specific pattern on top of the same pump, respecting the priority-floor rule
from [`tasking.md`](tasking.md) so a genuinely urgent event can still
interrupt.

An event consumed by a nested `oaa_wait_for/3` never reaches the ordinary
dispatcher (`app_do_event`). The wait takes it directly off the queue without
handing it to `oaa_handle_event/2`. This happens when `oaa_add_data/2` waits
for its `ev_data_updated` reply. An `on_receive` hook inside the wait still
sees the event, and the agent library wires that hook to comm-trigger
observation. See [`triggers.md`](triggers.md).

## Wire envelope and handshake

Conversational content is not sent as a bare `ev_*` term. OAA 2.3.2 wraps
every message as `event(Content, EventParams).` on the TCP stream. The
transport decodes that envelope before handing content to the modern event
loop and creates it when modern code sends an `ev_*` term.

A client first sends `ev_connect(ClientInfo)` and receives
`ev_connected(FacilitatorInfo)`. The response assigns its full OAA address.
It then sends `ev_register_solvables(Mode, Solvables, Name, Params)` and
finally `ev_ready(Name)`. The open/ready distinction ensures a client does not
receive delegated requests before startup is complete. Password validation
and unique-name policy are part of this handshake.

## Wire events

The conversational layer's vocabulary, as ICL terms with a parameter list:

| Event | Shape | Meaning |
|---|---|---|
| `ev_solve` | `ev_solve(GoalId, Goal, Params)` | A goal to solve |
| `ev_solved` | `ev_solved(GoalId, Requestees, Solvers, Goal, Params, Solutions)` | The answer |
| `ev_update_data` | `ev_update_data(GoalId, Mode, Payload, Params)` | Add/remove/replace a data clause |
| `ev_data_updated` | `ev_data_updated(GoalId, Mode, Payload, Params, Requestees, Updaters)` | The historical six-argument reply to a data update |
| `ev_update_trigger` | `ev_update_trigger(GoalId, Mode, Type, Condition, Action, Params)` | Install/remove a trigger, possibly on another agent |
| `ev_trigger_updated` | `ev_trigger_updated(GoalId, Mode, Type, Condition, Action, Params, Requestees, Updaters)` | Trigger update reply |
| `ev_connect` / `ev_connected` | `ev_connect(Info)` / `ev_connected(Info)` | Historical connection handshake |
| `ev_register_solvables` | `ev_register_solvables(Mode, Solvables, Name, Params)` | Add, remove, or replace advertised capabilities |
| `ev_ready` | `ev_ready(Name)` | Change an agent from open to ready |
| `ev_post_declare` / `ev_reply_declared` | Three/four arguments respectively | Remote declaration and acknowledgement |
| `ev_heartbeat` / `ev_heartbeat_reply` | Atoms | Liveness exchange accepted by classic peers |

`ev_registered/2` remains accepted only as a migration extension for early
oaa-next peers. It is not the OAA 2.3.2 registration acknowledgement; the
historical handshake assigns the address in `ev_connected/1`.

`Goal` in `ev_solved` is a fresh variable by default from 2.3.2 onward
(pre-2.3.2 echoed the actual goal); `-return_goal_with_solutions` restores
the older behaviour. Goal IDs are generated client-side and, from 2.3.2,
randomised to avoid collisions across reconnects. Both behaviours are
preserved here as documented
(`doc/history.txt`, cited in
[`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md)).

## Configuration

`oaa_config.pl` resolves settings in this order: command line, environment
variables, then a setup file. This matches the Developer's Guide's
own ordering (§4.6). The setup file is Prolog syntax
(`default_facilitator(tcp(Host, Port))`, preferred there over calling
`oaa_connect` directly in a file multiple agents share). `oaa_mode/1`
resolves `OAA_CLASSIC` (default) or `OAA_LLM` through the same precedence
chain. See [`llm-agents.md`](llm-agents.md) for what that mode gates.
`-on_port_exception` controls what happens when a requested port is taken:
`exit`, `try_again`, `next_highest`, `change_port`, or `any_available`
(Developer's Guide §4.6.2).
