# Concepts

The vocabulary OAA uses for everything else, gathered in one place. Each
term links to the page that treats it in depth.

**Agent** — any process using the agent library to connect to a Facilitator
and register solvables. A Facilitator is itself an agent. See
[`agents.md`](agents.md).

**Facilitator** — the agent that matches goals against registered
capabilities, orders and dispatches to candidates, and collects and relays
results. See [`facilitator.md`](facilitator.md).

**Solvable** — a capability declaration, `solvable(GoalTemplate, Parameters,
Permissions)`. What an agent tells the Facilitator it can do. See
[`capability-registration.md`](capability-registration.md).

**Goal** — an ICL term an agent wants solved, e.g. `square(7, X)`. Matched
against solvables by unification, not by name lookup or similarity.

**ICL** — Interagent Communication Language, the term syntax and event
protocol every message on the wire is written in. See [`icl.md`](icl.md).

**Event** — a wire-level message with a type and a parameter list, e.g.
`ev_solve(GoalId, Goal, Params)`. The conversational layer over ICL's
content layer. See [`communication.md`](communication.md).

**Parameter list** — `[type(data), utility(8), reply(none)]`-shaped advice
attached to a solvable, a goal or an event. Booleans may drop `(true)`;
defaults are elided on the wire and reapplied on receipt
(`icl_param_apply_defaults/3`).

**Delegation** — the act of the Facilitator routing a goal to the agent(s)
whose solvables match it, invisibly to the requester. See
[`delegation.md`](delegation.md).

**Data solvable** — a solvable of `type(data)`: a relational table an agent
maintains, queried and updated through the same `oaa_Solve` /
`oaa_AddData` / `oaa_RemoveData` interface as any capability. See
[`data.md`](data.md).

**Trigger** — a standing instruction: when some condition holds, take some
action. Four kinds — `comm`, `data`, `task`, `time` — with different
placement and firing rules. See [`triggers.md`](triggers.md).

**Blackboard** — a data solvable declared on the Facilitator itself via
`address(parent)`, so multiple agents can read and write it as shared state.

**Meta-agent** — an agent the Facilitator consults during delegation:
`prioritize` to reorder candidates, `lookup` to find a solver when none is
registered. Optional, and the Facilitator's own default runs when none
answers. This is the seam the LLM extension uses.

**Utility** — an integer 0–10 a solvable declares, used to order candidates
when several agents can solve the same goal (default 5).

**Compound goal** — a conjunction or disjunction of goals the Facilitator
decomposes and delegates piece by piece rather than routing as one unit.

**Continuation / reply tag** — the mechanism that lets a reply find its way
back through however many hops it took to arrive, without the Facilitator
blocking on any one leg. See "reply tags" in
[`../../research/implementation-notes/facilitator.md`](../../research/implementation-notes/facilitator.md) §5a.

**Provenance labels** — every subsystem in this repository is one of
ORIGINAL (unmodified historical source — none is committed; see
[`../../research/licensing.md`](../../research/licensing.md)), RECONSTRUCTED
(independently written from documented or observed behaviour), MODERNIZED
(a deliberate, recorded change), NEW / LLM EXTENSION, or INTEROPERABILITY
ADAPTER. Tracked per-subsystem in
[`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md).
