# Communication

Everything an agent or the Facilitator sends or receives is an ICL term,
framed over TCP, behind a transport API kept deliberately separate from the
rest of the library — the `com_`-prefixed module (Developer's Guide §4.2).
Preserving that seam is what let historical OAA claim transport
independence in principle even though TCP was, in practice, the only
transport shipped; `oaa-next` keeps the same boundary in `src/runtime/com_tcp.pl`.

## Framing

ICL terms are Prolog-like, ending in `.`, and the wire has to know where one
ends and the next begins without parsing the whole stream twice. `com_frame/3`
scans the byte stream for a period that ends a term — tracking quote state
so a period inside a quoted string or atom doesn't end the term early — and
splits off complete terms as they arrive, leaving a remainder for the next
read. Terms may span multiple lines; only the trailing period, outside any
quote, ends one.

## Connections

`com_connect/3` opens a connection and returns the address that resulted
(useful when connecting to an unbound port); `com_listen_at/3` opens a
listener; `com_accept/2` accepts a pending connection on one. `com_send/2`
and `com_read/2` / `com_read_pending/2` move terms across an established
connection; `com_poll/3` waits across several connections at once for
whichever have input ready, which is what the event loop's pump is built on.

## The event queue

Incoming terms are enqueued (`oaa_enqueue/2,3`) with a priority — from a
`priority/1` parameter if the term carries one, default 5 — and dequeued by
the main loop in priority order, oldest first within a priority band
(`oaa_dequeue/3`). `oaa_pump/1` is one turn: poll every open connection for
up to a timeout, accept anything pending on a listener, move whatever
arrived onto the queue. `oaa_wait_for/3` layers a nested wait for one
specific pattern on top of the same pump, respecting the priority-floor rule
from [`tasking.md`](tasking.md) so a genuinely urgent event can still
interrupt.

A consequence worth stating plainly: an event a nested `oaa_wait_for/3`
consumes never reaches the ordinary dispatcher (`app_do_event`), because it
was taken directly off the queue rather than handed to
`oaa_handle_event/2`. `oaa_add_data/2`'s own wait for its `ev_data_updated`
reply is exactly this case. What still sees it is an `on_receive` hook fired
from inside the wait itself, which the agent library wires to comm-trigger
observation — see [`triggers.md`](triggers.md).

## Wire events

The conversational layer's vocabulary, as ICL terms with a parameter list:

| Event | Shape | Meaning |
|---|---|---|
| `ev_solve` | `ev_solve(GoalId, Goal, Params)` | A goal to solve |
| `ev_solved` | `ev_solved(GoalId, Requestees, Solvers, Goal, Params, Solutions)` | The answer |
| `ev_update_data` | `ev_update_data(GoalId, Mode, Payload, Params)` | Add/remove/replace a data clause |
| `ev_data_updated` | `ev_data_updated(GoalId, Mode, Payload, Requestees, Solvers, Params)` | The reply to a data update — six arguments; settled against SRI's own OTML conformance corpus (`samples/test3/parallel.otml`), not assumed |
| `ev_update_trigger` | `ev_update_trigger(GoalId, Mode, Type, Condition, Action, Params)` | Install/remove a trigger, possibly on another agent |
| `ev_registered` | `ev_registered(LocalId, Address)` | Registration acknowledged |

`Goal` in `ev_solved` is a fresh variable by default from 2.3.2 onward
(pre-2.3.2 echoed the actual goal); `-return_goal_with_solutions` restores
the older behaviour. Goal IDs are generated client-side, randomised from
2.3.2 to avoid collisions across reconnects — both preserved here as
documented behaviour rather than convenience defaults
(`doc/history.txt`, cited in
[`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md)).

## Configuration

`oaa_config.pl` resolves settings by precedence — command line, then
environment variables, then a setup file — matching the Developer's Guide's
own ordering (§4.6). The setup file is Prolog syntax
(`default_facilitator(tcp(Host, Port))`, preferred there over calling
`oaa_connect` directly in a file multiple agents share). `oaa_mode/1`
resolves `OAA_CLASSIC` (default) or `OAA_LLM` through the same precedence
chain — see [`llm-agents.md`](llm-agents.md) for what that mode gates.
`-on_port_exception` controls what happens when a requested port is taken:
`exit`, `try_again`, `next_highest`, `change_port`, or `any_available`
(Developer's Guide §4.6.2).
