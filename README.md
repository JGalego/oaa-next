# oaa-next

An independent reimplementation and modernization of SRI International's Open
Agent Architecture (OAA), extended to support LLM-based agents.

oaa-next is not a new agent framework inspired by OAA. It is an attempt to
rebuild the original architecture and developer experience as faithfully as the
evidence permits, using current implementations of the original technology
stack, and then to add LLM support as an optional extension that does not
change the architecture underneath it.

The question the project exists to answer:

> What does the original Open Agent Architecture look like when rebuilt
> faithfully with modern implementations, and given an LLM as a reasoning
> substrate?

## Status: Phase 0 — archaeology

No implementation code yet, by design. The historical record is recovered and
documented first. Everything currently in this repository lives under
`research/`.

| Phase | | |
|---|---|---|
| 0 | Archaeology — recover sources, establish provenance and licensing | **in progress** |
| 1 | Historical core — ICL, agent model, solvables, Facilitator, Prolog | not started |
| 2 | Agent Development Toolkit | not started |
| 3 | Examples and compatibility tests | not started |
| 4 | LLM extension — optional, disabled by default | not started |
| 5 | Modern interoperability — MCP, A2A | not started |
| 6 | Documentation and historical comparison | not started |

## What Phase 0 established

**The original distribution survives.** SRI's original host,
`www.ai.sri.com/~oaa`, is still serving the complete OAA 2.3.2 tree — source,
runtime and documentation. No archive was needed. Provenance and SHA-256 hashes
for everything consulted are in [`research/recovered-artifacts.md`](research/recovered-artifacts.md).

**OAA 2.3.2 is LGPL-2.1-or-later, not a non-commercial license.** The
frequently-cited FAQ describes a non-commercial "community license", and that
was true of 2.3.0 and 2.3.1. The final release, in June 2007, relicensed the
software; this is confirmed by the license file, the distribution's own
licensing statement, the release notes, and LGPL headers on 413 of 596 source
files. Details, including what the superseded license said, are in
[`research/licensing.md`](research/licensing.md).

**The Facilitator is written in Prolog, and its source was published.** Under
the older non-commercial license the Facilitator was executable-only and could
not be modified or disassembled. Under the LGPL, `fac.pl` — 140 KB of Prolog by
Adam Cheyer and David Martin — ships in the distribution. A faithful
reconstruction is therefore far more tractable than it would have been a decade
ago.

**The historical Prolog was SICStus and Quintus, not SWI.** OAA carried an
explicit dialect-compatibility layer and discovered the running system at
runtime. Targeting SWI-Prolog adds a third dialect to a design that already
expected more than one — see [`research/compatibility-matrix.md`](research/compatibility-matrix.md).

## Approach to the historical code

The recovered source is used as the specification of record for behaviour that
the documentation leaves underspecified. oaa-next code is authored
independently rather than ported.

The LGPL finding means deriving directly from OAA 2.3.2 would also be lawful,
and that option is documented rather than dismissed — but taking it would place
oaa-next's own license under LGPL-2.1-or-later, so it is the project owner's
call. Until that call is made, no historical OAA source or binary is committed
to this repository.

Every subsystem will be labelled ORIGINAL, RECONSTRUCTED, MODERNIZED, NEW, or
INTEROPERABILITY ADAPTER, so that anyone can tell where a given behaviour came
from.

## Repository layout

```
research/
  sources.md                 citation index and evidence hierarchy
  chronology.md              OAA release history
  recovered-artifacts.md     provenance and hashes
  licensing.md               licensing, copyright, trademark
  compatibility-matrix.md    historical concept -> oaa-next mapping
  implementation-notes/      per-subsystem behavioural notes
docs/
  historical/                historical and trademark notices
```

Directories are created as there is something to put in them.

## License

**Not yet chosen.** The project deliberately defers this until the provenance
of any incorporated historical material is settled; see
[`research/licensing.md`](research/licensing.md) §5. Choosing a permissive
license before knowing what is being distributed would be exactly the mistake
this project is trying to avoid.

## Trademark and affiliation

oaa-next is an independent reimplementation of SRI International's Open Agent
Architecture. It is not an SRI International project, not an official
continuation of SRI OAA, and not endorsed by or affiliated with SRI
International.

"OAA" is a registered trademark, and "Open Agent Architecture" is a trademark,
of SRI International. The live status of those marks has not been verified, and
the project name is itself an open question — see
[`research/licensing.md`](research/licensing.md) §6. See also
[`docs/historical/notice.md`](docs/historical/notice.md).
