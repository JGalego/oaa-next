# Data

A data solvable functions as a relational table and uses the same query and
update interface as a procedural capability. An agent asking for data does
not need to know whether the answer comes from a computation or a lookup
(Developer's Guide §7).

## Declaring one

```prolog
solvable(foo(_), [type(data), write(true)], [write(true)])
```

Note the permission quirk from [`capability-registration.md`](capability-registration.md):
an agent has to declare `write(true)` on its own data solvable to modify
it, the same as any other agent would need to.

## Querying

Queries go through `oaa_Solve`. A data solvable's clauses match a goal by
unification like a procedure's, and `oaa_Solve` backtracks over every matching
fact from every agent that provides one, subject to the usual advice
parameters.

## Maintaining

`oaa_AddData(Clause, Params)`, `oaa_RemoveData(Clause, Params)`,
`oaa_ReplaceData(Clause1, Clause2, Params)` are routed like
`oaa_Solve`: an `address` sends the operation to named agents directly;
without one, the Facilitator treats the clause as a goal and finds every
agent with a matching writable data solvable (Developer's Guide §7.1–7.3).
`oaa_ReplaceData` is atomic: the old clause is never visible as absent
while the new one isn't yet present.

New facts are appended by default; `at_beginning(true)` prepends instead.
Removal takes `do_all(true)` to remove every match, or defaults to removing
just the first. An unbound removal pattern without `do_all` therefore takes
only the first matching fact.

## Constraints

`single_value(true)` and `unique_values(true)`, declared on the solvable,
apply to every write against it and are merged beneath the caller's own
parameters (`merged_params/3` in `src/agents/oaa_agent.pl`) so a caller
cannot silently override a constraint the solvable itself declared.

## The reply to a data update

`ev_data_updated(GoalId, Mode, Payload, Requestees, Solvers, Params)` has six
arguments. The Developer's Guide's prose did not establish the arity;
it was settled by reading SRI's own OTML conformance test corpus
(`samples/test3/parallel.otml` in the recovered distribution, transcribed in
`tests/compatibility/test_conformance.pl`), which exercises the wire format
directly. An earlier implementation here sent three arguments and passed
every unit test that didn't touch the wire shape. Conformance tests against
the historical record caught the gap.
See [`communication.md`](communication.md) for the full event table.

## Ownership

The library records which agent added each fact. Facts are removed when
their owning agent disconnects, unless `bookkeeping(false)` or
`persistent(true)` says otherwise (Developer's Guide §7.5). A data
solvable can either behave as session-scoped (the default) or survive its
contributor's disconnection.

## Blackboards

A blackboard is a data solvable declared with `address(parent)`. It resides
on the Facilitator instead of the declaring agent, so every agent in the
community can see and write it (Developer's Guide §5.2, §7.7). Blackboard
behaviour follows from address routing applied to an ordinary data solvable.

## Data triggers watch this

`data`-type triggers fire on a data solvable's add, remove and replace
operations. See [`triggers.md`](triggers.md).
