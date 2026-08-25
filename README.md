# oaa-next

An independent reimplementation and modernization of SRI International's Open
Agent Architecture (OAA), extended to support LLM-based agents.

The aim is to rebuild the original architecture and developer experience as
faithfully as the evidence permits, using current implementations of the
original technology stack, and then to add LLM support as an optional
extension that leaves the architecture underneath it alone.

The question the project exists to answer:

> What does the original Open Agent Architecture look like when rebuilt
> faithfully with modern implementations, and given an LLM as a reasoning
> substrate?

## Status

| Phase | | |
|---|---|---|
| 0 | Archaeology — recover sources, establish provenance and licensing | **done** |
| 1 | Historical core — ICL, agent model, solvables, Facilitator, Prolog | **running** |
| 2 | Agent Development Toolkit | not started |
| 3 | Examples and compatibility tests | not started |
| 4 | LLM extension — optional, disabled by default | not started |
| 5 | Modern interoperability — MCP, A2A | not started |
| 6 | Documentation and historical comparison | not started |

The core runs in SWI-Prolog. A Facilitator and client agents, each its own
operating-system process, exchange ICL over TCP: capabilities are declared as
solvables, matched by unification, ordered by utility and delegated. Data
solvables, ownership, blackboards and triggers work. The test suite passes.

Nothing in the core has an LLM dependency of any kind. `OAA_CLASSIC` names a
system that contains no LLM, so there is nothing to switch off.

Compound goals, facilitator hierarchies, direct connect, meta-agent
consultation and time triggers are deferred, and listed as such in
[`research/compatibility-matrix.md`](research/compatibility-matrix.md).

## Running it

```sh
make test                     # the whole suite, including a live community

# or start a community by hand
swipl bin/facilitator.pl -- -write_setup_file setup.pl &
swipl examples/basic/square_agent.pl -- &
swipl examples/basic/greet_agent.pl -- &
swipl examples/basic/client.pl --
```

The client prints `square(7) = 49`, backtracks over the greetings, and fails
on a goal nothing can solve. It names no agent, no host and no port; the
Facilitator works out who to ask.

## What Phase 0 established

The original distribution survives. SRI's host, `www.ai.sri.com/~oaa`, is
still serving the complete OAA 2.3.2 tree: source, runtime and documentation.
No archive was needed. Provenance and SHA-256 hashes for everything consulted
are in [`research/recovered-artifacts.md`](research/recovered-artifacts.md).

OAA 2.3.2 is LGPL-2.1-or-later. The frequently cited FAQ describes a
non-commercial "community license", which held for 2.3.0 and 2.3.1; the final
release, in June 2007, relicensed the software. The license file, the
distribution's own licensing statement, the release notes and the per-file
headers all agree. Details, including what the superseded license said, are in
[`research/licensing.md`](research/licensing.md).

The Facilitator is written in Prolog, and its source was published. Under the
older non-commercial license the Facilitator was executable-only and could not
be modified or disassembled. Under the LGPL, `fac.pl` — 140 KB of Prolog by
Adam Cheyer and David Martin — ships in the distribution, which makes a
faithful reconstruction far more tractable than it would have been a decade
ago.

The historical Prolog was SICStus, with Quintus as a fallback. OAA carried a
dialect-compatibility layer and discovered the running system at runtime, so
targeting SWI-Prolog adds a third dialect to a design that already expected
more than one — see
[`research/compatibility-matrix.md`](research/compatibility-matrix.md).

## Approach to the historical code

The recovered source is used as the specification of record for behaviour that
the documentation leaves underspecified. oaa-next code is authored
independently rather than ported.

The LGPL finding means deriving directly from OAA 2.3.2 would also be lawful,
and that option stays documented. Taking it would place oaa-next's own license
under LGPL-2.1-or-later, so the choice belongs to the project owner. Until it
is made, no historical OAA source or binary is committed here.

Every subsystem will be labelled ORIGINAL, RECONSTRUCTED, MODERNIZED, NEW, or
INTEROPERABILITY ADAPTER, so that anyone can tell where a given behaviour came
from.

## Repository layout

```
src/
  icl/          terms, tokenizer, parser, writer, types, parameter lists
  runtime/      com_ transport, event loop, configuration
  agents/       agent library, solvables, data store, triggers
  facilitator/  the Facilitator and its delegation rules
bin/            runnable Facilitator
examples/       runnable agents
tests/          unit tests, plus a live multi-process community
research/
  sources.md                 citation index and evidence hierarchy
  chronology.md              OAA release history
  recovered-artifacts.md     provenance and hashes
  licensing.md               licensing, copyright, trademark
  compatibility-matrix.md    historical concept -> oaa-next mapping
  implementation-notes/      per-subsystem behavioural notes
docs/
  roadmap/                   phase plans
  historical/                historical and trademark notices
```

Directories are created as there is something to put in them.

## License

Not yet chosen. The choice waits on the provenance of any incorporated
historical material being settled; see
[`research/licensing.md`](research/licensing.md) §5. Picking a permissive
license before knowing what is being distributed is the mistake this project
is set up to avoid.

## Trademark and affiliation

oaa-next is an independent reimplementation of SRI International's Open Agent
Architecture. It is not an SRI International project, not an official
continuation of SRI OAA, and not endorsed by or affiliated with SRI
International.

"OAA" is a registered trademark, and "Open Agent Architecture" is a trademark,
of SRI International. The live status of those marks has not been verified,
and the project name remains an open question — see
[`research/licensing.md`](research/licensing.md) §6. See also
[`docs/historical/notice.md`](docs/historical/notice.md).
