# oaa-next documentation guide

This guide follows the shape of the historical OAA documentation set —
because recognisability is a goal of this project — while being written
independently rather than reproduced from it. Where a page states a
historical fact, it cites the Developer's Guide, the FAQ or the recovered
source by section, the same way `research/` does.

1. [Architecture](architecture.md) — the shape of a community and why it has that shape
2. [Concepts](concepts.md) — agent, solvable, goal, event, parameter list, in one place
3. [The Facilitator](facilitator.md) — registration, matching, delegation, routing
4. [Agents](agents.md) — what the agent library gives an agent for free
5. [The Agent Development Toolkit](adt.md) — generator, shell, debug, Start-It, Monitor
6. [ICL](icl.md) — the Interagent Communication Language
7. [Capability registration](capability-registration.md) — solvables in depth
8. [Delegation](delegation.md) — how a goal finds a solver
9. [Tasking](tasking.md) — triggers, delayed solutions, and asynchronous work
10. [Triggers](triggers.md) — comm, data, task and time triggers
11. [Communication](communication.md) — the wire: transport, framing, events
12. [Data](data.md) — data solvables, ownership, blackboards
13. [Examples](examples.md) — a guided tour of `examples/`
14. [Tutorials](tutorials.md) — build a two-agent community from nothing
15. [API reference](api-reference.md) — every exported predicate, by module
16. [LLM agents](llm-agents.md) — the optional `OAA_LLM` extension
17. [Modern interoperability](modern-interoperability.md) — MCP and A2A adapters
18. [Historical notes](historical-notes.md) — where oaa-next's behaviour was settled by evidence rather than by design choice, and where it deliberately diverges

Two documents outside this guide carry weight the pages above don't
duplicate: [`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md)
maps every historical concept to its status here, and
[`../historical/notice.md`](../historical/notice.md) is the trademark and
licensing notice, not a design document.
