# The Office Assistant demo

The "original" OAA demonstration, per Adam Cheyer's own description of it,
and the best-documented concrete scenario recovered so far — used here as
the basis for an illustrative reconstruction rather than transcribed as
architecture. Two independent primary sources corroborate each other, plus
a screenshot with a verbatim command.

## Sources

- **Demo page**: `http://www.adam.cheyer.com/demo-office.html` — SHA-256
  `4791897798fcdb89c37e4904a14dc5924d93cce11efd879973798099db441005`,
  retrieved 2026-08-25. States: "Control your office from remote locations
  -- agents provide access and monitoring of your calendar, email, or
  database applications over the telephone, a laptop, web browser or
  wireless PDA. Handwriting and speech recognition are incorporated into a
  simple multi-modal user interface. The focus of this demonstration is on
  non-hardcoded interactions among a dynamically extensible set of 'web
  services' or agents." Filmed 1997, of the original '93/'94 demo.
- **Screenshot** (`images/demo-o1.jpg` on that page) — SHA-256
  `a22d3901f88b2e55c4c2cf332f4dd04fede7886792f6dd773bb681dc833e8720`.
  Copyright Adam Cheyer, all rights reserved (per the page footer); not
  reproduced here, cited and described only. Shows the OAA graphical
  office: a room with a photo of Adam Cheyer, a clock, telephone, mailbox,
  and filing cabinet, each an icon for an agent; a status line reading
  "Connected to server. Agents are now active."; and a natural-language
  command bar containing, verbatim: **"When mail arrives for me about
  "security" get it to me by telephone."**
- **Architecture diagram** (`images/demo-o2.jpg` on the same page) — SHA-256
  `00cf9e85a9a5e277e6248d79bcb980e4c04d43d4f710a3a787601afc43d2293b`. Shows
  the Facilitator as a hub with arrows to and from every other box: User
  Interface Agent(s) (desktop, telephone and pen/PDA icons), Speech
  Recognition Agent, Natural Language Agent, Electronic Mail Agent, Notify
  Agent, Database Agent, Calendar Agent, Text-To-Speech Agent, Telephone
  Agent.
- **Moran, Cheyer, Julia, Martin & Park**, *Multimodal User Interfaces in
  the Open Agent Architecture*, IUI 1997 — already in
  [`sources.md`](sources.md) Tier 3, SHA-256
  `9b572c567a05e32996dcd5657573564e62295e2706d24f2e6bf8045954658adb`. Its
  "Office Assistant" section describes the same demo in prose, and its
  "Triggers" section describes the general mechanism the screenshot's
  command exercises.
- **Cohen, Cheyer, Wang & Baeg**, *An Open Agent Architecture*, AAAI Spring
  Symposium, 1994 — already in `sources.md` Tier 3, cited by the IUI paper
  as reference [4] for the Office Assistant's original description; not yet
  retrieved in full text.

## What the sources establish

The IUI 1997 paper (§"Office Assistant"): "a multifunctional 'office
assistant', fourteen autonomous agents provide information retrieval and
communication services for a group of coworkers... makes use of a
multimodal user interface running on a pen-enabled portable PC, and allows
for the use of a telephone to give spoken commands... agents with expertise
in e-mail processing, text-to-speech translation, notification planning,
calendar and database access, and telephone control cooperate to find a
user and alert him or her of an important message." And on the interface
itself: "the initial screen portrays an office, in which familiar objects
are associated with the appropriate functionality... clicking on a wall
clock brings up a dialogue that allows one to interact with the calendar
agent" — which matches the screenshot's clock icon exactly.

The paper's "Triggers" section describes the general mechanism the
screenshot's command is an instance of, using a different worked example
(a rental-housing listing, not mail) that happens to spell out the full
notify sequence in more detail than the mail/telephone one gets:

> "When a house for rent is available in Menlo Park for less than 1800
> dollars, notify me immediately." This natural language request installed
> a trigger on an agent knowledgeable about the domain... At regular
> intervals, the agent instructs a Web retrieval agent to scan data...
> When an advertisement meeting the specified criteria is detected, a
> request is sent to the Facilitator for a notify action to be delegated to
> the appropriate other agents. The notify action involves a complex series
> of interactions between several agents, coordinated by the Notify and
> Facilitator agents. For example, if the user is in a meeting in a
> conference room, the Notify agent first determines his current location
> by checking his calendar... The Notify agent then requests contact
> information for the conference room, and finds only a telephone number.
> Subsequent requests create a spoken version of the advertisement and
> retrieve the user's confirmation password. When all required information
> is collected, the Facilitator contacts the Telephone agent with a request
> to dial the telephone, ask for the user, confirm his identity with
> password (entered by TouchTone), and finally play the message.

Read together with the mail/telephone command in the screenshot, the shape
of that example generalizes directly: a natural-language sentence installs
a **trigger** (condition = a content pattern on incoming data; action =
notify via a named channel), the Facilitator delegates the notify action to
a small pipeline of agents, and which channel is used (telephone, e-mail,
FAX, pager) is itself agent-mediated rather than hardcoded — exactly the
"non-hardcoded interactions among a dynamically extensible set of agents"
the demo page's own description advertises as its point.

## What isn't established

Neither source gives a full transcript of the mail/security interaction
specifically — only the one command line visible in the screenshot. The
four linked demo videos (`Office.wmv`, `UMsg.wmv`, `spkid.wmv`, `cnet.wmv`,
all still resolving as of 2026-08-25) would likely show it end to end, but
video content cannot be reviewed in this environment. The exact NL parse
grammar, the Notify agent's internal decision logic, and the full fourteen-
agent roster (the diagram names nine boxes; the paper says fourteen agents)
are not recovered. None of that is invented below — the reconstruction
stays at the level the sources actually support.

## Reconstruction versus historical claim

`examples/multi-agent/office/` (added alongside this note) is a NEW,
illustrative scenario — labelled as such, not RECONSTRUCTED — built to
exercise the same *pattern* the evidence above establishes: a natural-
language sentence, parsed by the LLM agent into an `oaa_AddTrigger` call, that
watches a mail data solvable for a content match and delegates delivery to a
separate channel agent when it fires. It reproduces the verbatim command
from the screenshot as its worked example, deliberately, since that much is
attested; it does not claim to reproduce the historical Notify agent's full
location-aware delegation logic (calendar lookup, room phone lookup,
TouchTone password confirmation), since that lives only in prose about a
different example, not in a source detailed enough to reconstruct
faithfully. Speech recognition, handwriting recognition, telephony and the
graphical office UI itself are out of scope for the same reason they're out
of scope for oaa-next generally: they were third-party or bespoke I/O
components wrapped as agents, not part of OAA's own core, and building them
is a distinct effort from reimplementing the architecture.
