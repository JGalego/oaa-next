# The Facilitator

The Facilitator is the agent that holds a community together: it keeps a
live index of who can do what, matches incoming goals against that index,
orders and dispatches to candidates, and collects and relays results. It
does this as an ordinary agent, using the same library every client uses
(Developer's Guide §10.2). `src/facilitator/fac.pl` starts by declaring the
facilitator solvables and then runs the same event loop as
`src/agents/oaa_run.pl` gives anyone.

## The registry

Every registered agent is recorded in the data solvable
`agent_data(LocalId, Kind, Status, Solvables, Name, Info)`, which is
queryable through `oaa_Solve`. Registration
(`oaa_Register`) replaces the entry for a reconnecting agent rather than
duplicating it; a listener address recorded for direct connect lives
alongside it in `agent_listener/3`. See
[`../../research/implementation-notes/facilitator.md`](../../research/implementation-notes/facilitator.md)
§2 for the reasoning behind representing the registry as ordinary data
rather than a separate table.

## Matching, ordering, selecting

`fac_delegate.pl` keeps the pure selection logic separate from I/O:

- `fac_candidates/3` filters the registry to agents whose solvable templates
  unify with the goal.
- `fac_order/2` sorts candidates by descending declared utility, stable
  within a utility band (a keysort on `NegU-Pos`, not a plain sort, so equal
  utilities keep registration order).
- `fac_select/5` applies request parameters such as `solution_limit`,
  `provider_limit` and `address` to the ordered candidates.
- `fac_dispatch_plan/4` decides how to dispatch: one round for a simple
  goal, one step of a branch walk for a compound one.

Its separation from `fac.pl`'s connection handling allows tests to run
without a live community. See `tests/facilitator/test_delegate.pl`.

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

Both are consulted through the ordinary reply-tag mechanism used for any
delegated goal. A facilitator therefore does not deadlock on an agent that
is itself waiting on the facilitator (see
[`../../research/implementation-notes/facilitator.md`](../../research/implementation-notes/facilitator.md)
§5a). Some design material also describes `plan_query` and `execute_plan`,
which would let a meta-agent take over compound-goal routing entirely. A
source audit found that the recovered 2.3.2 Facilitator only dispatches
`lookup` and `prioritize`; those two therefore define implementation parity.

## Reply tags and continuations

A naive Facilitator that blocks on each leg of a request deadlocks the
moment two agents wait on each other through it. `oaa-next` avoids this with
continuation-tagged replies: every outstanding request the Facilitator is
waiting on carries a `client(...)`, `compound(...)`, or `meta(...)` tag
recording what to do with the answer when it arrives, so the Facilitator's
own event loop never has to block inside a request handler. The same tags
serve compound goals and meta-agent consultation, avoiding separate
deadlock-handling paths.

## Hierarchies

Multiple Facilitators compose strictly as a tree, the only topology the
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
`time_limit` and `parallel_ok`. These historical restrictions remain in
place (Developer's Guide §10.1).

## Running one

```sh
swipl bin/facilitator.pl -- -write_setup_file setup.pl
```

writes its listening address to `setup.pl`, which is how agents started
without an explicit address find it (`oaa_config.pl`'s command line → env →
setup-file precedence, [`communication.md`](communication.md)).
