# Architecture

An OAA community is a set of independent processes, called agents, that share no
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
The requester does not know or care how a goal reaches a solver or who ends
up doing the work. The Developer's Guide calls this delegation transparency
(§3.2).

## The Facilitator's role

A service registry answers "who provides X," leaving the caller to invoke
the provider. A message bus moves bytes and
leaves matching and routing to whoever is listening. The Facilitator does
neither of those alone: it holds a live index of capabilities
(`agent_data/6`), matches a goal against that index by unification, orders
the matches by declared utility, decomposes a compound goal into pieces it
can route independently, and collects and relays the replies. Removing any
one of those responsibilities changes what a program written against OAA can
assume. `oaa-next` therefore keeps the Facilitator as an architectural
component and does not replace it with a lookup step in front of an LLM
router. See "Deliberate non-goals" in
[`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md).

## Why OAA uses ICL

ICL goals carry unbound logic variables, unify against templates rather than
matching by name or schema, and can be conjunctions the Facilitator picks
apart to delegate separately. A JSON-RPC call is one call with named
arguments and one result; it cannot represent any of that. Two layers make
up ICL: a conversational layer of event types and parameter lists, and a
content layer of goals, triggers and data elements written in ICL itself.
The Developer's Guide compares this to KQML wrapping KIF (§4.3). Because the
content remains in ICL, the Facilitator can read and decompose a request.
Full treatment is in [`icl.md`](icl.md).

## The Facilitator is an agent

A Facilitator uses the same agent library as any client, connects through the
same API, and answers requests through the same callback path. There is no
separate service type for it (Developer's Guide §10.2). Concretely, `fac.pl`
declares the facilitator solvables (`can_solve`, `agent_data`, and the rest)
and runs the event loop that `oaa_run.pl` gives any agent. A Facilitator can
therefore become another Facilitator's client without a separate federation
protocol: a node facilitator connects upward like any
client, registering the union of what its own clients declare
(Developer's Guide §10.2; see [`facilitator.md`](facilitator.md)).

## A community's lifecycle

1. A Facilitator starts and listens.
2. Client agents connect (`com_Connect`) and register (`oaa_Register`),
   declaring their solvables.
3. A requester calls `oaa_Solve` (or `oaa_AddData` / `oaa_RemoveData`, which
   are solves under a different name) without naming a solver.
4. The Facilitator matches the goal against its registry, orders candidates
   by utility, and dispatches to each: directly for a simple goal, one
   dispatch at a time for a compound one, so it never blocks waiting on an
   agent (`fac_compound.pl`).
5. Solvers reply; the Facilitator collects and relays the result.

Meta-agents can participate in step 4 without changing anything else: a
`prioritize` meta-agent reorders the candidate list, a `lookup` meta-agent is
asked when nothing local matches. Both are optional and the Facilitator's
deterministic default runs when none is consulted or none answers. An LLM
extension fits this existing design (see [`llm-agents.md`](llm-agents.md)
and the "Meta-agents are where an LLM belongs" note in the compatibility
matrix).

## Modernization boundaries

`oaa-next` runs on SWI-Prolog rather than SICStus or Quintus, with current
transport and process libraries in place of their 2007-era counterparts.
Those are version changes. The architecture above preserves the Facilitator
as delegator, ICL as the content language, and unification-based solvable
matching. Replacing any of those pieces would produce a
different architecture wearing OAA's name. See §38 concerns tracked in the
project brief and enforced by `tests/llm/test_isolation.pl` for the one part
of this system, the LLM extension, that is genuinely new.
