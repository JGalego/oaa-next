# Implementation note: the Interagent Communication Language

Provenance: OAA Developer's Guide v2.3.2 (DG), the OAA v2.x FAQ, and
observation of the recovered ICL grammars — `src/oaalib/java/icl_parser/
OaaPrologNetParse.g` (ANTLR, Java library) and `src/oaalib/c/icl_parser/parser/
parser.g` (PCCTS, C library). OAA 2.3.2, LGPL-2.1-or-later, © SRI
International.

Behavioural specification, not a transcription.

---

## 1. What ICL is, and what it is not

ICL is described in the Developer's Guide as an extension of the Prolog
programming language, chosen so that unification and backtracking are available
and so that agent messages can be translated to and from natural language.

That description is easy to over-read. **ICL is a term language, not Prolog.**
The recovered grammars accept a deliberately restricted subset:

- Structures — a functor applied to one or more arguments
- Lists, including the `[Head|Tail]` form
- Variables
- Strings and atoms
- Integers and floats
- `icldataq/1` and `icldataq/3` — the double-quoted data forms
- Grouped terms

And that is essentially all. In the Java grammar the tokens for arithmetic
operators (`*`, `/`, `+`, `-`), for `=`, for `:` and for the turnstile `:-` are
all present but **commented out**. There is no operator precedence table, no
clause syntax, no arithmetic evaluation, and no cut as a control construct
(`!` is lexed, but only as a plain token).

The practical consequence for a reimplementation is sharp: **do not implement
ICL by calling a full Prolog reader.** A Prolog reader accepts a strictly
larger language than ICL does, so an implementation built that way will
silently accept messages the historical system would have rejected, and will
diverge in exactly the places compatibility tests should catch. oaa-next should
implement the restricted grammar directly and treat the Prolog resemblance as
being about *semantics* — unification, variables, backtracking over solutions —
rather than about surface syntax.

## 2. Two layers

The Developer's Guide frames ICL as two layers, compared explicitly to KQML
over KIF:

- **Conversational layer** — the event types, together with the parameter lists
  associated with certain of them. `ev_solve`, `ev_solved`, `ev_update_data`,
  `ev_update_trigger` and their parameter lists live here.
- **Content layer** — the specific goals, triggers and data elements embedded
  within events.

The Guide gives a reason for keeping content in ICL rather than embedding some
other language: it is what lets the Facilitator see *into* a request, so it can
decompose a compound goal and delegate the subgoals individually. Content
expressed in an opaque payload would reduce the Facilitator to a message
router.

This is the single argument that most needs preserving when adding
interoperability adapters later. A JSON or MCP bridge that carries ICL as an
opaque string is a downgrade in kind, not just in syntax.

## 3. Wire format

Terms are transmitted terminated by a period. The Java grammar's entry points
distinguish a single term (`startOneOnly`) from a stream of terms
(`startMulti` / `netstruct`), which is what a socket carrying successive events
needs.

The character vocabulary in the recovered Java grammar is U+0000 to U+00FF —
Latin-1. A `-latin1` variant of the grammar file ships alongside it, and the
2.3.2 release notes record considerable churn in `IclStr` quoting behaviour.
**Encoding is a known-weak area of the historical implementation.** oaa-next
should be UTF-8 throughout and should record this as a deliberate
modernization, not attempt to reproduce Latin-1 behaviour.

Quoting deserves care. From the 2.3.2 notes, `IclStr` moved to storing an
unquoted value and computing the minimally-quoted form lazily, with
`toMinimallyQuotedString()`, `toForcedQuotedString()` and `toUnquotedString()`
distinguished. The lesson is that **a term's printed form is not canonical** —
the same term has several valid renderings — so equality and hashing must be
defined on structure, not on printed text. The historical implementation
learned this late; oaa-next should start there.

## 4. Type system

A supertype hierarchy, used by the Facilitator during matchmaking (DG §4.3.4):

```
atomic
├── number
│   ├── float
│   └── integer
└── string
    ├── atom
    ├── icldataq(_)
    └── icldataq(_,_,_)

compound
├── icldataq(_)          (also a subtype of string)
├── icldataq(_,_,_)      (also a subtype of string)
└── document
    ├── xml(XSDSpec, _Document)
    └── mime(MimeType, _Document)

list
```

Note that `icldataq/1` and `icldataq/3` are deliberately subtypes of *both*
`compound` and `string` — the hierarchy is not a tree. An implementation using
a single-parent type structure will get matchmaking wrong.

Document types exist to let external typing schemes ride along: `xml/2` takes a
URL for an XML Schema declaration (or a variable, meaning unconstrained) and a
document body; `mime/2` takes a MIME type name and a body. In both, the body
may be a variable, `icldataq(_)` or `icldataq(_,_,_)`.

Type recognition is by inspection: primitive values are typed by the usual
Prolog means, `icldataq` values by their arity, and `xml`/`mime` values by
their functor with the second argument left free.

**The hierarchy is extensible at runtime** — the Facilitator declares
`icl_type(Type, SuperType)` as a *writable data solvable*, so facts can be
added to it while the community is running. See
[`facilitator.md`](facilitator.md) §2.

## 5. Solvables

```
solvable(GoalTemplate, Parameters, Permissions)
```

Shorthand forms drop trailing arguments, down to a bare goal template; all
forms normalize to the three-argument form on receipt.

Matching is **unification of the goal against the goal template**. Permissions
and parameters take no part in matching. This is worth stating flatly because
it is the property a "modernized" implementation is most likely to erode: OAA
capability matching is exact and deterministic, not similarity-based.

Optional argument typing (from 2.3.0) uses `argspecs(Spec1, ..., SpecN)` where
each spec is `in(Type, Required)`, `out(Type, Deterministic)` or
`inout(Type, Deterministic)`. Absent `argspecs`, every argument is treated as
`inout(_, false)` — any type, not required, non-deterministic. `argnames(...)`
is documentation only and is not used by the Facilitator.

## 6. Parameter lists

Parameters are functors with arguments — `type(data)`, `single_value(true)`,
`solution_limit(5)`. Two conventions matter:

- A boolean parameter with value `true` may omit the value, so
  `[type(data), single_value(true), persistent(true)]` and
  `[type(data), single_value, persistent]` denote the same thing.
- Parameters at their default value are normally stripped before a request
  goes to the Facilitator, to conserve bandwidth.

The second is a wire-level behaviour with a testable consequence: a parameter
list is not preserved verbatim across a request. `icl_GetParamValue/2` — which
works by unification against a pattern like `from(Requestor)` — must therefore
supply defaults for absent parameters rather than fail on them.

## 7. Events

Events are the unit of all interagent communication. The Developer's Guide is
explicit that the developer does not normally construct them: they are built
and sent transparently by library calls. The canonical pair:

```
oaa_Solve(Goal, Params)
    →  ev_solve(GoalId, Goal, Params)
    ←  ev_solved(GoalId, Requestees, Solvers, Goal, Params, Solutions)
```

with further messages between the Facilitator and the solvers in between.
`Requestees` is the list of local IDs asked; `Solvers` the list that actually
returned solutions; each solution unifies with `Goal`.

Two 2.3.2 changes are load-bearing for a reconstruction:

- The `Goal` position in `ev_solved` carries a **variable** by default from
  2.3.2 onward, not a copy of the goal — a bandwidth fix. The old behaviour is
  restorable with `return_goal_with_solutions`, and the 2.3.1 Monitor requires
  it. This is the one documented wire change that visibly breaks
  compatibility.
- `GoalId` is generated **client-side** and, from 2.3.2, starts from a random
  integer rather than 1, because sequential IDs allowed replies to two
  different solve requests to be intermixed. Any reimplementation must make
  goal IDs unique per requester *across reconnects*, not merely increasing.

## 8. Addresses

```
addr( tcp(Host, Port) )            % a facilitator
addr( tcp(Host, Port), LocalID )   % a client agent
```

Where an address parameter is expected, any of the following is accepted: a
full address; a local ID (when the addressee is self or a peer); a name wrapped
in `name/1`; or one of the reserved terms `self`, `parent`, `facilitator`
(the last two being synonyms). These are normalized on receipt: local IDs
become full addresses, reserved terms are resolved, names are wrapped.

Full addresses are globally unique; local addresses are unique only with
respect to a facilitator; **symbolic names are not unique in any sense**. Local
IDs are integers in the historical implementation and the Guide explicitly
tells developers not to depend on that — good advice to honour in the
reconstruction by making them opaque.

## 9. Open questions

- The complete set of escape sequences inside quoted atoms and `icldataq`
  bodies. The grammar handles this in lexer rules not yet fully read.
- Whether the C (PCCTS) and Java (ANTLR) grammars accept exactly the same
  language, or diverge at the edges. **Worth a direct comparison** — a
  divergence between two libraries shipped in the same release would be a
  strong signal about which behaviours are actually load-bearing.
- The exact form and semantics of `icldataq/3`'s three arguments; the
  Developer's Guide defers to documentation "elsewhere" that has not been
  recovered.
- Whether `GROUP` in the grammar is parenthesised grouping only, or carries
  meaning in matching.
- The ICL Reference Manual (`doc/iclrefmanual.html`, not yet retrieved) is the
  natural source for most of the above.
