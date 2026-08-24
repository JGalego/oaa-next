# Licensing, copyright and trademark provenance

**Status: the licensing question is resolved for OAA 2.3.2, and the answer is
materially better than the project brief assumed.** This file records what was
found, how it was verified, and what it permits and forbids.

Nothing in this file is legal advice. It is a research record. Decisions with
legal consequence — in particular the choice of the oaa-next license and the
use of the "OAA" name — remain with the project owner.

---

## 1. Headline finding

**OAA 2.3.2 (the final release, June 2007) is licensed under the GNU Lesser
General Public License, version 2.1 or later, copyright SRI International.**

It is *not* under the non-commercial "community license" that the widely-cited
OAA FAQ describes. The FAQ is accurate about earlier 2.x releases and
out of date with respect to the last one.

This was verified from inside the distribution itself, which is the top of the
evidence hierarchy — not inferred from a web page.

### The four independent confirmations

1. **`src/licenses/lgpl.txt`** contains the verbatim text of the GNU Lesser
   General Public License, Version 2.1, February 1999.

2. **`src/licenses/LicenseInfo.txt`** opens with the distribution's own
   licensing statement:

   > "Starting with version 2.3.2, OAA is released under the GNU Lesser
   > General Public License, which is reproduced in src/licenses/lgpl.txt of
   > the release."

3. **`doc/history.txt`**, in the release notes for 2.3.2A, states the intent
   directly and explains the earlier confusion:

   > "Although OAA 2.3.1 was already 'de facto' open source, the Web site and
   > license blocks in the source files did not reflect that. This has been
   > corrected, so that OAA is now fully and unambiguously open source, under
   > the GNU Lesser General Public License."

4. **Per-file headers.** 413 of 596 OAA-authored source files carry the
   standard LGPL-2.1-or-later header block with `Copyright (C) 2006 SRI
   International`. The remaining 166 carry no license header at all (build
   scripts, small data files, generated sources); **no** OAA-authored source
   file was found still carrying the old non-commercial header.

The Facilitator itself — the file that matters most — carries the LGPL header
explicitly:

```
oaa2.3.2/src/facilitator/fac.pl
  Copyright (C) 2006  SRI International
  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License ... version 2.1 of the License, or (at your option) any later version.
  ...
  Primary Authors : Adam Cheyer, David Martin
```

## 2. The conflict in the record, and how it resolves

Four sources appear to disagree. They do not actually disagree once dated.

| Source | Says | Applies to | Weight |
|---|---|---|---|
| `src/licenses/LicenseInfo.txt`, `doc/history.txt`, per-file headers (in-distribution, 2007) | LGPL-2.1-or-later | **2.3.2** | Tier 1 — decisive |
| 2.3.2 download page, `.../2.3.2/download/welcome.shtml` | LGPL | 2.3.2 | Corroborating |
| `.../v2.3/license-v2.html` — OAA® Research Community License v2.3 | Non-commercial only | 2.3.0 / 2.3.1 | Superseded |
| OAA v2.x FAQ — "a version of a community license ... for non-commercial purposes" | Non-commercial only | 2.x generally, pre-2.3.2 | Superseded, and a summary rather than a license |

The 2.3.0 distribution page and the FAQ were simply never updated after the
2007 relicense. The project brief's caution — do not infer rights from the FAQ,
recover the actual license — was exactly right, and following it produced the
opposite conclusion from the one the FAQ would have supported.

### One residual inconsistency, recorded not resolved

`src/dotnetproxyagent/Source/oaa_copyright.txt` is a leftover copyright
*template* still reciting the OAA Community Research License Version 2.0 and
the non-commercial terms. It is a stray file: the actual `.cs` sources beside
it carry LGPL headers. It does not appear to encumber anything, but it is
noted here so that nobody later "discovers" it and believes the LGPL finding
was wrong.

## 3. What the superseded Research Community License said

Recorded because it governs OAA 2.3.0 and 2.3.1, and because anyone working
from an older tarball is bound by it rather than by the LGPL.

- Full title: **OAA® Research Community License, Version 2.3**, SRI
  International, portions Copyright (c) SRI International, 1999.
- **"Licensed Purpose"** was the whole of it: rights were granted *solely* for
  (a) official government agency use for non-commercial public benefit
  purposes, or (b) non-commercial research for which no financially valuable
  consideration is received, government research funding excepted.
- The **Facilitator was executable-only**: the grant covered copying, using and
  distributing `fac.exe` / `fac` in original unmodified executable form, and
  §2.5 expressly forbade modifying, decompiling or disassembling it.
- Distribution obligations: a required notice in every source file, source
  availability for modifications for at least 12 months, and **prior licensee
  registration by email to SRI** before distributing anything.
- California law; no OSI-style field-of-endeavour freedom.

The most striking difference between the two licenses is therefore not just
"non-commercial vs. LGPL". It is that **under the 2.3 Research Community
License the Facilitator was a black box, and under 2.3.2's LGPL its Prolog
source was published.** A faithful reconstruction of Facilitator behaviour was
a much harder problem in 2005 than it is today.

## 4. What the LGPL-2.1 finding permits and requires

Assuming the LGPL-2.1-or-later grant (and this is the project owner's call to
accept):

**Permitted:** commercial use; modification; redistribution in source and
binary form; linking from software under any license; use of the source as a
behavioural reference without restriction.

**Required if OAA 2.3.2 code is copied into oaa-next:** those files, and works
derived from them, stay under LGPL-2.1-or-later; SRI's copyright notices and
the license header must be preserved; changes must be documented; the full
license text must ship. Practically, incorporating LGPL code makes oaa-next a
mixed-license project and constrains its own license choice.

**Not granted by any of this:** trademark rights. See §6.

## 5. Consequence for oaa-next — a real choice, not a foregone one

The project brief specified clean-room reconstruction on the assumption that
the historical license would be too restrictive to copy from. That assumption
is now false, which turns a constraint into a decision:

- **Option A — clean-room, permissive.** Use the recovered source only as a
  behavioural reference; author all oaa-next code independently; release
  newly-written code under a permissive license of the owner's choosing. Keeps
  oaa-next unencumbered and matches the brief's stated preference in §21.
- **Option B — derive from OAA 2.3.2 under the LGPL.** Legitimate, faster for
  the hardest parts (the Facilitator's matching and routing), and honest about
  lineage — but oaa-next inherits LGPL-2.1-or-later for those parts.

**This repository proceeds under Option A** unless the owner directs
otherwise, for three reasons: it is what the brief asked for; it keeps the
final license choice open; and a reconstruction whose value is pedagogical is
better served by independently written code that can be read alongside the
original than by a port of it.

Under Option A the recovered source is still enormously useful — as the
specification of record for behaviour that the Developer's Guide leaves
underspecified. Reading it for that purpose is not copying.

**No historical OAA source code, and no historical binary, is committed to
this repository.** That holds regardless of which option is chosen, until the
owner decides.

## 6. Trademark — the unresolved risk

From Exhibit A of the Research Community License and repeated in source
headers throughout the distribution:

> "'OAA' is a registered trademark, and 'Open Agent Architecture' is a
> trademark, of SRI International, a California nonprofit public benefit
> corporation."

SRI's current web pages still render it as **OAA®**.

Two things follow, and neither is settled by the LGPL finding, because a
software copyright license grants no trademark rights:

1. **The project name `oaa-next` incorporates a registered mark.** Nominative
   use — saying truthfully that this project reimplements SRI's OAA — is a
   different thing from using the mark *as the name of your own software*. The
   latter is where trademark risk actually lives.
2. **Current status must be checked before publication.** Everything above is
   from documents written between 1999 and 2007. Whether the registration is
   live, lapsed or assigned in 2026 is a question for the live USPTO TSDR
   register, not for archived pages. Note that the OAA patent family was
   assigned onward to IPA Technologies; marks may have moved too.

**Action for the owner before any public release:** verify the live status of
the "OAA" mark, and decide whether to keep `oaa-next` as the name or to adopt a
distinct name that describes the project by reference ("an independent
reimplementation of SRI International's Open Agent Architecture") without
taking the mark as its own. This repository does not make that call and does
not assume the outcome.

Regardless of the name, this project must not imply affiliation with,
endorsement by, or continuation-of-record from SRI International.

## 7. Third-party components in the historical distribution

If any part of the 2.3.2 tree is ever vendored, these ride along. Recorded from
`src/licenses/LicenseInfo.txt`.

| Component | Version | License |
|---|---|---|
| ANTLR | 2.7.1 | Public domain |
| JSch | 0.1.28 | BSD-style |
| dom4j | 1.5.2 | BSD-style |
| log4j | 1.2.7 | Apache 2.0 |
| trayicon | 1.7.9b | Informal warranty disclaimer only |
| WebL | 2.3.1 | HP/Compaq WebL license (`WebL-license.txt`) |
| backport-util-concurrent | 2.2 | Public domain |
| icu4j | 3.6 | ICU (BSD-style) |
| glib | 2.10.1 | LGPL-2 |
| gettext | 0.16 | GPL — build-time i18n only |
| libiconv | 1.9.1 | LGPL-2 |
| pkg-config | 0.14.0 | GPL — build tool, not linked |
| FLTK | 1.1.3 | LGPL with static-linking exception (used by the C debug agent) |

The GPL entries (gettext, pkg-config) are build tooling rather than linked
dependencies, which is why an LGPL distribution could ship them.

## 8. Component licensing register

Tracks material actually present in, or proposed for, this repository.

| Component | Origin | Version | Copyright holder | Original license | Redistribute? | Modify? | Commercial? | In repo? | Required notices |
|---|---|---|---|---|---|---|---|---|---|
| oaa-next research notes and documentation | New, this project | — | Project authors | Undecided — see §5 | n/a | n/a | n/a | **Yes** | — |
| OAA 2.3.2 distribution (`oaa2.3.2_02.zip`) | SRI International | 2.3.2 build 02 | SRI International | LGPL-2.1-or-later | Yes | Yes | Yes | **No** — reference only | LGPL header, SRI copyright |
| OAA Facilitator source (`fac.pl` et al.) | SRI International | 2.3.2 | SRI International | LGPL-2.1-or-later | Yes | Yes | Yes | **No** — reference only | LGPL header, SRI copyright |
| OAA Facilitator binary (`fac.exe`) | SRI International | 2.3.2 | SRI International | LGPL-2.1-or-later | Yes | Yes | Yes | **No** | LGPL |
| OAA Developer's Guide 2.3.2 | SRI International | 2.3.2 | SRI International | Not stated; assume all rights reserved | Unknown | Unknown | Unknown | **No** — cited, prose independently authored | Attribution |
| OAA v2.x FAQ | SRI International | — | SRI International | Not stated | Unknown | Unknown | Unknown | **No** — cited, short quotation only | Attribution |
| OAA Research Community License v2.3 text | SRI International | 2.3 | SRI International | Not stated | Unknown | Unknown | Unknown | **No** — cited and summarised | Attribution |
| "OAA", "Open Agent Architecture" | SRI International | — | SRI International | **Trademark, not copyright** | n/a | n/a | n/a | Name in use — **unresolved, §6** | Trademark notice |

**Documentation licensing note.** The LGPL covers the software. It does not
obviously cover the Developer's Guide, the FAQ or the web pages, none of which
carry a license grant. Those are therefore treated as all-rights-reserved:
oaa-next preserves their *terminology and conceptual structure*, cites them,
and writes its own prose. Short quotations, as used in this file, are
attributed and kept to what is needed to establish a fact.

## 9. Open licensing questions

- [ ] Confirm the Unix distribution (`oaa2.3.2_02.tar.gz`) carries the same
      license files as the Windows one. Expected yes; unverified.
- [ ] Retrieve the OAA 1.x distribution and determine its license
      independently. It is *not* covered by the 2.3.2 relicense.
- [ ] Determine whether OAA 2.3.1 and earlier were ever retroactively
      relicensed, or whether the LGPL grant begins strictly at 2.3.2.
- [ ] Verify live USPTO status of the "OAA" mark (§6). **Blocking for public
      release.**
- [ ] Decide Option A vs. Option B (§5). **Blocking for Phase 1 coding.**
- [ ] Decide the oaa-next license for newly authored code, after the above.
