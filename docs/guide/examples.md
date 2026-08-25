# Examples

The examples are grouped here by what they demonstrate, not by directory.
Every example is runnable on its own; most start
their own Facilitator and agents as separate processes via
`tests/integration/community.pl`'s pattern, or can be launched by hand as
shown in the main [`README`](../../README.md#running-it).

## `examples/basic/`: the smallest community

- `square_agent.pl` / `greet_agent.pl`: one procedure solvable each. The
  smallest thing recognisably an OAA agent: declare a solvable, define the
  callback, connect, register, loop.
- `client.pl`: requests services it cannot perform itself, declaring no
  solvables of its own, which the Developer's Guide explicitly allows: an
  agent with nothing to offer the community can still be a pure requester.

These files show delegation transparency in its simplest form: the client
never names an agent, host or port.

## `examples/multi-agent/`: the rest of the architecture

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
| `office_mail_agent.pl` / `office_telephone_agent.pl` / `office_client.pl` | The Office Assistant demo — see below |

`data_client.pl` is also where `ev_data_updated`'s wire shape is pinned:
`check_reply_arity/0` installs a `comm` trigger on itself before calling
`oaa_AddData`, because the ordinary reply path (`oaa_wait_for/3` inside
`oaa_AddData`) consumes that event before an `app_do_event` callback would
ever see it. See [`triggers.md`](triggers.md#comm-triggers-observe-all-traffic).

## `examples/llm/`: the optional extension

- `scripted_llm_agent.pl`: an LLM-backed agent running against the scripted
  provider, so its behaviour is deterministic and it makes no network call.
- `llm_client.pl`: asks for `interpret/2` with no idea an LLM is involved:
  the Facilitator finds an agent that provides it, and an answer comes back
  through the ordinary delegation path, exactly like any other capability.
- `office_assistant.pl`: the natural-language front end for the Office
  Assistant demo, below.

These examples exercise the isolation claim. A requester behaves the same
whether the capability behind a goal is LLM-backed or not. See
[`llm-agents.md`](llm-agents.md).

## The Office Assistant demo

`office_mail_agent.pl`, `office_telephone_agent.pl` (both
`examples/multi-agent/`), `office_assistant.pl` (`examples/llm/`) and
`office_client.pl` (`examples/multi-agent/`) together reconstruct the
pattern behind what Adam Cheyer's own site calls "the 'original' OAA
demonstration." Citations and the limits of the evidence are in
[`../../research/office-demo.md`](../../research/office-demo.md). The
client sends the demo's documented command verbatim:

> When mail arrives for me about "security" get it to me by telephone.

The LLM agent's `propose_goal/2` returns an ICL `oaa_AddTrigger(...)` term,
which the client installs as a data trigger on the mail
solvable that delegates delivery to the Telephone agent when a matching
message arrives. Two messages then "arrive" (an ordinary `oaa_AddData`, run
by whichever agent has something to deliver, in this case the client itself);
only the one about security is delivered.

This is provenance NEW / ILLUSTRATIVE, not RECONSTRUCTED: the trigger
pattern and the exact command are attested by a primary-source screenshot
and a corroborating 1997 paper, but the historical Notify agent's fuller
delegation logic (location-aware, password-confirmed) is only described in
prose about a different example and isn't rebuilt here. Speech recognition,
handwriting recognition and real telephony are out of scope for the reason
they always are for oaa-next: they were I/O components wrapped as agents,
not part of the architecture itself. `tests/llm/test_office_demo.pl` keeps
this example working.

### A visual front end

`office_ui_agent.pl` and `office_ui/index.html` (both
`examples/multi-agent/`) add a graphical front end: a hand-drawn
reconstruction of the screenshot's own room composition, served over plain
HTTP by another ordinary agent standing in for a "User Interface Agent."
The "visual reconstruction" section of
[`../../research/office-demo.md`](../../research/office-demo.md) describes
what this does and does not claim about fidelity.

Run it alongside the rest of the community:

```sh
swipl bin/facilitator.pl
swipl examples/multi-agent/office_mail_agent.pl
swipl examples/multi-agent/office_telephone_agent.pl
swipl examples/llm/office_assistant.pl -- -oaa_mode OAA_LLM
swipl examples/multi-agent/office_ui_agent.pl
```

then open the URL the last one prints. The command bar comes pre-filled
with the screenshot's own sentence; "Do It!" installs the trigger through
`propose_goal/2` as `office_client.pl` does. The two "simulate mail arriving"
buttons send mail through ordinary `oaa_AddData` calls. Only the message
about "security" is delivered, as shown by the activity log and a
"ring ring…" tag. `tests/llm/test_office_ui.pl` exercises the
same three HTTP endpoints (`/command`, `/mail`, `/state`) a browser uses,
which keeps the browser and non-visual clients under the same tests.

## Running the whole set

```sh
make test
```

runs every unit test plus `tests/integration/`'s live multi-process
community tests and `tests/compatibility/test_conformance.pl`, which drives
several of the `examples/multi-agent/` scripts directly against a real
Facilitator and checks their output against the historical record.
