# Implementation note: the Facilitator

Provenance of this note: derived from the OAA Developer's Guide v2.3.2 (DG),
the OAA v2.x FAQ, and observation of the recovered `src/facilitator/fac.pl`,
`compound.pl` and `translations.pl` (OAA 2.3.2, LGPL-2.1-or-later, © SRI
International, primary authors Adam Cheyer and David Martin).

This is a behavioural specification written from observation. It describes
what the Facilitator does and leaves aside how its Prolog is written, so that
oaa-next's implementation can be authored independently from it.

---

## 1. The Facilitator is an ordinary agent

The structural fact most likely to be lost in a modern reimplementation is
that the Facilitator is an ordinary component. It uses the same agent library
as every client, registers itself with `oaa_Register` on a connection whose id
is `fac_listener` in place of `parent`, declares solvables like any agent, and
handles incoming requests through the same `oaa_AppDoEvent` callback any agent
uses.

A Facilitator can therefore be a client of another Facilitator: starting one
with `oaa_connect` pointed at a parent makes it a *node* facilitator, and that
is the entire mechanism behind multi-facilitator hierarchies, with no separate
federation protocol. Anything a client can do to a solvable it can also do to
the Facilitator's solvables, subject to permissions, so capability discovery
goes through the same door as everything else: it is a query.

oaa-next should therefore implement the Facilitator as an agent that declares
the facilitator solvables, and give it no distinct service type of its own.

## 2. The registry is a data solvable

The Facilitator's knowledge of the community is held in ordinary data
solvables, maintained with the same local add/remove primitives that back
`oaa_AddData` and `oaa_RemoveData` for any agent. The initial set it declares:

| Solvable | Type | Writable | Purpose |
|---|---|---|---|
| `agent_data(Id, Type, Status, Solvables, Name, Info)` | data | yes | The registry proper: one fact per connected agent, carrying its declared solvables |
| `agent_host(Id, Name, Host)` | data | yes | Host of each client agent, where known |
| `agent_version(Id, Language, Version)` | procedure | — | Looks like data but is computed from connection information |
| `facilitator_data(FacAddr, FirstStep, Status, Name, Info)` | data (bookkeeping) | yes | Peer/parent facilitator records |
| `can_solve(Goal, AgentAddr)` | procedure | — | Capability lookup: which agents can solve `Goal` |
| `agent_location(Id, Name, Host, Port)` | data | yes | Facilitator locations; maintained only by the `root` facilitator |
| `data(Item, Data)` | data | yes | OAA 1.0 backwards compatibility |
| `icl_type(Type, SuperType)` | data | yes | The ICL type hierarchy — built-in entries, **extensible at runtime** |

Some entries in that table repay attention.

`agent_data/6` is a writable data solvable, so an agent's status and
capability set are queryable by any client through the normal `oaa_Solve`
path. Registration, deregistration and re-declaration are data maintenance
operations on this relation. Reconstructing it faithfully means resisting the
urge to build a bespoke registry object.

`icl_type/2` is a writable data solvable too, so the ICL type hierarchy is
open. Supertype relations used during matchmaking can be extended at runtime
by adding facts — a real extensibility point that a modern reimplementation
would likely replace with a static enum.

`can_solve/2` is a procedure. Lookup is computed against the current registry
at call time, rather than read from a cached index.

## 3. External event protocol

The Facilitator responds to this set of events from clients. This list is the
Facilitator's actual interface; the library procedures in the Developer's Guide
are wrappers that construct these.

| Event | Meaning |
|---|---|
| `ev_solve(GoalId, Goal, Params)` | Find agent(s) to solve `Goal`, delegate, collect, reply |
| `ev_post_event(AgentId, Cmd)` | Send an event to one agent |
| `ev_post_event(Cmd)` | Send an event to all appropriate agents |
| `ev_post_declare(Mode, Solvables, Params)` | Add / remove / replace solvables **on the facilitator** |
| `ev_update_data(GoalId, Mode, Clause, Params)` | Add / remove / replace data on appropriate agents |
| `ev_update_trigger(GoalId, Mode, Type, Condition, Action, Params)` | Add or remove a trigger on appropriate agents |
| `ev_register_solvables` | Record the goals an agent can solve |
| `ev_connect(AgentInfo)` | Additional client information (library version > 3.0) |
| `connected(Connection)` | A client agent has connected |
| `end_of_file(Connection)` | A client has closed its connection |

Internally the Facilitator uses `ev_respond_query(Id, Requester, Responders,
Solvers, Goal, OrigParams, Params, Solutions)` as a trigger action to return
results to the requester — that is, **the Facilitator routes its own replies
using the trigger mechanism it exposes to clients.** Again: not a special path.

Note the symmetry across `ev_update_data` and `ev_update_trigger`: data
maintenance and trigger installation are routed by the same unification-based
agent selection as `ev_solve`. One routing rule serves all three.

## 4. Delegation

The behaviour that must be preserved exactly, from DG §5.1.2, §6, and observed
handling:

1. **Match by unification.** The incoming goal is unified against the goal
   templates in every connected agent's declared solvables. Only goal templates
   participate; permissions and parameters do not.
2. **Filter by argument specs.** Where a solvable carries `argspecs`, each
   argument value in the goal must conform to the corresponding spec, honouring
   the `icl_type/2` supertype hierarchy (an argument specified as `number`
   accepts an `integer` or a `float`).
3. **Order by utility.** Candidate solvers are ordered by decreasing `utility`
   (0–10, default 5). Equal utility is first-come, first-served.
4. **Consult meta-agents, if any.** A `prioritize` meta-agent may reorder the
   candidate list. If several meta-agents can contribute they are themselves
   ordered by utility and consulted in turn until one returns usable
   information; if none does, the Facilitator's own ordering stands.
5. **Dispatch according to strategy.** By default every matching agent receives
   the request in parallel and all solutions are collected into one reply. With
   `parallel_ok(false)` providers are tried one at a time until the solution
   limit is met. `strategy(action)` means try one provider, and on failure try
   the next — the semantics wanted for side-effecting operations, so that a fax
   is not sent five times.
6. **Collect and reply.** Solutions from all solvers are gathered and returned
   in a single `ev_solved`, unless `reply(none)`.

Steps 1–3 and 5–6 are **deterministic and must remain so**. Step 4 is the only
place where external judgement enters, and OAA already defined it as optional
and fallible.

## 5. Failure, absence and lookup

When no connected agent matches a goal, the Facilitator does not simply fail:
a `lookup` meta-agent, if one is registered, is given the goal and parameters
and is responsible for finding and starting an agent that can handle it,
returning true once that agent has connected. Only if there is no such
meta-agent, or it returns false, does the request fail.

This is a genuine architectural feature — the community is *extensible at
request time* — and it is the natural attachment point for any modern
"discover and launch a capability" mechanism.

## 5a. Consulting a meta-agent without deadlocking

The obvious way to consult a meta-agent is to ask it and wait. A
single-threaded Facilitator cannot: the agent it is waiting on may itself be
waiting on the Facilitator.

oaa-next resolves this by never waiting. Every dispatch carries a reply tag
saying where its answer goes — the client that asked, a compound goal
execution part-way through its branches, or a meta consultation. A
consultation is therefore an ordinary delegated request, and the Facilitator
returns to its event loop while the meta-agent thinks. When the answer
arrives, selection resumes from where it left off.

The same mechanism carries compound goals, which is why both stopped being
hard at the same time.

## 6. Compound goals

`compound.pl` handles goals that are not atomic requests. oaa-next implements
this as a breadth-first branch walk: each branch produces a dispatch,
expansion, or completed solution, and every dispatched subgoal returns through
a continuation tag. Shared variables bind later conjuncts; disjunctions and
parallel solutions copy branches so siblings remain independent.

The Developer's Guide discusses routing plans and names `plan_query` and
`execute_plan` as possible meta-agent control points. A later source audit of
the recovered 2.3.2 Facilitator found that its executable meta handlers admit
only `(Type = prioritize ; Type = lookup)`. Those two hooks and compound-goal
behavior are implemented; inventing additional event behavior would reduce,
not improve, parity with the implementation being reconstructed.

## 7. Connection lifecycle

- A raw socket is followed by `event(ev_connect(Info), [])`. The Facilitator
  assigns a full client address and returns it in
  `event(ev_connected(Info), [])`, before registration.
- `ev_register_solvables/4` records capabilities while status is `open`;
  `ev_ready/1` changes it to `ready`. Local integer IDs remain internal and
  externally visible registry data uses `addr(tcp(Host,Port), LocalId)`.
- Agents carry a status; `ready` and `open` both appear in lookup paths, so a
  client is visible for some purposes before it is fully ready.
- On `end_of_file`, the agent's registry entry is removed, and with it the
  data facts it owned — subject to the `bookkeeping/1` and `persistent/1`
  parameters on the relevant solvables.
- The recovered library contains heartbeat and sequencing machinery gated on
  peer version `[2,3,3]` or newer, while this release reports `[2,3,2]`.
  Therefore two target-version peers do not negotiate sequencing. The public
  sequence predicates preserve that result and heartbeat events are accepted.

## 8. Backwards compatibility

`translations.pl` exists to translate between event vocabularies across OAA
versions — the `data/2` solvable and old-style `write_bb` events are OAA 1.0
carry-over. The Facilitator was expected to serve agents built against older
libraries.

OAA 1.0 translation remains outside the 2.3.2 Prolog/TCP compatibility
boundary. The equivalent seam is retained: transport encoding/decoding and
the classic API facade isolate historical forms from the lower-case runtime.

## 8a. A consequence of typed solvables worth knowing

Discovered while building the reconstruction, and recorded because it will
surprise anyone using `can_solve` as a readiness probe.

Matchmaking checks argument conformance against `argspecs`, and `in(Type,
true)` means the argument *must* be instantiated in the goal. So a lookup with
a wholly unbound goal:

```
can_solve(square(_, _), Address)
```

correctly matches **nothing** when the only provider declares
`argspecs(in(number, true), out(number, true))` — the unbound first argument
violates the required-input spec. Asking `can_solve(square(1, _), Address)`
asks the real question and matches.

This follows directly from Developer's Guide §5.2, so it is almost certainly
historical behaviour rather than an artefact of this implementation. It has a
practical consequence: `can_solve` asks about a goal rather than about a
predicate signature, so callers probing for a capability must supply a
representative goal. There is no recovered evidence of how the historical
tools (Debug, Monitor) handled this, which is worth checking against the
Reference Manual.

## 9. Explicitly open questions

- The precise ordering rule when `utility` ties **and** several agents connected
  in the same event-loop pass.
- Whether `agent_version`'s "language" field is used in any routing decision or
  is purely informational.
- The exact semantics of the `Status` field beyond `ready` and `open`.
- How `test/1` (test-locatable queries) is evaluated on a remote facilitator.
- Whether the OAA Reference Manual documents facilitator solvables beyond the
  initial set above. Retrieving the Reference Manual would likely close
  several of these.
