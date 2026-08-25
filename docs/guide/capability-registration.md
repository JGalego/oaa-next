# Capability registration

A solvable is what an agent tells the Facilitator it can do. Everything
about delegation, matching and permissions starts with how solvables are
declared.

## Form

```prolog
solvable(GoalTemplate, Parameters, Permissions)
```

`GoalTemplate` is the ICL goal shape this solvable answers, such as
`square(In, Out)` or `foo(_)`. `Parameters` describes the solvable itself: its type,
utility, argument specs and so on. `Permissions` controls who may invoke it
and how.

## Shorthand forms

The Developer's Guide (§5.1.5) allows dropping trailing arguments down to a
bare goal template, and every agent library procedure taking a solvable list
accepts any of them interchangeably:

```prolog
solvable(get_message(A, B), [], [])
solvable(get_message(A, B), [])
solvable(get_message(A, B))
get_message(A, B)
```

`solvable_normalize/2` (`src/agents/oaa_solvable.pl`) is what every other
predicate calls to reach the canonical three-argument form; `solvable_list/2`
does the same across a whole declaration list.

## Type

`type(procedure)` (the default), `type(data)`, or `type(trigger)`. A data
solvable is a relational table, queried and updated the same way a
procedure is invoked. See [`data.md`](data.md). A `task` trigger requires a
trigger-type solvable because the library never checks a task trigger's
condition itself. See [`triggers.md`](triggers.md).

## Permissions

`call/1`, `write/1`, `read/1` (the last historically unused), defaulting to
`call(true), write(false), read(false)` (Developer's Guide §5.1.3). A
historical quirk preserved here: permissions apply to the declaring agent
too, so an agent wanting to write its own data solvable must still declare
`write(true)` on it (`solvable_permission/2`).

## Utility

`utility(N)`, an integer 0–10, default 5. When several agents provide
matching solvables, the Facilitator orders candidates by descending utility
(`fac_order/2`), stable within a utility band. Utility controls order but
does not guarantee exclusive selection. Every matching agent still receives
the request by default (below).

## Default fan-out

Every connected agent whose template unifies with the goal receives the
request unless request parameters (`solution_limit`, `provider_limit`,
`address`) narrow the set. Unlike an RPC call to one handler, this default
fans out to all matching agents
(Developer's Guide §5.1.2).

## Argument specs

`argspecs([in(1, number), out(2, number)])` documents which arguments are
inputs a caller must bind and which are outputs the solver produces;
`argnames(...)` is display-only. A solvable with no argspecs behaves as if
every argument were `inout(_, false)`. The specs are advisory, not required
(Developer's Guide §5.2). `icl_conforms_argspec/2` checks a value against a
declared spec's type. As a result, a
goal with an unbound argument cannot match a solvable that declares that
argument `in` (required). This historical rule is documented in
[`../../research/implementation-notes/facilitator.md`](../../research/implementation-notes/facilitator.md)
§8a.

## Declaring and changing

`oaa_Register(ConnId, Name, Solvables, Params)` declares at connection time.
`oaa_Declare/2` and `oaa_Undeclare/2` add and remove solvables afterward.
`oaa_Redeclare/3` swaps one solvable for another atomically. The old
declaration is never visible as absent while the new one isn't yet present
(Developer's Guide §5.1.6).

## Private solvables

`private(true)` keeps a solvable out of the Facilitator's public registry.
The built-in `oaa_trigger/5` data solvable uses it. Every agent implicitly
provides this solvable, so installed triggers are queryable like
any other data without cluttering `can_solve` results with library
plumbing.
