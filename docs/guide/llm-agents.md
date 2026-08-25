# LLM agents

`oaa-next` extends OAA to support LLM-based agents as one optional piece
outside the historical core, not as a replacement for anything inside it.
Provenance: NEW / LLM EXTENSION — nothing here corresponds to any historical
OAA behaviour, which is why it lives entirely under `src/llm/`, never under
`src/icl/`, `src/agents/`, `src/facilitator/`, `src/runtime/` or `src/adt/`.

## The claim, and how it's checked

The project's claim about classic mode is negative: with the extension off,
an installation contains no LLM at all — not initialised and ignored,
*absent*. `tests/llm/test_isolation.pl` makes that checkable rather than
aspirational: it walks every file under the core directories
(`src/icl`, `src/runtime`, `src/agents`, `src/facilitator`, `src/adt`) and
fails the suite if any of them so much as names anything starting `llm_`.
This is why `oaa_solve`, `fac_select`, and every other core predicate has no
`if llm_enabled` branch anywhere — the branch would already be a violation,
whether or not it took the LLM path.

## The mode gate

```
OAA_MODE=OAA_CLASSIC   # default
OAA_MODE=OAA_LLM
```

or `oaa_mode('OAA_LLM').` in a setup file, resolved through the same
command-line → environment → setup-file precedence as everything else in
`oaa_config.pl` (see [`communication.md`](communication.md)). The gate lives
in `llm_config.pl`, in the extension, not the core — the core does not know
an LLM exists, so there is nothing in it to gate. `llm_require_enabled/0`
throws rather than failing quietly: an agent that needs the extension
refuses to start with a clear reason instead of registering and then
answering nothing.

## Provider independence

```prolog
llm_complete(Messages, Options, Response)
```

is the one interface `llm_agent.pl` and `llm_meta_agent.pl` call.
`Messages` are `message(Role, Text)` terms; `Options` and `Response` are
provider-agnostic. `llm_register_provider/2` and `llm_known_provider/2`
mean nothing in the extension is coupled to one vendor —
`src/llm/providers/` currently has:

| Provider | Network |
|---|---|
| `llm_scripted.pl` | None — deterministic canned responses, the default, and what every example and test that needs an LLM-shaped agent runs against |
| `llm_anthropic.pl` | Anthropic Messages API over raw HTTP |
| `llm_openai.pl` | Any OpenAI-compatible chat-completions endpoint |

The scripted provider existing as a first-class option (not a mock bolted
onto tests) is what keeps `make test` and every LLM example runnable with no
credentials and no outbound network call.

`llm_openai.pl` is written against the chat-completions shape rather than
against OpenAI specifically, because that shape is what most self-hosted
runtimes copy as well — Ollama, vLLM, LM Studio and llama.cpp's server all
answer at a `/chat/completions` path with the same request and reply shape
OpenAI's hosted API uses. `LLM_BASE_URL` (or `-llm_base_url`) is what
distinguishes them:

```
LLM_PROVIDER=openai
LLM_BASE_URL=https://api.openai.com/v1        # OpenAI's own hosted API
OPENAI_API_KEY=...

LLM_PROVIDER=openai
LLM_BASE_URL=http://localhost:11434/v1        # a local runtime instead
                                               # (no key needed for most)
```

No code changes between the two — only where the adapter points, which is
the point of a provider being an adapter rather than a special case.
`tests/llm/test_llm_openai_wire.pl` exercises the actual request and reply
handling (model, message content, `max_tokens`, token usage, and a
content-filter refusal) against a local stub server standing in for either
of the above, so the wire format itself is under test, not only that a
provider by this name is registered.

## The LLM agent

An ordinary agent — it connects, registers, answers callbacks, calls
`oaa_Solve` — that happens to declare `interpret/2` and `propose_goal/2` as
solvables and implement them by calling `llm_complete/3`. Nothing about
being a requester in the community changes because the capability behind a
goal is LLM-backed: `examples/llm/llm_client.pl` asks for `interpret/2`
with no idea an LLM is involved, gets an answer through the ordinary
delegation path, and would behave identically if a hand-written Prolog
agent answered the same goal shape instead.

## The LLM meta-agent

Declares `meta(prioritize, Goal, Params, FacInfo, Result)` — the same
`prioritize` hook `examples/multi-agent/preference_agent.pl` uses, per
[`delegation.md`](delegation.md). This is deliberate: OAA already defined
meta-agent consultation as optional, external, and fallible, with the
Facilitator's own deterministic default running whenever no meta-agent
returns anything usable. An LLM advising candidate ordering through that
existing seam is an additive extension that changes nothing about the
Facilitator itself — see "Meta-agents are where an LLM belongs" in
[`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md).
`plan_query` and `execute_plan`, which would let a meta-agent take over
compound-goal routing rather than just advise it, remain deferred.

## What this deliberately is not

- Not a replacement for the Facilitator: no LLM ever performs matching,
  ordering, or delegation itself; it only advises a hook the Facilitator
  already consults and may ignore.
- Not a replacement for ICL: LLM agents speak ICL like any other agent.
- Not mandatory: nothing else in the community can tell whether the agent
  answering `interpret/2` is LLM-backed, scripted, or hand-written.
- Not tied to a cloud provider: the scripted provider is a complete,
  network-free implementation of the same interface.

See the "Deliberate non-goals" table in
[`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md)
for the fuller list this extension was built to respect.
