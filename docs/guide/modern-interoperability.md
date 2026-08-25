# Modern interoperability

Provenance: INTEROPERABILITY ADAPTER. `src/interop/` bridges an OAA
community to two current agent-interop conventions, MCP and A2A, without
either becoming the community's internal protocol. Each adapter is an
ordinary OAA agent that translates at the edge; nothing inside the
community changes shape to accommodate one — see "Deliberate non-goals" in
[`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md)
for why MCP/A2A-as-internal-protocol was ruled out rather than merely not
attempted.

## `icl_json` — ICL and JSON

Two conversions, deliberately not one, because they trade off differently:

- **Tagged, lossless** (`icl_to_json/2`, `json_to_icl/2`) — every ICL term
  survives a round trip, including unbound variables and functor structure.
  A consumer needs to understand the tagging to make sense of the result;
  this is for another `oaa-next` process, or a consumer that wants the full
  term back.
- **Plain, lossy** (`icl_to_plain_json/2`, `plain_json_to_icl/2`) — natural
  JSON a consumer reads with no knowledge of ICL at all. Atoms and strings
  become indistinguishable on the way through, which is the cost of looking
  like ordinary JSON.

`solvable_to_schema/2` projects a solvable's `argnames` and `argspecs` into
a JSON Schema, which is what lets a solvable's declared inputs and outputs
become a tool definition without an OAA-specific decoder on the other end.

## `mcp_server` — an OAA community as an MCP server

`mcp_server_main/0` runs an MCP server, JSON-RPC 2.0 over stdio, in front of
a connected OAA community; `mcp_tools/1` lists the community's solvables as
MCP tools (via `solvable_to_schema/2`); `mcp_handle/2` turns a tool call
into an `oaa_Solve` and the result back into an MCP response.

What the translation loses is worth stating rather than glossing over: an
MCP tool call is one call with named arguments and one result. An ICL goal
can carry unbound variables anywhere, backtrack over several solutions, and
be a conjunction the Facilitator decomposes. The bridge reports every
solution it collects rather than choosing one, and leaves the richer forms —
genuinely open goals, compound requests — to callers that speak ICL
directly rather than through this adapter.

```sh
swipl bin/oaa-mcp-server.pl --
```

## `a2a_bridge` — an OAA community as an A2A agent

`a2a_agent_card/1` projects the Facilitator's registry as an A2A Agent
Card; `a2a_skill/2` turns one solvable into one A2A skill entry;
`a2a_handle/2` answers an A2A request the same way the MCP adapter answers
a tool call — by issuing an `oaa_Solve` and relaying what comes back.

The comparison with A2A is the more interesting one of the two, because the
two designs answer the same question differently rather than one merely
being a subset of the other. An A2A agent publishes its own card, and a
client reads cards to decide who to ask directly. In OAA, an agent tells one
Facilitator what it can do, and the Facilitator decides; the requester names
a goal, never an agent. The bridge has to manufacture the card OAA never
needed, from information the Facilitator already had for its own purposes.

## Where these fit the LLM extension

Neither adapter has anything to do with `OAA_LLM` — an MCP or A2A client
reaching into a community sees ordinary OAA capabilities, whether or not any
of them happen to be LLM-backed, and neither adapter is required for the LLM
extension to work (an LLM agent inside the community talks ICL like
everything else; see [`llm-agents.md`](llm-agents.md)). They compose because
each is orthogonal to the core, not because one depends on the other.
