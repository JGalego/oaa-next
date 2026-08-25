# Phase 1 — the historical core

Approved and built. Kept here as the plan the work followed; where it and the
code disagree, the code and `research/compatibility-matrix.md` are current.

Phase 1 delivers a working OAA community: a Facilitator, an agent library, ICL,
solvables, registration, delegation, data solvables and triggers, running with
no LLM dependency of any kind. The result has to be usable indefinitely in
`OAA_CLASSIC` mode.

## Prerequisites, and what is already settled

Settled in Phase 0:

- Prolog implementation: SWI-Prolog. Historical OAA ran on SICStus, the
  default from 2.2.0, with Quintus behind it; both are proprietary. SWI-Prolog
  9.x is the maintained, freely available, ISO-conformant equivalent, and
  adding a third dialect to a system that already carried a
  dialect-compatibility layer (`spcompat.pl`, `oaa:current_prolog/1`) stays
  faithful to the original design.
- The Facilitator is written in Prolog, and its historical source is available
  as a behavioural reference.
- ICL is a restricted term language, and will be implemented as one.
- Clean-room: the recovered source informs the specification; oaa-next code is
  authored independently.

These decisions remain open for the owner. Neither blocks starting Phase 1,
since clean-room code can be licensed after the fact and renamed cheaply, but
both should be resolved before any public release:

1. The oaa-next license for newly authored code (`research/licensing.md` §5).
2. The trademark position and hence the project name (`research/licensing.md` §6).

## Design commitments

These are the invariants Phase 1 must not break.

1. The Facilitator is an ordinary agent. It uses the same library, registers
   like any client, and answers requests through the same callback path, with
   no separate service type.
2. The registry is a data solvable. `agent_data/6` and its companions,
   maintained through the same data primitives clients use, with no bespoke
   registry object.
3. Matching is unification: exact, deterministic, on goal templates alone.
4. The transport sits behind a `com_` seam. TCP is the implementation; the API
   boundary is the architecture.
5. Nothing in the core knows what an LLM is — no import, no configuration key,
   no conditional. The extension boundary arrives in Phase 4 and attaches at
   the meta-agent hooks, which already exist.

## Deliverables, in dependency order

### 1.1 ICL — terms, parser, writer

The foundation; everything else is expressed in it.

- Term representation: struct, list, var, atom/string, integer, float,
  `icldataq/1`, `icldataq/3`.
- Structural equality and hashing — **not** printed-form equality.
- Parser for the restricted grammar, including the `[H|T]` list form and the
  period-terminated stream framing.
- Writer with minimal quoting; `toMinimallyQuoted` / `toForcedQuoted` /
  `toUnquoted` distinguished.
- UTF-8 throughout, recorded as a deliberate modernization.
- Unification with occurs-check policy documented.

*Tests:* round-trip property tests (parse ∘ write ≡ identity on structure);
a corpus of terms taken verbatim from the Developer's Guide examples; explicit
negative tests that ICL **rejects** what full Prolog would accept — `X is 1+2`,
`a :- b`, operator expressions.

### 1.2 ICL type system

- The supertype lattice, honouring `icldataq` having two parents.
- Type recognition by inspection.
- `icl_type/2` as a runtime-writable relation rather than a static enum.

*Tests:* subtype queries across every documented pair; runtime extension of the
hierarchy changes matchmaking outcomes.

### 1.3 Solvables

- `solvable(GoalTemplate, Parameters, Permissions)` with all shorthand forms
  normalizing to standard form.
- Types `procedure` / `data` / `trigger`; permissions `call` / `write` / `read`;
  parameters incl. `type`, `utility`, `callback`, `private`, `single_value`,
  `unique_values`, `persistent`, `bookkeeping`.
- `argspecs` / `argnames`, with the `inout(_, false)` default when absent.

*Tests:* every shorthand form in DG §5.1.5 normalizes identically; argspec
conformance including supertype acceptance.

### 1.4 Transport and event loop

- `com_` API with a TCP implementation; period-framed term stream.
- Event queue with priorities 1–10, default 5, and the documented rule:
  equal-or-lower priority queues, higher priority interrupts.
- `oaa_MainLoop`, `oaa_SetTimeout`, `app_idle`, `app_done`,
  `oaa_RegisterCallback`.
- Liveness from the start: pings, prompt dead-connection detection,
  reconnect-with-identity. Retrofitting this is what OAA had to do in 2.3.2.

*Tests:* priority ordering and interruption; a killed peer is detected within a
bounded time; an agent reconnects and retains identity.

### 1.5 Agent library

- `com_Connect`, `oaa_Register`, `oaa_Declare`, `oaa_Undeclare`,
  `oaa_Redeclare` (atomic).
- `oaa_Solve` with the parameter set: `address`, `blocking`, `reply`,
  `solution_limit`, `provider_limit`, `parallel_ok`, `reflexive`, `priority`,
  `time_limit`, `context`, `cache`, `unique_values`, `strategy`, and the return
  parameters `get_address`, `get_satisfiers`, `get_goal_id`.
- Strategy macros `query` / `action` / `inform`, and the precedence quirks
  (`reply(none)` overriding `blocking(true)` and `parallel_ok(false)`).
- Goal IDs unique per requester across reconnects.
- Delayed solutions: `oaa_DelaySolution`, `oaa_AddDelayedContextParams`,
  `oaa_ReturnDelayedSolutions`.

*Tests:* each parameter changes observable behaviour; `strategy(action)` sends
to exactly one provider and falls through on failure; `context` propagates
across a chain of solves through three agents.

### 1.6 Facilitator

- Registration and deregistration as data maintenance on `agent_data/6`.
- The initial solvable set: `agent_data/6`, `agent_host/3`, `agent_version/3`,
  `facilitator_data/5`, `can_solve/2`, `agent_location/4`, `icl_type/2`.
- The delegation sequence: unify → argspec filter → utility order → (meta-agent
  hook, no-op in Phase 1) → dispatch per strategy → collect → reply.
- The external event protocol: `ev_solve`, `ev_post_event`, `ev_post_declare`,
  `ev_update_data`, `ev_update_trigger`, `ev_register_solvables`, `connected`,
  `end_of_file`.
- Owned-fact cleanup when an agent disconnects.

Deferred to a later phase: compound goals, multi-facilitator hierarchies,
`propagate`, `direct_connect`, `test`-locatable queries.

*Tests:* the architectural scenarios — an advertised capability is discovered
and delegated; two providers of the same capability are ordered by utility;
`provider_limit` and `solution_limit` interact as documented; a disconnecting
agent's facts disappear.

### 1.7 Data solvables

- `oaa_AddData`, `oaa_RemoveData`, `oaa_ReplaceData` (atomic).
- `at_beginning`, `do_all`, `single_value`, `unique_values`.
- Ownership tracking and offline cleanup, modulated by `bookkeeping` /
  `persistent`.
- Blackboard: a client declaring a data solvable **on the facilitator** via
  `address(parent)`.

### 1.8 Triggers

- `oaa_AddTrigger` / `oaa_RemoveTrigger` for `comm`, `data` and `task`.
- Stored as instances of the built-in data solvable `oaa_trigger/5`, so
  installed triggers are queryable through `oaa_Solve` — this reflexivity is
  part of the architecture rather than an implementation detail.
- `on/1`, `test/1`, `recurrence/1` (`when` / `whenever` / integer).
- Actions as `oaa_Solve` or `oaa_Interpret` terms, with `reply` defaulting to
  `none` inside a trigger.
- Task triggers: the library leaves the condition unchecked, supplying
  `app_setup_trigger` notification and `oaa_CheckTriggers/3` for application
  code.
- `time` triggers stay out of the library, as historically — an Alarm agent
  supplies them, and is a Phase 3 sample.

### 1.9 Configuration and invocation

- Precedence: command line → environment → setup file, first value wins.
- `setup.pl` in the documented search order.
- `default_facilitator(tcp(Host, Port))`, `oaa_connect`, `oaa_listen`,
  `oaa_name`, `write_setup_file`, `on_port_exception` with all five actions.
- `OAA_CLASSIC` is the only mode Phase 1 knows about. The switch arrives here
  so that later work does not have to retrofit it; `OAA_LLM` is not yet a
  value the core accepts.

### 1.10 A running community

The Phase 1 acceptance test: start a Facilitator and three Prolog agents, have
one solve a goal it cannot answer itself, and observe the Facilitator discover,
delegate, collect and return. No LLM present, no LLM package installed, no
credentials configured.

## Layout

```
src/
  icl/          terms, parser, writer, unification, types
  runtime/      com_ transport, event loop, callbacks
  agents/       agent library (oaa_Solve, data, triggers)
  facilitator/  the facilitator agent
  prolog/       SWI-Prolog dialect seam
tests/
  icl/          parser, writer, unification, types
  facilitator/  delegation, registration, utility ordering
  agents/       library procedures
  integration/  running communities
  compatibility/ behaviour asserted against the historical record
examples/
  basic/        the minimal agent from the FAQ, reconstructed
  multi-agent/  the acceptance community
```

## Sequencing and commits

Roughly in the order above; ICL first, because nothing can be tested without
it, and the Facilitator after the agent library, because the Facilitator is an
agent. Commits stay small and prefixed as the project brief specifies:
`core:`, `docs:`, `research:`.

Each subsystem lands with its tests, its provenance label (ORIGINAL /
RECONSTRUCTED / MODERNIZED / NEW), and an update to
`research/compatibility-matrix.md` moving rows from `planned` to
`reconstructed` or `modernized`.

## Risks

- The Reference Manual has not been recovered. The Developer's Guide defers
  to it for exhaustive parameter lists, so Phase 1 will hit gaps; each becomes
  an entry in the relevant note's "open questions" rather than an invention.
  Retrieving it early would reduce that materially.
- Compound goals are deferred, and `compound.pl` runs to 43 KB, so the
  deferral is real scope. The Phase 1 Facilitator handles atomic goals.
- Backtracking across a network boundary is the hardest part of `oaa_Solve`'s
  Prolog-facing contract, and where a naive implementation will diverge
  first.
