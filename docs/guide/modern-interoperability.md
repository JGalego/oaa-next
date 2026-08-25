# Modern interoperability

Provenance: INTEROPERABILITY ADAPTER. `src/interop/` bridges an OAA
community to two current agent-interop conventions, MCP and A2A, without
either becoming the community's internal protocol. Each adapter is an
ordinary OAA agent that translates at the edge; nothing inside the
community changes shape to accommodate one. The "Deliberate non-goals" in
[`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md)
explain why MCP and A2A were rejected as internal protocols.

## `icl_json` — ICL and JSON

The module provides two conversions with different properties:

- **Tagged, lossless** (`icl_to_json/2`, `json_to_icl/2`) — every ICL term
  survives a round trip, including unbound variables and functor structure.
  A consumer needs to understand the tagging to make sense of the result;
  this is for another `oaa-next` process, or a consumer that wants the full
  term back.
- **Plain, lossy** (`icl_to_plain_json/2`, `plain_json_to_icl/2`) — natural
  JSON a consumer reads with no knowledge of ICL at all. Atoms and strings
  become indistinguishable during conversion so that the result remains
  ordinary JSON.

`solvable_to_schema/2` projects a solvable's `argnames` and `argspecs` into
a JSON Schema. The declared inputs and outputs then become a tool definition
that does not require an OAA-specific decoder.

## `mcp_server` — an OAA community as an MCP server

`mcp_server_main/0` runs an MCP server, JSON-RPC 2.0 over stdio, in front of
a connected OAA community; `mcp_tools/1` lists the community's solvables as
MCP tools (via `solvable_to_schema/2`); `mcp_handle/2` turns a tool call
into an `oaa_Solve` and the result back into an MCP response.

The translation cannot preserve all ICL semantics. An MCP tool call is one
call with named arguments and one result. An ICL goal
can carry unbound variables anywhere, backtrack over several solutions, and
be a conjunction the Facilitator decomposes. The bridge reports every
solution it collects rather than choosing one. Genuinely open goals and
compound requests remain available only to callers that speak ICL directly.

```sh
swipl bin/oaa-mcp-server.pl --
```

## `a2a_bridge` — an OAA community as an A2A agent

`a2a_agent_card/1` projects the Facilitator's registry as an A2A Agent
Card; `a2a_skill/2` turns one solvable into one A2A skill entry;
`a2a_handle/2` answers an A2A request by issuing an `oaa_Solve` and relaying
the result, as the MCP adapter does for a tool call.

The A2A and OAA designs answer the same question differently. An A2A agent
publishes its own card, and a
client reads cards to decide who to ask directly. In OAA, an agent tells one
Facilitator what it can do, and the Facilitator decides; the requester names
a goal, never an agent. The bridge has to manufacture the card OAA never
needed, from information the Facilitator already had for its own purposes.

## Where these fit the LLM extension

Neither adapter depends on `OAA_LLM`. An MCP or A2A client
reaching into a community sees ordinary OAA capabilities, whether or not any
of them happen to be LLM-backed, and neither adapter is required for the LLM
extension to work. An LLM agent inside the community talks ICL like
everything else; see [`llm-agents.md`](llm-agents.md). The adapters and LLM
extension can be combined, but none depends on another.
