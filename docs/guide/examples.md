# Examples

A guided tour of `examples/`, grouped by what each one is there to show
rather than by directory. Every example is runnable on its own; most start
their own Facilitator and agents as separate processes via
`tests/integration/community.pl`'s pattern, or can be launched by hand as
shown in the main [`README`](../../README.md#running-it).

## `examples/basic/` — the smallest community

- `square_agent.pl` / `greet_agent.pl` — one procedure solvable each. The
  smallest thing recognisably an OAA agent: declare a solvable, define the
  callback, connect, register, loop.
- `client.pl` — requests services it cannot perform itself, declaring no
  solvables of its own, which the Developer's Guide explicitly allows: an
  agent with nothing to offer the community can still be a pure requester.

Start here to see delegation transparency in its simplest form: the client
never names an agent, host or port.

## `examples/multi-agent/` — the rest of the architecture

| Example | Demonstrates |
|---|---|
| `data_agent.pl` / `data_client.pl` | A writable data solvable, and the full lifecycle: add, query, remove by exact value, remove by an unbound pattern — transcribed from SRI's own `test2/system/fac/data.otml` |
| `compound_client.pl` | A single request the Facilitator decomposes and delegates piece by piece, per [`delegation.md`](delegation.md) |
| `direct_agent.pl` / `direct_client.pl` | `direct_connect`: the Facilitator selects, then traffic bypasses it |
| `hierarchy_client.pl` / `root_client.pl` | A node facilitator answering both from its own community and by referral up to its root |
| `oracle_a.pl` / `oracle_b.pl` / `oracle_client.pl` | Two agents offering the same capability — utility ordering and multi-solution collection in action |
| `preference_agent.pl` | A `prioritize` meta-agent: declares `meta(prioritize, Goal, Params, FacInfo, Result)`, consulted by the Facilitator during ordering |
| `reporter.pl` | A blackboard reader — reads a data solvable it never declared, written by an agent it has never heard of |
| `robot_agent.pl` | `oaa_DelaySolution`/`oaa_ReturnDelayedSolutions`: a goal that takes real time to satisfy, answered asynchronously without the requester noticing |
| `sensor_agent.pl` | A blackboard writer — `address(parent)` turns an ordinary data solvable into shared state |
| `timed_client.pl` | A time trigger plus a delayed solution together, via the Alarm agent |
| `alarm_agent.pl` | The Alarm agent itself — time triggers exist only while it's connected |

`data_client.pl` is also where `ev_data_updated`'s wire shape is pinned:
`check_reply_arity/0` installs a `comm` trigger on itself before calling
`oaa_AddData`, because the ordinary reply path (`oaa_wait_for/3` inside
`oaa_AddData`) consumes that event before an `app_do_event` callback would
ever see it — see [`triggers.md`](triggers.md#comm-triggers-see-traffic-not-just-what-youre-waiting-for).

## `examples/llm/` — the optional extension

- `scripted_llm_agent.pl` — an LLM-backed agent running against the scripted
  provider, so its behaviour is deterministic and it makes no network call.
- `llm_client.pl` — asks for `interpret/2` with no idea an LLM is involved:
  the Facilitator finds an agent that provides it, and an answer comes back
  through the ordinary delegation path, exactly like any other capability.

These exist to demonstrate the isolation claim concretely: nothing about
being a requester in this community changes when the capability behind a
goal happens to be LLM-backed. See [`llm-agents.md`](llm-agents.md).

## Running the whole set

```sh
make test
```

runs every unit test plus `tests/integration/`'s live multi-process
community tests and `tests/compatibility/test_conformance.pl`, which drives
several of the `examples/multi-agent/` scripts directly against a real
Facilitator and checks their output against the historical record.
