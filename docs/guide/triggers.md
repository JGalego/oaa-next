# Triggers

A trigger says: when some condition is met, take some action. There are four
kinds, and they differ in what "condition" means and where the library
installs them by default (Developer's Guide §4.3.5, §8; `src/agents/oaa_trigger.pl`).

| Type | Condition form | Default placement | Checked by |
|---|---|---|---|
| `comm` | `event(FromToAgtId, Content, Params)` | self | library, on every send/receive |
| `data` | a data clause pattern | routed by the Facilitator | library, on every add/remove/replace |
| `task` | anything domain-specific | routed by the Facilitator | **application code**, via `oaa_CheckTriggers/3` |
| `time` | `time_expr(From, To, Recurrence)` | self (needs the Alarm agent) | the Alarm agent, not the library |

## Installing one

```prolog
oaa_add_trigger(Type, Condition, Action, Params)
```

`Params` may carry `on(What)` (which operations or directions select the
trigger), `test(Goal)` (an extra condition the trigger must also satisfy),
`recurrence(R)`, and `address(A)`. `oaa_remove_trigger/4` reverses it.

## Triggers are themselves data

Every installed trigger is recorded as an instance of a built-in, private
data solvable, `oaa_trigger/5`, so an agent can query its own installed
triggers with `oaa_Solve` exactly as it would query any other data
(`oaa_triggers/1`). Triggers and the data they watch share the same storage,
as they did in the historical design.

## Placement

Comm and time triggers default to `['self']`: they watch this agent's own
traffic, or need the Alarm agent addressed explicitly. Data and task
triggers with no address are routed by the Facilitator exactly like a
request. The condition is treated as a goal and matched against agents' data
or trigger-type solvables (Developer's Guide §8.2). A time trigger left at
its default address never fires. Agent libraries do not implement time
triggers; only the separate Alarm agent does, and it must be addressed
explicitly.

## Comm triggers observe all traffic

A comm trigger's condition, `event(From, Content, Params)`, is offered every
event this agent sends or receives, including a reply that
another part of the library is about to consume for its own purposes. This
includes `oaa_AddData/2`, which waits for its own `ev_data_updated`
reply internally (via `oaa_wait_for/3`) and never hands that event to the
ordinary dispatcher, so an `app_do_event` callback never sees it. A comm
trigger does, because `oaa_wait_for/3` notifies an `on_receive` hook the
moment it takes an event off the queue, before deciding what to do with it.
The agent library wires that hook straight to `oaa_note_event/3`. Only a comm
trigger lets an application observe the wire shape of a reply it triggered
itself. That is how the six-argument shape of `ev_data_updated` was
confirmed against SRI's own conformance tests
(`tests/compatibility/test_conformance.pl`,
`examples/multi-agent/data_client.pl`; see [`communication.md`](communication.md)).

## Data triggers

Fire when a data solvable is added to, removed from, or replaced.
`on(add)`, `on(remove)`, `on(replace)`, or a list, restricts which
operations select the trigger; an unbound condition matches every
modification of the watched solvable. Condition and action are copied
together (`copy_term(Cond-Action, Cond1-Action1)`) before matching, so
variables the condition binds are visible to the action. A `replace`
trigger naming `OldLocation` and `NewLocation` can use both in what it does
next.

## Task triggers

The 2.x library does not check a task trigger's condition. Application code
does so using whatever means fits the domain (a
poll, a callback from some other system, anything), followed by a call to
`oaa_CheckTriggers(Type, Condition, Params)` once the condition holds. This
is a documented divergence from OAA 1.x, where the library did check
conditions itself (Developer's Guide §8.3). An agent that offers a
trigger-type solvable is told a task trigger was installed on it via the
`app_setup_trigger` callback, so it can set up whatever machinery it needs
to eventually notice the condition.

## Time triggers

Time triggers are not part of any agent library, historically or here. A
separate Alarm agent supplies them, and they exist only while it is connected.
`time_expr(From, To, Recurrence)` uses C `struct tm`-style dates,
`date(YearLess1900, MonthLess1, Day, Hour, Min, Sec)`
(Developer's Guide §4.3.5). `src/agents/oaa_time.pl` handles conversion to
and from Unix time with modern date libraries. This replaces `struct tm`
arithmetic without changing the architecture.

## Recurrence

`recurrence(when)` (the default) fires once and removes itself;
`recurrence(whenever)` fires every time the condition matches; a positive
integer fires that many times before removing itself.

## Actions

A trigger's action is an `oaa_Solve/1,2` or `oaa_Interpret/1,2` term. For
backwards compatibility with earlier libraries, it may also be a bare ICL goal,
treated as if wrapped in `oaa_Interpret`. Inside a trigger, `oaa_Solve`'s
`reply` parameter defaults to `none` rather than `true`, since a trigger
action is a notification and nobody is blocked waiting on its answer.
