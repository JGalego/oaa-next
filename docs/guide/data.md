# Data

A data solvable is, functionally, a relational table — but it is queried
and updated through exactly the same interface as any procedural
capability, which is the point: an agent asking for data doesn't need to
know whether the answer comes from a computation or a lookup (Developer's
Guide §7).

## Declaring one

```prolog
solvable(foo(_), [type(data), write(true)], [write(true)])
```

Note the permission quirk from [`capability-registration.md`](capability-registration.md):
an agent has to declare `write(true)` on its own data solvable to modify
it, the same as any other agent would need to.

## Querying

Through `oaa_Solve` — a data solvable's clauses match a goal by unification
exactly like a procedure's, and `oaa_Solve` backtracks over every matching
fact from every agent that provides one, subject to the usual advice
parameters.

## Maintaining

`oaa_AddData(Clause, Params)`, `oaa_RemoveData(Clause, Params)`,
`oaa_ReplaceData(Clause1, Clause2, Params)` — routed exactly like
`oaa_Solve`: an `address` sends the operation to named agents directly;
without one, the Facilitator treats the clause as a goal and finds every
agent with a matching writable data solvable (Developer's Guide §7.1–7.3).
`oaa_ReplaceData` is atomic — the old clause is never visible as absent
while the new one isn't yet present.

New facts are appended by default; `at_beginning(true)` prepends instead.
Removal takes `do_all(true)` to remove every match, or defaults to removing
just the first — an unbound removal pattern with no `do_all` therefore
takes only the first matching fact, which reads as surprising until you
expect it.

## Constraints

`single_value(true)` and `unique_values(true)`, declared on the solvable,
apply to every write against it and are merged beneath the caller's own
parameters (`merged_params/3` in `src/agents/oaa_agent.pl`) so a caller
cannot silently override a constraint the solvable itself declared.

## The reply to a data update

`ev_data_updated(GoalId, Mode, Payload, Requestees, Solvers, Params)` — six
arguments. This was not obvious from the Developer's Guide's prose alone;
it was settled by reading SRI's own OTML conformance test corpus
(`samples/test3/parallel.otml` in the recovered distribution, transcribed in
`tests/compatibility/test_conformance.pl`), which exercises the wire format
directly. An earlier implementation here sent three arguments and passed
every unit test that didn't touch the wire shape, which is exactly the kind
of gap conformance testing against the historical record exists to catch.
See [`communication.md`](communication.md) for the full event table.

## Ownership

The library records which agent added each fact. Facts are removed when
their owning agent disconnects, unless `bookkeeping(false)` or
`persistent(true)` says otherwise (Developer's Guide §7.5) — so a data
solvable can either behave as session-scoped (the default) or survive its
contributor's disconnection.

## Blackboards

A blackboard is nothing more than a data solvable declared with
`address(parent)` — on the Facilitator itself rather than on the declaring
agent — which is what makes it visible and writable by every other agent in
the community rather than only by whoever declared it (Developer's Guide
§5.2, §7.7). There is no separate blackboard mechanism to learn; it falls
out of address routing applied to an ordinary data solvable.

## Data triggers watch this

A data solvable's add/remove/replace operations are exactly what `data`-type
triggers fire on — see [`triggers.md`](triggers.md).
