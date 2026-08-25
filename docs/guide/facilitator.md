# The Facilitator

The Facilitator is the agent that holds a community together: it keeps a
live index of who can do what, matches incoming goals against that index,
orders and dispatches to candidates, and collects and relays results. It
does this as an ordinary agent, using the same library every client uses
(Developer's Guide §10.2) — `src/facilitator/fac.pl` starts by declaring the
facilitator solvables and then runs the same event loop as
`src/agents/oaa_run.pl` gives anyone.

## The registry

Every registered agent is recorded as an instance of `agent_data/6`
(`agent_data(LocalId, Kind, Status, Solvables, Name, Info)`) — a data
solvable like any other, queryable through `oaa_Solve`. Registration
(`oaa_Register`) replaces the entry for a reconnecting agent rather than
duplicating it; a listener address recorded for direct connect lives
alongside it in `agent_listener/3`. See
[`../../research/implementation-notes/facilitator.md`](../../research/implementation-notes/facilitator.md)
§2 for the reasoning behind representing the registry as ordinary data
rather than a separate table.

## Matching, ordering, selecting

`fac_delegate.pl` is the pure selection logic, deliberately kept apart from
I/O:

- `fac_candidates/3` filters the registry to agents whose solvable templates
  unify with the goal.
- `fac_order/2` sorts candidates by descending declared utility, stable
  within a utility band (a keysort on `NegU-Pos`, not a plain sort, so equal
  utilities keep registration order).
- `fac_select/5` applies request parameters — `solution_limit`,
  `provider_limit`, `address`, and so on — to the ordered candidates.
- `fac_dispatch_plan/4` decides how to dispatch: one round for a simple
  goal, one step of a branch walk for a compound one.

Keeping this apart from `fac.pl`'s connection handling is what makes it
testable without a live community — see `tests/facilitator/test_delegate.pl`.

## Compound goals

A conjunction or disjunction is not routed as a single opaque request. The
Facilitator decomposes it and walks it breadth-first, one dispatch at a
time, so it is never blocked waiting on a slow agent while other agents in
the same conjunction sit idle (`fac_compound.pl`: `branch_step/2` produces a
`solution`, `expand`, or `dispatch` action per step; `branch_advance/3`
copies the branch per solution so parallel solutions to an earlier conjunct
don't interfere with each other). Variables shared between conjuncts bind
later conjuncts from earlier solutions, following ordinary logic-programming
semantics.

## Meta-agents

Two hooks let another agent influence delegation without the Facilitator
knowing anything about how that agent decides:

- **`prioritize`** — given the Facilitator's already-ordered candidate list,
  return a reordering.
- **`lookup`** — given a goal nothing local can solve, find or start an
  agent that can; selection repeats once one registers.

Both are consulted the same way any delegated goal is answered — through the
ordinary reply-tag mechanism below — which is what avoids a facilitator
deadlocking on an agent that is, in turn, waiting on the facilitator (see
[`../../research/implementation-notes/facilitator.md`](../../research/implementation-notes/facilitator.md)
§5a). `plan_query` and `execute_plan`, which would let a meta-agent take
over compound-goal routing entirely, remain deferred (see
[`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md)).

## Reply tags and continuations

A naive Facilitator that blocks on each leg of a request deadlocks the
moment two agents wait on each other through it. `oaa-next` avoids this with
continuation-tagged replies: every outstanding request the Facilitator is
waiting on carries a tag — `client(...)`, `compound(...)`, or `meta(...)` —
recording what to do with the answer when it arrives, so the Facilitator's
own event loop never has to block inside a request handler. This single
mechanism is what makes compound goals and meta-agent consultation both work
without a separate deadlock-avoidance path for each.

## Hierarchies

Multiple Facilitators compose strictly as a tree — the only topology the
library supports (Developer's Guide §10.2). A node facilitator is one
started with `oaa_connect` to a parent; it registers upward with the union
of its own clients' solvables, so downward reach needs no separate
propagation step and no federation protocol of its own. `propagate/1`
parameters (`up`, `down`, `up_limit`, `down_limit`) control whether and how
far a goal is referred beyond the immediate facilitator, defaulting to no
propagation.

## Direct connect

`direct_connect(true)` lets a requester and a single selected provider
exchange the goal and its solutions directly over a socket, bypassing the
Facilitator for message flow while the Facilitator still performs selection.
It requires the provider to have registered a listener address beforehand,
applies only to a single provider and a single facilitator, and ignores
`time_limit` and `parallel_ok` — all historical constraints, preserved here
rather than lifted (Developer's Guide §10.1).

## Running one

```sh
swipl bin/facilitator.pl -- -write_setup_file setup.pl
```

writes its listening address to `setup.pl`, which is how agents started
without an explicit address find it (`oaa_config.pl`'s command line → env →
setup-file precedence, [`communication.md`](communication.md)).
