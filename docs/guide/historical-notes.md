# Historical notes

Places where `oaa-next`'s behaviour was settled by evidence rather than
assumed, including cases where an earlier reading here was wrong and was
corrected against the record — kept visible rather than quietly fixed,
because the project's own rule is to document ambiguity and correction
rather than launder it. This page indexes findings; the full derivation for
each lives in `research/`.

## The evidence hierarchy this project uses

Original source, then binaries, then archived distributions, then the
Developer's Guide, then papers and patents — in that order of trust, applied
throughout `research/`. SRI's own host,
`www.ai.sri.com/~oaa`, turned out to still be serving the complete OAA 2.3.2
tree, so no archive was needed; provenance and SHA-256 hashes for everything
consulted are in
[`../../research/recovered-artifacts.md`](../../research/recovered-artifacts.md).

## Licensing: not what the FAQ alone would suggest

The frequently cited OAA FAQ describes a non-commercial "community license."
That held for OAA 2.3.0 and 2.3.1. The final release, 2.3.2 in June 2007,
relicensed the software to LGPL-2.1-or-later — the license file, the
distribution's own licensing statement, the release notes, and the per-file
source headers all agree, and in-distribution evidence outranks the FAQ in
this project's hierarchy. Trusting the FAQ alone here would have wrongly
concluded the Facilitator's source was unusable even as a behavioural
reference. Full account, including what the superseded license actually
said, in [`../../research/licensing.md`](../../research/licensing.md).

## ICL has an operator table — an earlier finding here said otherwise, and was wrong

An earlier revision of the ICL implementation note claimed ICL had no
operators at all, reasoning from commented-out token definitions
(`//STAR`, `//PLUS`, `//COLON`) near the top of the Java lexer grammar. That
reading mistook supersession for removal: those single-character rules were
folded into one dynamic-type rule in the Java lexer, and declared plainly as
tokens in the C grammar; the parser rules using them are live in both. The
parser, lexer and writer here were rewritten to match once this was caught,
and the correction is recorded in place rather than silently
fixed — see the "Correction" block in
[`../../research/implementation-notes/icl.md`](../../research/implementation-notes/icl.md) §1
and the operator table in [`icl.md`](icl.md).

## `ev_data_updated` carries six arguments, not three

Nothing in the Developer's Guide's prose pins down the exact arity of the
reply to a data update. An earlier implementation here sent
`ev_data_updated(GoalId, Requestees, Solvers)` — three arguments — which
passed every test written against documented behaviour, because none of
those tests exercised the wire format directly. SRI's own OTML conformance
corpus, recovered under `src/oaatest/` in the distribution and previously
unread, settles it: `samples/test3/parallel.otml` shows six arguments,
`ev_data_updated(GoalId, Mode, Clause, Requestees, Solvers, Params)`. Fixed
in `fac.pl`; the shape is now pinned by
`tests/compatibility/test_conformance.pl`, which transcribes cases from that
corpus against a live community. This is the clearest instance in the
project of why wire-level conformance testing against the historical record
matters even after the documented interface tests all pass — see
[`data.md`](data.md) and [`communication.md`](communication.md).

## `can_solve` with an unbound goal can miss a real match

A solvable declaring a required input via `argspecs(in(...), ...)` cannot
match a wholly unbound probe goal, because matching is unification and an
unbound argument can't satisfy a required-input constraint the way a bound
one can. This reads as a bug until it's expected: asking
`can_solve(square(_, _), A)` about a solvable requiring its first argument
bound correctly finds nothing, and the right probe is a representative bound
goal like `square(1, _)` instead. `examples/basic/client.pl`'s
`await_capability/2` is written around this deliberately. Full account in
[`../../research/implementation-notes/facilitator.md`](../../research/implementation-notes/facilitator.md)
§8a.

## A nested wait consumes an event before the ordinary dispatcher sees it

`oaa_wait_for/3` — what a blocking `oaa_Solve` or `oaa_AddData` uses
internally while its answer is in flight — takes a matching event straight
off the queue, which means `app_do_event` never receives it. This is
invisible until something tries to observe a reply the library itself
consumes, like pinning the wire arity of `ev_data_updated` above: the only
way to see that event is a comm trigger, because comm-trigger observation is
wired to fire from inside the nested wait itself (`on_receive`), not from
the ordinary dispatch path. See [`triggers.md`](triggers.md) and
[`communication.md`](communication.md).

## An intermittent one-in-five failure, and what it actually was

An early version of the event loop blocked on waiting for socket input even
when events were already sitting in the queue, which surfaced as a failure
roughly one run in five under the test suite's timing — rare enough to look
like flakiness, consistent enough to have a real cause. The fix checks the
queue before polling for new input (`oaa_queue_empty -> poll_delay(...) ;
immediate`); a regression test pins the ordering so the loop can't regress
to blocking-first without a test noticing.

## Where oaa-next deliberately diverges

Not every difference from the historical system is a correction — some are
recorded, deliberate modernizations, kept distinct from findings above:
SICStus/Quintus → SWI-Prolog (a third Prolog dialect, which the historical
compatibility layer already anticipated supporting), graphical Monitor and
Debug → terminal tools, and `struct tm`-based date arithmetic → modern date
libraries producing the same documented result
(`date(YearLess1900, MonthLess1, ...)` semantics preserved,
implementation not). Each is marked `modernized` with its rationale in
[`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md),
which is the authoritative status table this page doesn't try to duplicate.
