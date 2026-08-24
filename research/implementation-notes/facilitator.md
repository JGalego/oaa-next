# Implementation note: the Facilitator

Provenance of this note: derived from the OAA Developer's Guide v2.3.2 (DG),
the OAA v2.x FAQ, and observation of the recovered `src/facilitator/fac.pl`,
`compound.pl` and `translations.pl` (OAA 2.3.2, LGPL-2.1-or-later, © SRI
International, primary authors Adam Cheyer and David Martin).

This is a **behavioural specification written from observation**. It is
deliberately a description of what the Facilitator does, not a transcription of
how its Prolog is written, so that oaa-next's implementation can be authored
independently from it.

---

## 1. The Facilitator is an ordinary agent

The single most important structural fact, and the one most likely to be lost
in a modern reimplementation: **the Facilitator is not a special kind of
component.** It uses the same agent library as every client, registers itself
with `oaa_Register` (on a connection whose id is `fac_listener` rather than
`parent`), declares solvables like any agent, and handles incoming requests
through the same `oaa_AppDoEvent` callback mechanism any agent uses.

Two consequences follow directly, and both are architecture rather than
accident:

- A Facilitator can be a client of another Facilitator. Starting one with
  `oaa_connect` pointed at a parent makes it a *node* facilitator. This is the
  entire mechanism behind multi-facilitator hierarchies — there is no separate
  federation protocol.
- Anything a client can do to a solvable, it can do to the Facilitator's
  solvables, subject to permissions. Capability discovery is not a privileged
  API; it is a query.

**oaa-next must not implement the Facilitator as a distinct service type.** It
should be an agent that happens to declare the facilitator solvables.

## 2. The registry is a data solvable, not a special structure

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

Three things in that table are worth pausing on.

**`agent_data/6` being a writable data solvable** means an agent's status and
capability set are queryable by any client through the normal `oaa_Solve` path.
Registration, deregistration and re-declaration are data maintenance operations
on this relation. Reconstructing this faithfully means resisting the urge to
build a bespoke registry object.

**`icl_type/2` being a writable data solvable** means the ICL type hierarchy is
not hard-coded. Supertype relations used during matchmaking can be extended at
runtime by adding facts. This is a real extensibility point that a modern
reimplementation would very likely miss and replace with a static enum.

**`can_solve/2` being a procedure, not data,** means lookup is computed against
the current registry at call time rather than being a cached index.

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

## 6. Compound goals

`compound.pl` handles goals that are not atomic requests. When compiled for
compound goals, the Facilitator produces a **routing plan** for a delegated
request using its strategies and metadata, then interprets that plan, invoking
and coordinating the agents it names. Two meta hooks bracket this:
`plan_query` lets a meta-agent improve the plan the Facilitator generated, and
`execute_plan` lets a client meta-agent interpret the plan instead of the
Facilitator — explicitly motivated in the Developer's Guide by wanting to avoid
the Facilitator being a single point of failure and a bottleneck for all
execution state.

Compound-goal handling is the deepest part of the Facilitator and is
**deferred** in oaa-next until atomic delegation is correct.

## 7. Connection lifecycle

- On `connected`, the Facilitator records the connection and assigns the client
  a local ID, which it returns to the client during `oaa_Register`. Local IDs
  are integers in the historical implementation, but the Developer's Guide
  explicitly warns developers not to rely on that.
- Agents carry a status; `ready` and `open` both appear in lookup paths, so a
  client is visible for some purposes before it is fully ready.
- On `end_of_file`, the agent's registry entry is removed, and with it the
  data facts it owned — subject to the `bookkeeping/1` and `persistent/1`
  parameters on the relevant solvables.
- From 2.3.2, client and facilitator exchange regular pings so that a dead
  connection is detected promptly, and an agent may reconnect *with the same
  identity*. oaa-next should implement liveness from the start rather than
  retrofitting it, because identity-across-reconnect constrains how local IDs
  and goal IDs are allocated.

## 8. Backwards compatibility

`translations.pl` exists to translate between event vocabularies across OAA
versions — the `data/2` solvable and old-style `write_bb` events are OAA 1.0
carry-over. The Facilitator was expected to serve agents built against older
libraries.

oaa-next does not need OAA 1.0 compatibility, but it should keep a comparable
seam, because the historical lesson is that the Facilitator, not the client,
absorbed protocol drift.

## 9. Explicitly open questions

- The precise ordering rule when `utility` ties **and** several agents connected
  in the same event-loop pass.
- Whether `agent_version`'s "language" field is used in any routing decision or
  is purely informational.
- The exact semantics of the `Status` field beyond `ready` and `open`.
- How `test/1` (test-locatable queries) is evaluated on a remote facilitator.
- Whether the OAA Reference Manual documents facilitator solvables beyond the
  initial set above. **Retrieving the Reference Manual would likely close
  several of these.**
