# Recovered artifacts

Every artifact consulted by this project, with provenance and cryptographic
hashes so that anyone can obtain the same bytes and verify them.

**Nothing listed here is committed to this repository.** The recovered
distribution is LGPL-2.1-or-later and *could* lawfully be redistributed, but
oaa-next keeps historical material out of its own tree so that the boundary
between ORIGINAL and NEW stays unambiguous, and so that the project's own
license choice remains unconstrained. See `licensing.md` §5.

Retrieval date for all entries: **2026-08-24**.

## How to obtain these yourself

The original SRI host is still serving the distribution tree. No archive or
mirror is required:

```sh
curl -L -A 'Mozilla/5.0' -O \
  https://www.ai.sri.com/~oaa/distribution/v2.3/2.3.2/download/windows/oaa2.3.2_02.zip
sha256sum oaa2.3.2_02.zip
# expect 1ca1e616be3f10cfaccbb54e14340a851e7ab0d3582d05fa6cc984514b583bd5
```

USPTO PTACTS endpoints reject requests lacking a browser `User-Agent` with a
CloudFront 403; pass `-A 'Mozilla/5.0'` there too.

## Software distributions

| Artifact | SHA-256 | Size | Source |
|---|---|---|---|
| `oaa2.3.2_02.zip` (Windows, source + runtime) | `1ca1e616be3f10cfaccbb54e14340a851e7ab0d3582d05fa6cc984514b583bd5` | 28,341,377 B | `https://www.ai.sri.com/~oaa/distribution/v2.3/2.3.2/download/windows/oaa2.3.2_02.zip` |

Not retrieved, known to exist, same directory:

- `.../download/unix/oaa2.3.2_02.tar.gz` — ~64 MB compressed, ~214 MB
  extracted. Per `doc/README.txt` the `src/` trees are identical to the Windows
  download except for line endings; `lib/` and `runtime/` differ in which
  platform binaries are included.
- `https://www.ai.sri.com/~oaa/distribution/v2.2` — the 2.2.1 distribution.
- `https://www.ai.sri.com/~oaa/distribution/v2.3/download` — the 2.3.0
  distribution.
- `https://www.ai.sri.com/~oaa/distribution/distribv1/` — **OAA 1.x.** Not
  covered by the 2.3.2 LGPL relicense; its license must be established
  separately before use.
- `https://www.ai.sri.com/~oaa/contributions/` — community-contributed agents,
  each with its own provenance.

## Documents

| Artifact | SHA-256 | Pages | Source |
|---|---|---|---|
| OAA Developer's Guide v2.3.2 (PDF capture) | `6e532f891623eee5d7fddb061ae25a8a091dd27d1ddb8bb1e998d00d45ee390d` | 47 | USPTO PTACTS petition 1524561 (*IPA Technologies, Exhibit 2064*) |
| OAA Developer's Guide v2.3.2 ("alternate" copy) | `6e532f891623eee5d7fddb061ae25a8a091dd27d1ddb8bb1e998d00d45ee390d` | 47 | USPTO PTACTS petition 1524643 — **byte-identical to the above** |
| OAA v2.x FAQ (PDF capture) | `3c32ac2bd223ed2f206117888614f296fc962a3707af232acd18c89c378c5645` | 6 | USPTO PTACTS petition 1524583 (*Exhibit 2065*) |
| OAA® Research Community License v2.3 (HTML) | `b80944f7776131ffd288b726271cb253b435c6e1a77567c34fec9e677919ab8f` | — | `https://www.ai.sri.com/~oaa/distribution/v2.3/license-v2.html` |
| US 6,851,115 B1 | `fa468e776a10b063e08842c03237c8a1a70dc5597ac75c1b832984de9e4850ac` | 37 | Google Patents image store |
| *The Open Agent Architecture* (JAAMS) | `d5271f7530f1f51fd1800d03485cb9f46f9452a3bce548c14695ca7deed462f2` | 6 | `http://www.adam.cheyer.com/papers/jaams.pdf` |
| *Multimodal User Interfaces in the OAA* (IUI'97) | `9b572c567a05e32996dcd5657573564e62295e2706d24f2e6bf8045954658adb` | 8 | `https://www.sri.com/wp-content/uploads/2021/12/multimodal_user_interfaces_in_the_open_agent_architecture.pdf` |
| SRI e-service modeling paper | `5658fd25879c0b7798bac3d610f0925d861d9a67386e94ceea0955c4763774db` | 10 | `https://www.csl.sri.com/papers/eservice-modeling/eservice-modeling.pdf` |

The two Developer's Guide captures sharing a hash is worth restating: they are
one document filed under two petition IDs. They are not independent
corroboration, and should not be cited as such.

## Structure of the 2.3.2 distribution

3,642 entries under a single `oaa2.3.2/` root.

```
oaa2.3.2/
  doc/        README.txt, README_PROLOG.txt, README_RUNTIME.txt,
              README_SRC.txt, history.txt, setup1.pl
  lib/        built and third-party library files
  runtime/    executables for the facilitator, tools and sample agents
  src/        all source
```

### `src/` inventory

| Directory | Entries | What it is |
|---|---|---|
| `oaalib/java` | 1,072 | Java agent library, incl. ANTLR ICL grammar |
| `oaalib/c` | 633 | C agent library, incl. PCCTS/ANTLR ICL parser |
| `oaalib/dotnet` | 78 | .NET library |
| `oaalib/prolog` | 14 | Prolog agent library — `oaa.pl`, `com_tcp.pl`, `spcompat.pl`, `tcp_extra.pl`, `make_setup.pl` |
| `debug_c` | 981 | C/FLTK debug agent (most of this is the bundled FLTK 1.1.3 tree) |
| `oaatest` | 128 | Test suite |
| `dotnetproxyagent` | 109 | .NET proxy agent |
| `monitor` | 82 | Monitor agent |
| `startit` | 40 | Start-It execution manager |
| `agentlib` | 35 | `com.sri.oaa2.agentlib` — the higher-level Java Agent API |
| `samples_*` | 103 | C, .NET, Java, VB and WebL samples |
| `scripts` | 37 | Build and launch scripts |
| `debug` | 12 | Java debug agent |
| `test` | 10 | Additional tests |
| `facilitator` | 5 | **`fac.pl`, `compound.pl`, `translations.pl`, Makefile** |
| `dcg_nl` | 4 | DCG natural-language agent (Prolog) |
| `eliza` | 4 | Eliza sample agent |
| `alarm` | 3 | Alarm agent — provides time triggers |
| `oaa_shell` | 3 | Command-line shell agent |
| `licenses` | 5 | LGPL, Apache, WebL licenses and `LicenseInfo.txt` |

### `runtime/`

`facilitator` (`win32/fac.exe` 1,556,549 B; `win32/fac_qp.exe` 876,544 B; an
empty `sparc-solaris/` in the Windows download), `monitor`, `startit`, `debug`,
`debug_c`, `oaa_shell`, `alarm`, `dcg_nl`, `eliza`, `dotnetproxyagent`,
`oaatest`, `samples_c`, `samples_dotnet`, `samples_webl`, `scripts`.

The `_qp` suffix marks Quintus-generated executables; the unsuffixed ones are
SICStus-generated and are the default from 2.2.0 onward.

## Executable preservation notes

Per the project's own rules, historical executables are never modified, are
identified by hash, and are never required by an oaa-next build.

`fac.exe` and `fac_qp.exe` are Win32 binaries from 2007. Running them for
black-box behavioural comparison would need Wine or a Windows VM, plus a
Facilitator port and cooperating client agents. Since `fac.pl` — the actual
Prolog source those binaries were compiled from — is included in the same
distribution under the LGPL, **source inspection is the better behavioural
reference and executable archaeology is not on the critical path.** It stays
available as a tiebreaker if source and documentation ever disagree.

No historical binary has been executed as part of this work.

## Outstanding retrievals, in priority order

1. **OAA Reference Manual** (`.../2.3.2/doc/refmanual.html`) — the Developer's
   Guide defers to it for exhaustive parameter lists on nearly every library
   procedure. Highest-value gap.
2. **ICL Reference Manual** (`.../2.3.2/doc/iclrefmanual.html`) — ICL parsing
   and construction API for non-Prolog languages.
3. **OAA 2.3 Tutorial** (`.../v2.3/doc/tutorial/index.html`) — the historical
   developer on-ramp; needed to reproduce the developer experience faithfully.
4. **Martin, Cheyer & Lee, PAAM'96** — the ADT paper. Prerequisite for Phase 2.
   Not retrievable from the URLs tried so far; likely needs a library or
   ResearchGate copy.
5. `README_RUNTIME.txt` and `README_SRC.txt` full text — partially read.
6. OAA 1.x distribution, for the language coverage 2.x dropped, and for its own
   licensing.
7. JavaDoc and C Doxygen bundles (`oaa_javadoc_2.3.2.zip`,
   `oaa_cdoc_2.3.2.zip`) — API-level detail.

## Environment note

`web.archive.org` was unreachable during this pass — direct requests and the
CDX API both reset, and the fetch tooling refused the host. This did not
obstruct the work, because the original host is live. It does mean this file
contains no archive-only provenance; if the SRI host later disappears, these
hashes are what let an archived copy be authenticated.
