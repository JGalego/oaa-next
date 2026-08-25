# Architecture

An OAA community is a set of independent processes — agents — that share no
memory and know nothing about each other's identity, location or
implementation language. What holds them together is a single distinguished
agent, the Facilitator, and a shared language for describing what an agent
can do and what it wants done: ICL, the Interagent Communication Language.

```
            +-------------+
            | Facilitator |
            +------+------+
                   |  ICL over TCP
       +-----------+-----------+-----------+
       |           |           |           |
   +---+---+   +---+---+   +---+---+   +---+---+
   | Agent |   | Agent |   | Agent |   | Agent |
   +-------+   +-------+   +-------+   +-------+
```

An agent connects to a Facilitator and declares its capabilities as
*solvables*: goal templates it can satisfy. It then asks the Facilitator to
solve goals on its behalf, and answers goals the Facilitator routes to it.
Nothing in that description mentions how a goal reaches a solver, and that is
the point — delegation transparency means a requester does not know or care
who ends up doing the work (Developer's Guide §3.2).

## Why a Facilitator, and not a registry or a message bus

A service registry answers "who provides X" and stops there — the caller
still has to invoke the provider itself. A message bus moves bytes and
leaves matching and routing to whoever is listening. The Facilitator does
neither of those alone: it holds a live index of capabilities
(`agent_data/6`), matches a goal against that index by unification, orders
the matches by declared utility, decomposes a compound goal into pieces it
can route independently, and collects and relays the replies. Removing any
one of those responsibilities changes what a program written against OAA can
assume, which is why `oaa-next` keeps the Facilitator as an architectural
component rather than replacing it with a lookup step in front of an LLM
router. See "Deliberate non-goals" in
[`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md).

## Why ICL, and not JSON or a bare RPC call

ICL goals carry unbound logic variables, unify against templates rather than
matching by name or schema, and can be conjunctions the Facilitator picks
apart to delegate separately. A JSON-RPC call is one call with named
arguments and one result; it cannot represent any of that. Two layers make
up ICL: a conversational layer of event types and parameter lists, and a
content layer of goals, triggers and data elements written in ICL itself —
comparable, as the Developer's Guide puts it, to KQML wrapping KIF (§4.3).
Keeping content in ICL rather than an opaque payload is what lets the
Facilitator read a request well enough to decompose it. Full treatment in
[`icl.md`](icl.md).

## The Facilitator is an agent

A Facilitator uses the same agent library as any client, connects the same
way, and answers requests through the same callback path — there is no
separate service type for it (Developer's Guide §10.2). Concretely, `fac.pl`
declares the facilitator solvables (`can_solve`, `agent_data`, and the rest)
and runs the same event loop as `oaa_run.pl` gives any agent. This is what
lets a Facilitator become a client of another Facilitator with no separate
federation protocol: a node facilitator just connects upward like any
client, registering the union of what its own clients declare
(Developer's Guide §10.2; see [`facilitator.md`](facilitator.md)).

## A community's lifecycle

1. A Facilitator starts and listens.
2. Client agents connect (`com_Connect`) and register (`oaa_Register`),
   declaring their solvables.
3. A requester calls `oaa_Solve` (or `oaa_AddData` / `oaa_RemoveData`, which
   are solves under a different name) without naming a solver.
4. The Facilitator matches the goal against its registry, orders candidates
   by utility, and dispatches to each — directly for a simple goal, one
   dispatch at a time for a compound one, so it never blocks waiting on an
   agent (`fac_compound.pl`).
5. Solvers reply; the Facilitator collects and relays the result.

Meta-agents can participate in step 4 without changing anything else: a
`prioritize` meta-agent reorders the candidate list, a `lookup` meta-agent is
asked when nothing local matches. Both are optional and the Facilitator's
deterministic default runs when none is consulted or none answers — which is
exactly the shape an LLM extension needs (see [`llm-agents.md`](llm-agents.md)
and the "Meta-agents are where an LLM belongs" note in the compatibility
matrix).

## What a modernization changes, and what it doesn't

`oaa-next` runs on SWI-Prolog rather than SICStus or Quintus, and current
transport and process libraries rather than 2007-era ones. Those are version
changes. The architecture above — Facilitator as delegator, ICL as the
content language, solvables matched by unification — is preserved exactly,
because it is what OAA *is*; replacing any piece of it would produce a
different architecture wearing OAA's name. See §38 concerns tracked in the
project brief and enforced by `tests/llm/test_isolation.pl` for the one part
of this system, the LLM extension, that is genuinely new.
