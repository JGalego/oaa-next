# Tasking

"Tasking" covers what happens between asking for something and having an
answer: blocking versus non-blocking requests, work that completes later
than the call that started it, and triggers that fire when a condition
becomes true rather than being polled for. None of it changes what a goal
means — only when and how its answer arrives.

## Blocking is the default

`oaa_Solve(Goal, Params)` behaves like `call/1` by default: the caller
blocks until at least one solution arrives (or the request fails, or
`time_limit` expires), and can backtrack for more. `blocking(false)` returns
immediately with a goal ID instead, and the eventual solutions arrive as an
`ev_solved` event the caller's own event loop picks up. `reply(none)`
overrides both — a fire-and-forget request that expects no answer at all
(Developer's Guide §6.15's stated precedence: `reply(none)` beats
`blocking(true)`, which beats `parallel_ok(false)`).

## Strategy macros

Three parameter combinations are named because they come up constantly:

| Strategy | Expands to | Use |
|---|---|---|
| `strategy(query)` | `parallel_ok(true)` | Gather every answer from every matching agent |
| `strategy(action)` | `parallel_ok(false), solution_limit(1)` | Have exactly one agent do something, once |
| `strategy(inform)` | `parallel_ok(true), reply(none)` | Tell the community something, expect nothing back |

## Delayed solutions

An agent that cannot answer synchronously — because it has to consult a
slower resource, say — can accept a request, return control to its own
event loop, and supply the answer later: `oaa_DelaySolution(Id)` marks the
goal as pending, `oaa_AddDelayedContextParams/3` attaches whatever context
the eventual answer will need, and `oaa_ReturnDelayedSolutions(Id,
Solutions)` supplies it when ready. To the original requester this is
invisible — the reply arrives exactly as if it had been synchronous
(Developer's Guide §5.4).

## Event priority

Every event carries a priority, 1–10, default 5 (`event_priority/2` in
`src/runtime/oaa_event.pl`, read from a `priority/1` parameter where
present). While an agent is blocked inside a nested wait — waiting on a
reply to its own request, say — an arriving event at or below that floor
stays queued for the outer loop, while one above the floor is dispatched
immediately, interrupting. This is what lets a high-priority event reach
its handler even while the agent is otherwise occupied waiting on something
of its own (Developer's Guide §5.5).

## Triggers as the asynchronous primitive

Where a delayed solution answers one specific request later, a trigger
answers many future occurrences of a condition, indefinitely. Task triggers
are the deliberately asymmetric case: the library does not check a task
trigger's condition at all — application code notices it by whatever means
suit the domain and calls `oaa_CheckTriggers/3` once it holds. This differs
from OAA 1.x, where the library did check conditions, and the change is
recorded rather than silently followed (Developer's Guide §8.3). Full
treatment of all four trigger kinds is in [`triggers.md`](triggers.md).
