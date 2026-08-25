# LLM agents

`oaa-next` extends OAA to support LLM-based agents as one optional piece
outside the historical core, not as a replacement for anything inside it.
Provenance: NEW / LLM EXTENSION. This code has no historical OAA equivalent
and lives entirely under `src/llm/`, never under
`src/icl/`, `src/agents/`, `src/facilitator/`, `src/runtime/` or `src/adt/`.

## Isolation from the core

With the extension off, an installation contains no LLM code at all. The code
is absent, not merely uninitialised. `tests/llm/test_isolation.pl` enforces
this claim: it walks every file under the core directories
(`src/icl`, `src/runtime`, `src/agents`, `src/facilitator`, `src/adt`) and
fails the suite if any of them so much as names anything starting `llm_`.
No core predicate, including `oaa_solve` and `fac_select`, has an
`if llm_enabled` branch. Such a branch would violate the isolation rule,
whether or not it took the LLM path.

## The mode gate

```
OAA_MODE=OAA_CLASSIC   # default
OAA_MODE=OAA_LLM
```

or `oaa_mode('OAA_LLM').` in a setup file, resolved through the same
command-line → environment → setup-file precedence as everything else in
`oaa_config.pl` (see [`communication.md`](communication.md)). The gate lives
in the extension's `llm_config.pl`. The core does not know an LLM exists and
has nothing to gate. `llm_require_enabled/0`
throws rather than failing quietly: an agent that needs the extension
refuses to start with a clear reason instead of registering and then
answering nothing.

## Provider independence

```prolog
llm_complete(Messages, Options, Response)
```

is the one interface `llm_agent.pl` and `llm_meta_agent.pl` call.
`Messages` are `message(Role, Text)` terms; `Options` and `Response` are
provider-agnostic. Providers register through `llm_register_provider/2` and
are queried through `llm_known_provider/2`, keeping vendor-specific code out
of the rest of the extension. `src/llm/providers/` currently has:

| Provider | Network |
|---|---|
| `llm_scripted.pl` | None. It returns deterministic canned responses, is the default, and runs every example and test that needs an LLM-shaped agent |
| `llm_anthropic.pl` | Anthropic Messages API over raw HTTP |
| `llm_openai.pl` | Any OpenAI-compatible chat-completions endpoint |

The scripted provider is a regular provider, not a test-only mock. It keeps
`make test` and every LLM example runnable without credentials or outbound
network calls.

`llm_openai.pl` implements the chat-completions protocol rather than an
OpenAI-only API. Most self-hosted runtimes copy that protocol: Ollama, vLLM,
LM Studio and llama.cpp's server all
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

Switching between the two changes only the adapter's destination, not its
code.
`tests/llm/test_llm_openai_wire.pl` exercises the actual request and reply
handling (model, message content, `max_tokens`, token usage, and a
content-filter refusal) against a local stub server standing in for either
of the above, so the wire format itself is under test, not only that a
provider by this name is registered.

## The LLM agent

The LLM agent is an ordinary agent: it connects, registers, answers callbacks
and calls `oaa_Solve`. It declares `interpret/2` and `propose_goal/2` as
solvables, implementing them through `llm_complete/3`. Nothing about
being a requester in the community changes because the capability behind a
goal is LLM-backed: `examples/llm/llm_client.pl` asks for `interpret/2`
with no idea an LLM is involved, gets an answer through the ordinary
delegation path, and would behave identically if a hand-written Prolog
agent answered the same goal shape instead.

## The LLM meta-agent

The LLM meta-agent declares
`meta(prioritize, Goal, Params, FacInfo, Result)`, the `prioritize` hook used
by `examples/multi-agent/preference_agent.pl`, per
[`delegation.md`](delegation.md). OAA already defined meta-agent consultation
as optional, external and fallible, with the
Facilitator's own deterministic default running whenever no meta-agent
returns anything usable. An LLM advising candidate ordering through that
existing hook adds LLM advice without changing the Facilitator itself. See
"Meta-agents are where an LLM belongs" in
[`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md).
`plan_query` and `execute_plan`, which would let a meta-agent take over
compound-goal routing rather than just advise it, appear in design material
but are not executable hook types in the recovered OAA 2.3.2 Facilitator.

## Boundaries

- The Facilitator retains matching, ordering and delegation. An LLM may
  advise an existing hook that the Facilitator is free to ignore.
- LLM agents speak ICL like every other agent.
- The extension is optional. Other community members cannot tell whether
  `interpret/2` is answered by an LLM-backed, scripted or hand-written agent.
- Providers may run locally. The scripted provider implements the complete
  interface without a network connection.

See the "Deliberate non-goals" table in
[`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md)
for the fuller list this extension was built to respect.
