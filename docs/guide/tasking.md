# Tasking

"Tasking" covers what happens between asking for something and having an
answer: blocking versus non-blocking requests, work that completes later
than the call that started it, and triggers that fire when a condition
becomes true rather than being polled for. None of it changes what a goal
means. It changes only when and how the answer arrives.

## Blocking is the default

`oaa_Solve(Goal, Params)` behaves like `call/1` by default: the caller
blocks until at least one solution arrives (or the request fails, or
`time_limit` expires), and can backtrack for more. `blocking(false)` returns
immediately with a goal ID instead, and the eventual solutions arrive as an
`ev_solved` event the caller's own event loop picks up. `reply(none)`
overrides both and makes a fire-and-forget request that expects no answer
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

An agent that must consult a slower resource can accept a request without
answering synchronously, return control to its own event loop, and supply
the answer later: `oaa_DelaySolution(Id)` marks the
goal as pending, `oaa_AddDelayedContextParams/3` attaches whatever context
the eventual answer will need, and `oaa_ReturnDelayedSolutions(Id,
Solutions)` supplies it when ready. The requester sees no difference: the
reply arrives as if it had been synchronous
(Developer's Guide §5.4).

## Event priority

Every event carries a priority, 1–10, default 5 (`event_priority/2` in
`src/runtime/oaa_event.pl`, read from a `priority/1` parameter where
present). While an agent is blocked inside a nested wait for a reply to its
own request, an arriving event at or below that floor stays queued for the
outer loop, while one above the floor is dispatched
immediately, interrupting. A high-priority event can therefore reach its
handler while the agent waits on its own request (Developer's Guide §5.5).

## Triggers as the asynchronous primitive

Where a delayed solution answers one specific request later, a trigger
answers many future occurrences of a condition, indefinitely. Task triggers
work differently: the library does not check a task trigger's condition.
Application code notices it by whatever means suit the domain and calls
`oaa_CheckTriggers/3` once it holds. This differs
from OAA 1.x, where the library did check conditions, and the change is
recorded rather than silently followed (Developer's Guide §8.3). Full
treatment of all four trigger kinds is in [`triggers.md`](triggers.md).
