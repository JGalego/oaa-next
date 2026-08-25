# Primary and secondary sources for OAA reconstruction

This file is the citation index for the oaa-next reconstruction. Every
historically significant claim made elsewhere in this repository should be
traceable to an entry here.

All retrieval dates in this file are **2026-08-24** unless stated otherwise.

## Evidence hierarchy used by this project

When sources disagree, they are weighed in roughly this order:

1. Original OAA source code (recovered — see `recovered-artifacts.md`)
2. Observed behaviour of original OAA executables
3. The original OAA license files, as shipped in the distribution
4. The OAA Developer's Guide and reference manuals
5. Original OAA examples and sample agents
6. Original OAA papers by the OAA authors
7. Other SRI technical documentation
8. Patents and technical disclosures
9. Contemporary academic descriptions
10. Later secondary sources

Where sources conflict, the conflict is recorded rather than silently
resolved. The most significant conflict found so far concerns licensing and is
documented in `licensing.md`.

---

## Tier 1 — Original source code and distribution

### OAA 2.3.2 build 02 distribution (Windows)

- Title: `oaa2.3.2_02.zip`
- Origin: `https://www.ai.sri.com/~oaa/distribution/v2.3/2.3.2/download/windows/oaa2.3.2_02.zip`
- Status at retrieval: **live and served directly from SRI's original host**
- SHA-256: `1ca1e616be3f10cfaccbb54e14340a851e7ab0d3582d05fa6cc984514b583bd5`
- Size: 28,341,377 bytes; 3,642 archive entries
- Contents: full source for the Facilitator, all four agent libraries, the
  runtime tools, the test suite and the sample agents.

This is the single most authoritative artifact recovered. It supersedes every
secondary description of OAA's implementation. A Unix counterpart
(`unix/oaa2.3.2_02.tar.gz`, ~64 MB) is served from the same directory and was
not retrieved; per the distribution's own README the two differ only in
line endings and platform-specific binaries.

Not committed to this repository; see `recovered-artifacts.md`.

### Key files within the distribution

| Path | Size | Significance |
|---|---|---|
| `src/facilitator/fac.pl` | 140,855 B | The Facilitator, in Prolog. Authors named in header: Adam Cheyer, David Martin |
| `src/facilitator/compound.pl` | 43,839 B | Compound-goal decomposition and routing |
| `src/facilitator/translations.pl` | 25,434 B | Cross-version ICL translation |
| `src/oaalib/prolog/oaa.pl` | 262,490 B | The Prolog agent library |
| `src/oaalib/prolog/com_tcp.pl` | 52,252 B | TCP transport layer (`com_` API) |
| `src/oaalib/prolog/spcompat.pl` | 37,166 B | SICStus compatibility shim |
| `src/oaalib/java/icl_parser/OaaPrologNetParse.g` | 13,497 B | ANTLR grammar for ICL (Java library) |
| `src/oaalib/c/icl_parser/parser/parser.g` | 31,839 B | PCCTS grammar for ICL (C library) |
| `src/licenses/lgpl.txt` | 26,940 B | GNU LGPL v2.1, February 1999 |
| `src/licenses/LicenseInfo.txt` | — | Distribution licensing statement and third-party inventory |
| `doc/history.txt` | 1,065 lines | Release-by-release change history |
| `doc/README.txt`, `README_PROLOG.txt`, `README_RUNTIME.txt`, `README_SRC.txt` | — | Installation, Prolog toolchain and build notes |

## Tier 2 — Original documentation

### OAA Developer's Guide, Version 2.3.2

The primary written specification. Structure and semantics of ICL, solvables,
the Facilitator, `oaa_Solve`, data solvables, triggers, and multi-facilitator
topologies are all taken from here.

- Live: `https://www.ai.sri.com/~oaa/distribution/v2.3/2.3.2/doc/devguide.html`
- Archived PDF (USPTO PTACTS, filed as *IPA Technologies, Exhibit 2064*,
  47 pages, page footer capture date 2020-01-28):
  `https://ptacts.uspto.gov/ptacts/public-informations/petitions/1524561/download-documents?artifactId=iK1M05HF8HIw2xZODwKZu9exIW_EFYwVPgYElfQmer0q_bgWxeWznf0`
- SHA-256 of retrieved PDF: `6e532f891623eee5d7fddb061ae25a8a091dd27d1ddb8bb1e998d00d45ee390d`

A second USPTO artifact was cited in the project brief as an alternate copy:

- `https://ptacts.uspto.gov/ptacts/public-informations/petitions/1524643/download-documents?artifactId=zsxRuFxemeOTNwYyVAFdCPIaQ4a8AmeW_4DXeiH0iDcp-OsIPl_uMV4`
- SHA-256: `6e532f891623eee5d7fddb061ae25a8a091dd27d1ddb8bb1e998d00d45ee390d`

The two USPTO artifacts turn out to be byte-identical: one document served
under two petition IDs. They give no independent corroboration of each other.

### OAA v2.x FAQ

- Live: `https://www.ai.sri.com/~oaa/distribution/doc/oaa-faq-v2.html`
- Archived PDF (USPTO PTACTS, *IPA Technologies, Exhibit 2065*, 6 pages):
  `https://ptacts.uspto.gov/ptacts/public-informations/petitions/1524583/download-documents?artifactId=3ThNCwBiXW49cqlqF25YQLGCt8e8SwPH8KcaRP5U1gxqPg7edU_9ZIY`
- SHA-256: `3c32ac2bd223ed2f206117888614f296fc962a3707af232acd18c89c378c5645`

Source of the language-support list, the four trigger types, the three-function
description of the Facilitator, and the widely-quoted "community license"
statement. Note that the FAQ describes OAA 2.x *before* the final release; see
`licensing.md`.

### OAA Research Community License, Version 2.3

- `https://www.ai.sri.com/~oaa/distribution/v2.3/license-v2.html`
- SHA-256 of retrieved HTML: `b80944f7776131ffd288b726271cb253b435c6e1a77567c34fec9e677919ab8f`

The actual non-commercial license that governed OAA 2.3.0/2.3.1. Superseded for
2.3.2. Recovered because the FAQ's summary alone is not a license.

### Other live SRI OAA pages retrieved

| Page | URL |
|---|---|
| OAA home (frameset + `main.html`) | `https://www.ai.sri.com/~oaa/main.html` |
| 2.3.0 distribution page (links the community license) | `https://www.ai.sri.com/~oaa/distribution/v2.3/main.html` |
| 2.3.2 download page (states LGPL) | `https://www.ai.sri.com/~oaa/distribution/v2.3/2.3.2/download/welcome.shtml` |
| 2.3.2 documentation index | `https://www.ai.sri.com/~oaa/distribution/v2.3/2.3.2/documentation.html` |

Documentation still linked from that index and not yet retrieved: the OAA 2.3
Tutorial, the OAA Reference Manual (`doc/refmanual.html`), the ICL Reference
Manual (`doc/iclrefmanual.html`), the JavaDoc bundle, the C Doxygen bundle, and
the per-agent documentation. The Reference Manual and ICL Reference Manual are
the highest-value outstanding retrievals; the Developer's Guide defers to them
repeatedly for exhaustive parameter lists.

## Tier 3 — Papers by the OAA authors

- **Martin, Cheyer & Moran**, *The Open Agent Architecture: A Framework for
  Building Distributed Software Systems*, Applied Artificial Intelligence
  13(1–2), 1999. `https://www.tandfonline.com/doi/pdf/10.1080/088395199117504`
- **Martin, Cheyer & Moran**, *The Open Agent Architecture*, Autonomous Agents
  and Multi-Agent Systems, 2001. Copy retrieved from the author's site:
  `http://www.adam.cheyer.com/papers/jaams.pdf` —
  SHA-256 `d5271f7530f1f51fd1800d03485cb9f46f9452a3bce548c14695ca7deed462f2`
- **Moran, Cheyer, Julia, Martin & Park**, *Multimodal User Interfaces in the
  Open Agent Architecture*, IUI 1997.
  `https://www.sri.com/wp-content/uploads/2021/12/multimodal_user_interfaces_in_the_open_agent_architecture.pdf` —
  SHA-256 `9b572c567a05e32996dcd5657573564e62295e2706d24f2e6bf8045954658adb`
- **Cohen & Cheyer et al.**, *An Open Agent Architecture*, AAAI Spring
  Symposium, 1994. `https://aaai.org/papers/0001-ss94-03-001-an-open-agent-architecture/`
- **Martin, Cheyer & Lee**, *Agent Development Tools for the Open Agent
  Architecture*, PAAM'96, pp. 387–404.
  `https://www.sri.com/publication/artificial-intelligence-pubs/agent-development-tools-for-the-open-agent-architecture/`
  — **not yet retrieved in full text.** This is the primary source for the
  Agent Development Toolkit and is a prerequisite for Phase 2.
- SRI, *e-service modeling* technical paper.
  `https://www.csl.sri.com/papers/eservice-modeling/eservice-modeling.pdf` —
  SHA-256 `5658fd25879c0b7798bac3d610f0925d861d9a67386e94ceea0955c4763774db`

## Tier 4 — Patents and disclosures

- **US 6,851,115 B1**, *Software-based architecture for communication and
  cooperation among distributed electronic agents* (SRI International).
  `https://patentimages.storage.googleapis.com/80/cd/7b/ecba8da93bd965/US6851115.pdf` —
  SHA-256 `fa468e776a10b063e08842c03237c8a1a70dc5597ac75c1b832984de9e4850ac`

Patent claim language is drafted for legal scope, not for implementation. It is
used here only as corroboration where the Developer's Guide and source are
ambiguous, never as a specification on its own.

The USPTO PTACTS petitions cited above sit in the *IPA Technologies* docket.
IPA Technologies is the entity that asserted the SRI OAA/Siri patent family in
later litigation; that is why high-quality captures of OAA documentation exist
in the USPTO record at all.

## Tier 5 — Third-party and contextual

- **Wikipedia**, *Open Agent Architecture* — orientation only, never cited as
  evidence.
- **IndiGolog–OAA interface documentation**, University of Toronto:
  `https://www.cs.toronto.edu/~alexei/ig-oaa/index.htm` — independent
  third-party account of writing OAA agents in Prolog. Useful as a cross-check
  on the agent library API.
- **SRI**, *Open agent architecture software*:
  `https://www.sri.com/hoi/open-agent-architecture-software/`
- **SRI**, *75 Years of Innovation: Open Agent Architecture software (OAA®)*:
  `https://www.sri.com/press/story/75-years-of-innovation-open-agent-architecture-software-oaa/`

## Modern comparison material (not specifications)

Used only for the comparative notes in `comparisons/`. These do not constrain
the oaa-next architecture.

- *AIOS: LLM Agent Operating System* — `https://arxiv.org/abs/2403.16971`
- *Agent Discovery in Internet of Agents* — `https://arxiv.org/abs/2511.19113`
- *A Technical Taxonomy of LLM Agent Communication Protocols* —
  `https://arxiv.org/abs/2606.19135`

## Retrieval notes and environment limitations

- **`web.archive.org` was unreachable** from the environment in which this
  research pass was performed: both direct HTTPS requests and the CDX API
  returned connection resets, and the fetch tooling declined the host. No
  Wayback-specific evidence is cited in this file. This turned out not to
  matter, because the original SRI host is still serving the entire
  distribution tree; but any future claim that rests on an archived-only page
  must be re-verified from an environment with archive access.
- USPTO PTACTS download endpoints reject requests without a browser
  `User-Agent`, returning a CloudFront 403. This is a retrieval quirk, not an
  access restriction.
- `https://www.ai.sri.com/~oaa/distribution/` itself returns a placeholder
  ("Nothing here to read") — the versioned subdirectories beneath it are what
  remain live.
