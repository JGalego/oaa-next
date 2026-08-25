# Architectural compatibility matrix

Maps each historical OAA concept to its historical implementation, the evidence
for that claim, and what oaa-next intends to do about it.

**Compatibility status** values:

- `planned` — not yet implemented
- `reconstructed` — implemented from documented behaviour, behaviour matches
- `modernized` — deliberate change, rationale recorded
- `deferred` — understood, postponed
- `partial` — begun, not finished
- `open` — historical behaviour not yet established

## Status

The historical core is running. A Facilitator and client agents, each its own
operating-system process, exchange ICL over TCP; capabilities are declared as
solvables, matched by unification, ordered by utility and delegated; data
solvables, ownership, blackboards, triggers and compound goals all work, in
single facilitators and in hierarchies. The Agent Development Toolkit
(generator, shell, debug REPL, Start-It, Monitor) sits on top of it. The
optional LLM extension and the MCP/A2A interoperability adapters are built
and kept outside `src/` core, with the isolation claim enforced by
`tests/llm/test_isolation.pl` rather than asserted. The test suite passes,
and no part of the core has any LLM dependency.

The classic compatibility target is now explicit: behavioral and source-level
parity for the OAA 2.3.2 Prolog/TCP surface. The historical mixed-case API is
provided by `src/agents/oaa.pl`; TCP uses the `event/2` envelope and
`ev_connect` / `ev_connected` lifecycle; the Facilitator exposes full OAA
addresses and accepts an original-style client. C/Java/.NET/WebL bindings,
historical binary ABIs, Swing user interfaces, and OAA 1.x translations are
distribution-level non-goals rather than claims hidden inside “core parity”.
See `docs/guide/classic-compatibility.md`.

Time triggers use the separate Alarm agent exactly as the historical library
required. A source audit also corrected an earlier interpretation of the
meta-agent design: recovered OAA 2.3.2 `fac.pl` executes only `lookup` and
`prioritize`. `plan_query` and `execute_plan` occur in broader design
material, but are not deferred executable behavior from this target release.

### Updated closeness verdict

| Surface | Current closeness | Evidence | Remaining difference |
|---|---|---|---|
| Architecture | **Very high** | Facilitator-centered communities, solvable registration, unification, delegation, data, triggers, compound goals, direct connections and hierarchies are exercised by the full suite | SWI-Prolog replaces the historical SICStus/Quintus runtime |
| OAA 2.3.2 Prolog API | **Target parity** | `src/agents/oaa.pl` exports the recovered mixed-case names and arities; an unchanged-style client runs against a live Facilitator | Does not reproduce implementation-private predicates or compiled SICStus artifacts |
| ICL/TCP wire protocol | **Target parity** | Raw-socket tests exercise `event/2`, `ev_connect` / `ev_connected`, registration, readiness, full addresses, solving and historical reply layouts | Compatibility claim is for the recovered ASCII ICL/TCP protocol, not undocumented transports |
| Classic agent behavior | **Very high** | Historical `app_do_event`, declarations, data updates and persistence, triggers, delayed solutions, cache, identity, heartbeat handling and version-gated sequencing are covered | Exact timing and failure text can differ across Prolog runtimes |
| Facilitator behavior | **Very high** | Matching, utility ordering, meta-agent hooks, compound routing, authentication, unique names, blackboards and hierarchy propagation are implemented and integration-tested | Internal data structures and numeric local-ID allocation are intentionally implementation-specific |
| Agent Development Toolkit | **High** | Generator, shell, debug REPL, Start-It and Monitor workflows are present | Modern terminal/browser interfaces replace historical platform-specific GUI details |
| Complete historical distribution | **Partial** | The Prolog/TCP system is reconstructed and modern adapters are additive | No replacement C ABI, Java/.NET/WebL bindings, Swing applications or OAA 1.x translation layer |
| Binary/runtime compatibility | **Not targeted** | The project is an independent source reimplementation on SWI-Prolog | Historical binaries and SICStus bytecode are neither loaded nor reproduced |
| **Overall** | **Near drop-in compatibility for the OAA 2.3.2 Prolog/TCP surface** | Both raw historical protocol traffic and original-style Prolog source are verified against a live community | It is not a drop-in replacement for every language binding and binary shipped in the complete historical distribution |

Findings from the implementation itself live in the notes rather than here:
`can_solve` with a wholly unbound goal cannot match a solvable declaring
required inputs (facilitator.md §8a), ICL's operator set is its own, smaller
than Prolog's and with its own precedence order (icl.md §1), and the wire
reply to a data update carries six arguments —
`ev_data_updated(GoalId, Mode, Clause, Params, Requestees, Updaters)` — as
settled from SRI's own OTML conformance corpus
(`tests/compatibility/test_conformance.pl`).

**Provenance** values, per the project's ORIGINAL / RECONSTRUCTED / MODERNIZED
/ NEW distinction, are recorded per subsystem once implementation begins.

Evidence abbreviations: **DG** = OAA Developer's Guide v2.3.2; **SRC** = OAA
2.3.2 source; **FAQ** = OAA v2.x FAQ; **HIST** = `doc/history.txt`; **PRO** =
`doc/README_PROLOG.txt`; **JAAMS** = Martin, Cheyer & Moran 2001.

---

## Technology stack

| Historical element | Historical implementation | Evidence | oaa-next | Modernization | Status |
|---|---|---|---|---|---|
| Facilitator language | Prolog — `fac.pl`, `compound.pl`, `translations.pl` | SRC | Prolog | Dialect only | reconstructed |
| Prolog dialect | **SICStus** (default from 2.2.0), **Quintus** (fallback, `_qp` binaries) | PRO, SRC | SWI-Prolog 9.x | Both historical dialects are proprietary; SWI-Prolog is the maintained, freely available, ISO-conformant equivalent. See note below | modernized |
| Agent library languages | Prolog, C, Java, WebL (+ .NET in 2.3.2) | FAQ, SRC | **Prolog done**; C next, then Java | WebL is dead (HP discontinued); .NET deferred | partial |
| OAA 1.x language reach | Prolog, C, C++, Perl, Lisp, Visual Basic, Delphi, Java, WebL | FAQ | Not targeted | 2.x already narrowed this deliberately | deferred |
| Transport | TCP/IP, behind a `com_`-prefixed transport API loaded as a separate module | DG §4.2 | Same: TCP with a `com_` transport boundary | Preserve the API seam — it is why OAA could claim transport independence | reconstructed |
| Build | Makefiles, MSVC project files, gcc, JDK 1.4 | SRC | Modern toolchains | Versions, not architecture | planned |

On replacing SICStus and Quintus with SWI-Prolog: this looks like a deviation
and is arguably the opposite. OAA already ran on two different Prolog systems
and carried a compatibility layer for it. `spcompat.pl` (37 KB) holds the
SICStus-specific code, `oaa.pl` and `com_tcp.pl` branch in a handful of
places, and the current dialect is discovered at runtime by calling
`oaa:current_prolog(P)`, which answers `sicstus` or `quintus`. Supporting a
third dialect is a move OAA's own design anticipated, so oaa-next should keep
an equivalent seam rather than assume a single Prolog.

## Core architecture

| Concept | Historical implementation | Evidence | oaa-next | Status |
|---|---|---|---|---|
| Facilitator | Specialized server agent; keeps a knowledge base of connected agents' capabilities; performs registration, matching, delegation, routing, result collection, and optionally a global data store | DG §3.2, FAQ §2.1 | Same responsibilities, same name, Prolog implementation | reconstructed |
| Facilitator as agent | The facilitator is itself an OAA agent using the same library and communication standards | DG §10.2 | Preserve — this is what makes hierarchies work | reconstructed |
| Facilitator domain-independence | Domain-independent; domain knowledge lives in meta-agents | FAQ §2.2 | Preserve | reconstructed |
| Client agent | Any agent that is not a facilitator; connects to a "parent facilitator" and declares its services | DG §3.1 | Same | reconstructed |
| Agent connection | `com_Connect(parent, [], _Address, _Actual)` then `oaa_Register(parent, Name, Solvables, Params)` | DG §9.1, SRC | Same two-step | reconstructed |
| Event loop | `oaa_MainLoop`; polls an event queue; builtin events handled by the library, user events dispatched to callbacks | DG §4.4 | Same | reconstructed |
| Startup ordering | Each facilitator must be listening before its clients connect | DG §3.4 | Same | reconstructed |
| Prolog public API | Mixed-case predicates and historical arities exported by module `oaa` | SRC `oaa.pl` export list | Compatibility facade exports the historical surface; lower-case API remains for new code | reconstructed |
| Connection handshake | `event(ev_connect(Info), [])` → `event(ev_connected(Info), [])`; address assigned before registration | SRC | Same envelope, metadata, password and unique-name rejection | reconstructed |
| Registration lifecycle | `ev_register_solvables/4`, then `ev_ready/1`; status changes `open` → `ready` | SRC | Same; transitional `ev_registered/2` is accepted only for early oaa-next peers | reconstructed |
| Public addresses | Facilitator `addr(tcp(Host,Port))`; client `addr(tcp(Host,Port),LocalId)` | DG §4.3.7, SRC | Same externally; integer IDs remain internal | reconstructed |

## ICL — Interagent Communication Language

| Concept | Historical implementation | Evidence | oaa-next | Status |
|---|---|---|---|---|
| Basis | An extension of Prolog syntax, chosen for unification and backtracking, and to be translatable to and from natural language | DG §3.3, FAQ §2.4 | Same | reconstructed |
| Layering | A conversational layer (event types + parameter lists) over a content layer (goals, triggers, data elements) — compared by the DG to KQML over KIF | DG §4.3 | Preserve the two layers explicitly | reconstructed |
| Why content stays in ICL | So the facilitator can read the content, decompose compound requests, and delegate subrequests individually | DG §4.3 | Preserve — this is the argument against opaque payloads | reconstructed |
| Parser | ANTLR grammar in Java (`OaaPrologNetParse.g`); PCCTS grammar in C (`parser.g`) | SRC | Single canonical grammar, one parser per language binding | reconstructed |
| Data types | `atomic` > `number` > {`float`,`integer`}; `string` > {`atom`, `icldataq/1`, `icldataq/3`}; `compound`; `list`; document types `xml/2`, `mime/2` | DG §4.3.4 | Same hierarchy, incl. supertype relations used in matchmaking | reconstructed |
| Parameter lists | Functor-with-arguments form, e.g. `[type(data), single_value(true)]`; boolean parameters may drop `(true)`; defaults elided on the wire | DG §4.3.6 | Same, including default elision | reconstructed |
| Addresses | `addr(tcp(Host,Port))` for facilitators, `addr(tcp(Host,Port), LocalID)` for clients; reserved terms `self`, `parent`, `facilitator`; `name/1` wrapper | DG §4.3.7 | Same | reconstructed |

## Solvables — capability declaration

| Concept | Historical implementation | Evidence | oaa-next | Status |
|---|---|---|---|---|
| Form | `solvable(GoalTemplate, Parameters, Permissions)` | DG §5.1.1 | Same | reconstructed |
| Shorthand forms | Trailing empty arguments omissible, down to a bare goal template | DG §5.1.5 | Same — normalize to standard form on receipt | reconstructed |
| Types | `procedure` (default), `data`, `trigger` | DG §4.3.1, §5.1.4 | Same three | reconstructed |
| Matching | **Unification** of the request goal against goal templates; permissions and parameters do not participate | DG §5.1.2 | Same — deterministic unification, not similarity | reconstructed |
| Default fan-out | Every connected agent whose template unifies receives the request | DG §5.1.2 | Same | reconstructed |
| Permissions | `call/1`, `write/1`, `read/1` (read unused) | DG §5.1.3 | Same; note the historical quirk that permissions apply to the declaring agent too | reconstructed |
| `utility/1` | Integer 0–10, default 5; facilitator orders candidate solvers by decreasing utility | DG §5.1.4 | Same | reconstructed |
| Optional typing | `argspecs(...)` with `in/2`, `out/2`, `inout/2`; `argnames(...)` for display only; absent argspecs mean `inout(_, false)` | DG §5.2 | Same, incl. the default | reconstructed |
| Declaration API | `oaa_Register`, `oaa_Declare`, `oaa_Undeclare`, `oaa_Redeclare` (atomic swap) | DG §5.1.6 | Same | reconstructed |

## Requesting services

| Concept | Historical implementation | Evidence | oaa-next | Status |
|---|---|---|---|---|
| Single entry point | `oaa_Solve(Goal, Params)` — used identically for data and procedure solvables | DG §4.3.3, §6 | Same | reconstructed |
| Default semantics | Behaves like Prolog `call/1`: blocks, may fail or succeed, backtracks over solutions from all matching peers | DG §6.15 | Same | reconstructed |
| Delegation transparency | Requester need not know identity or location of solvers | DG §3.2 | Same | reconstructed |
| Advice parameters | `address`, `solution_limit`, `provider_limit`, `blocking`, `reply`, `parallel_ok`, `reflexive`, `priority`, `time_limit`, `context`, `cache`, `unique_values`, `owner`, `test`, `propagate`, `direct_connect`, `flush_events`, `level_limit` | DG §6 | Same set | reconstructed |
| Return parameters | `get_address/1`, `get_satisfiers/1`, `get_goal_id/1` | DG §6.13 | Same | reconstructed |
| Strategy macros | `query` = `[parallel_ok(true)]`; `action` = `[parallel_ok(false), solution_limit(1)]`; `inform` = `[parallel_ok(true), reply(none)]` | DG §6.14 | Same | reconstructed |
| Precedence quirks | `reply(none)` overrides `blocking(true)` and overrides `parallel_ok(false)` | DG §6.15 | Same — document explicitly | reconstructed |
| Peer discovery | `can_solve(Goal, AgentAddress)` and `agent_data/6` as facilitator solvables | DG §4.3.7 | Same | reconstructed |
| Wire events | `ev_solve(GoalId, Goal, Params)` → `ev_solved(GoalId, Requestees, Solvers, Goal, Params, Solutions)` | DG §4.3.2, §6.8 | Same shape | reconstructed |
| Goal echo in replies | Pre-2.3.2 the goal was echoed in `ev_solved`; 2.3.2 sends a variable, `-return_goal_with_solutions` restores it | HIST | Follow 2.3.2 default; keep the flag | reconstructed |
| Goal ID generation | Client-side; randomised start from 2.3.2 to avoid cross-request collisions | HIST | Randomised, and unique across reconnects | reconstructed |
| Delayed solutions | `oaa_DelaySolution/1`, `oaa_AddDelayedContextParams/3`, `oaa_ReturnDelayedSolutions/2` — asynchrony invisible to the requester | DG §5.4 | Same | reconstructed |
| Event priorities | 1–10, default 5; equal-or-lower priority events queue, higher priority events interrupt | DG §5.5 | Same | reconstructed |

## Data solvables

| Concept | Historical implementation | Evidence | oaa-next | Status |
|---|---|---|---|---|
| Model | A data solvable is essentially a relational table; queried through `oaa_Solve` like any other solvable | DG §7 | Same | reconstructed |
| Maintenance | `oaa_AddData/2`, `oaa_RemoveData/2`, `oaa_ReplaceData/3`; replace is atomic | DG §7.1–7.3 | Same, incl. atomicity | reconstructed |
| Ordering | New facts appended by default; `at_beginning/1` to prepend; `do_all/1` on removal | DG §7.1–7.2 | Same | reconstructed |
| Constraints | `single_value/1`, `unique_values/1` | DG §7.1 | Same | reconstructed |
| Ownership | The library records which agent created each fact; facts are removed when that agent goes offline, subject to `bookkeeping/1` and `persistent/1` | DG §7.5 | Same | reconstructed |
| Blackboard | A publicly readable/writable data solvable declared *on the facilitator* by a client, via `address(parent)` | DG §5.2, §7.7 | Same | reconstructed |

## Triggers

| Concept | Historical implementation | Evidence | oaa-next | Status |
|---|---|---|---|---|
| Types | `comm`, `data`, `task`, `time` | DG §4.3.5, FAQ §2.5 | Same four | reconstructed |
| API | `oaa_AddTrigger(Type, Condition, Action, Params)` / `oaa_RemoveTrigger/4` | DG §8.1, §8.6 | Same | reconstructed |
| Implementation | All triggers are stored as instances of a built-in data solvable `oaa_trigger/5`, so installed triggers are queryable via `oaa_Solve` | DG §4.3.5 | Same — an elegant reflexivity worth preserving | reconstructed |
| Placement | Local, on the facilitator, or on a peer; default `['self']` for `comm` and `time`; `data`/`task` route by unification like a request | DG §8.2 | Same, including the consequence that an unaddressed time trigger never fires | reconstructed |
| Duration | `recurrence(when)` (default, fires once), `whenever`, or a positive integer count | DG §8.4 | Same | reconstructed |
| Actions | An `oaa_Solve/1,2` or `oaa_Interpret/1,2` term; bare goal accepted for backwards compatibility; `reply` defaults to `none` inside a trigger | DG §8.5 | Same, incl. the changed default | reconstructed |
| Task triggers | Require a `trigger`-type solvable. **The 2.x library does not check the condition** — application code must, and calls `oaa_CheckTriggers/3`. `app_setup_trigger` notifies the agent that one was installed. Differs from 1.x | DG §8.3 | Same, and document the 1.x/2.x divergence | reconstructed |
| Time triggers | Not in the agent libraries at all — provided by a separate Alarm agent; `time_expr(From, To, Recurrence)` with 1900/0-based `date/6` | DG §4.3.5, §8.3 | Same separation; modern date handling internally | modernized |

## Execution management and tooling

| Concept | Historical implementation | Evidence | oaa-next | Status |
|---|---|---|---|---|
| Start-It | Execution manager: launches a community per platform conventions, ensures each agent connects, monitors agents, restarts failures | DG §3.4, FAQ §2.6 | Same role, driven by a community description file | reconstructed |
| Monitor | Graphically displays and records an agent community and its communications | FAQ §2.6 | Same role; terminal output rather than graphical, and it learns the community by querying `agent_data/6` and watching traffic through a comm trigger on the facilitator | modernized |
| Debug | Sends ICL or natural-language messages to the community or a single agent; shipped in both Java and C builds | FAQ §2.6 | Terminal REPL; natural language is left to a community that has an NL agent, as it was historically | modernized |
| Shell agent | Command-line access to the community | SRC, download page | Same | reconstructed |
| Configuration | Command line → environment variables → setup file, searched in that order; setup file is Prolog-syntax `setup.pl`; `default_facilitator(tcp(Host,Port))` preferred over `oaa_connect` in shared setup files | DG §4.6 | Same precedence and same file syntax | reconstructed |
| Port exception handling | `-on_port_exception` with `exit`, `try_again`, `next_highest`, `change_port`, `any_available` | DG §4.6.2 | Same | reconstructed |
| ADT | Agent Development Toolkit — Martin, Cheyer & Lee, PAAM'96 | paper not yet retrieved | Generator, shell, debug REPL, Start-It and Monitor, built from the Developer's Guide and FAQ descriptions; the PAAM'96 paper would still be worth having | partial |

## Scaling

| Concept | Historical implementation | Evidence | oaa-next | Status |
|---|---|---|---|---|
| Multiple facilitators | Strictly hierarchical (tree) topology is the only pattern with library support; a node facilitator is one started with `oaa_connect` to a parent | DG §10.2 | Same. A node registers upward with the union of its clients' solvables, so downward reach needs no propagation and no federation protocol | reconstructed |
| Propagation | `propagate([up/1, down/1, up_limit/1, down_limit/1])`; `up`/`down` take `true`, `false`, `if_no_solvers`; default is no propagation | DG §6.10 | Same defaults; `up_limit` counts down across levels, and a goal that arrived from the parent is never referred back up | reconstructed |
| Referred goals | Carry the originating facilitator's address as continuation information; the responding agent's identity returns to the originator | DG §10.2 | The reply tag is the continuation | reconstructed |
| Direct connect | `direct_connect(true)` bypasses the facilitator for message flow while the facilitator still selects the provider; requires a provider listener socket registered before `oaa_Register`; single-provider, single-facilitator, `oaa_Solve` only; `time_limit` and `parallel_ok` ignored | DG §10.1 | Same, including the limitations | reconstructed |
| Meta-agents: `prioritize` | Given the Facilitator's sorted candidate list, return a reordering | DG §5.6 | Consulted as an ordinary dispatch answered to a `meta(...)` reply tag | reconstructed |
| Meta-agents: `lookup` | Given a goal nothing can solve, find and start an agent that can; selection is repeated on success | DG §5.6 | Same | reconstructed |
| Meta-agents beyond `lookup`/`prioritize` | Design material describes `plan_query` and `execute_plan`, but recovered 2.3.2 `fac.pl` dispatches only `(Type = prioritize ; Type = lookup)` | DG §5.6, SRC `fac.pl` meta handlers | No invented wire behavior; executable 2.3.2 hook set is complete | reconstructed |
| Compound goals | Facilitator decomposes a compound request and delegates the subrequests individually | DG §4.3 | Breadth-first branch walk, driven one dispatch at a time so the Facilitator never blocks on an agent | reconstructed |
| Conjunction join | Variables shared between conjuncts bind the later ones from the earlier ones' solutions | SRC, logic-programming semantics | Same; branches copy so siblings stay independent | reconstructed |
| Nested parameter lists | A subgoal may carry its own address and parameters inside a compound goal | DG §6.15, Reference Manual | `Address:Goal::Params` disassembly per `oaa_DisassembleGoal` | reconstructed |

Meta-agents are where an LLM belongs. The `prioritize` hook reorders the
facilitator's candidate solver list; `lookup` finds and starts an agent when
no local one matches. These are the executable 2.3.2 decisions an LLM can
improve, and OAA defined them as optional,
external and fallible: the facilitator proceeds with its deterministic default
when no meta-agent returns anything usable. An LLM meta-agent is therefore an
additive extension that changes nothing about the core, which is the invariant
this project requires. Recorded here because it means the LLM extension can
leave the Facilitator alone.

## The LLM extension

Provenance: NEW / LLM EXTENSION. Nothing here corresponds to anything
historical, which is why it lives outside `src/` core entirely.

| Element | oaa-next | Notes |
|---|---|---|
| Mode gate | `OAA_CLASSIC` (default) / `OAA_LLM` | Read by the extension; never by the core |
| Provider interface | `llm_complete(Messages, Options, Response)` | Messages are `message(Role, Text)`; adapters are replaceable |
| Adapters | Anthropic, OpenAI-compatible, scripted | Scripted is the default and reaches no network |
| LLM agent | Declares `interpret/2` and `propose_goal/2` | An ordinary agent: `com_Connect`, `oaa_Register`, callbacks, `oaa_Solve` |
| LLM meta-agent | Declares `meta(prioritize, ...)` | Advises provider ordering through the hook OAA already had |

The isolation claim is tested rather than asserted: `tests/llm/test_isolation.pl`
fails if any core module so much as names the extension.

## Interoperability adapters

Provenance: INTEROPERABILITY ADAPTER. Not OAA, and kept visibly separate from
it. Each is an ordinary OAA agent that translates at the edge; nothing inside
the community changes shape to accommodate one.

| Adapter | Direction | Notes |
|---|---|---|
| `icl_json` tagged | ICL ↔ JSON, lossless | Every term survives a round trip, variables and functors included |
| `icl_json` plain | ICL → JSON, lossy | Natural JSON a consumer reads without knowing ICL; atoms and strings become indistinguishable |
| `solvable_to_schema` | Solvable → JSON Schema | Argument names come from `argnames`, types from `argspecs` |
| `mcp_server` | OAA community → MCP server | JSON-RPC 2.0 over stdio; capabilities become tools |
| `a2a_bridge` | OAA community → A2A agent | The Facilitator's registry projected as an Agent Card |

What the translation loses is worth naming. An MCP tool call is one call with
named arguments and one result; an ICL goal can carry unbound variables
anywhere, backtrack over several solutions, and be a conjunction the
Facilitator takes apart. The bridge reports all solutions rather than choosing
between them, and leaves the richer forms to callers who speak ICL.

The comparison with A2A is the more interesting one, because the two designs
answer the same question differently. An A2A agent publishes its own card and
a client reads cards to decide who to ask. In OAA an agent tells one
Facilitator what it can do and the Facilitator decides; the requester names a
goal, never an agent.

## Deliberate non-goals

| Modern convention | Why not | Where it may appear instead |
|---|---|---|
| JSON as the interagent format | Loses unification, variables and the facilitator's ability to decompose compound goals | Interoperability adapter |
| LLM as the router | Replaces a deterministic mechanism with a stochastic one | Optional executable `prioritize`/`lookup` meta-agent hooks |
| Vector similarity for capability matching | OAA matching is unification, and is exact | Optional meta-agent advice |
| MCP or A2A as the internal protocol | ICL is the architecture, not an implementation detail | Bridges, clearly separated |
| Service registry in place of the Facilitator | A registry does not delegate, decompose, collect or route | — |
