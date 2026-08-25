# ICL — the Interagent Communication Language

ICL extends Prolog syntax. The Developer's Guide says it was chosen for
unification and backtracking, and so that agent
messages can in principle be translated to and from natural language (§3.3,
FAQ §2.4). Every event, every goal, every solvable declaration on the wire is
an ICL term.

## Two layers

A **conversational layer** of event types and parameter lists, such as
`ev_solve(GoalId, Goal, Params)` and `[type(data), utility(8)]`, sits over a
**content layer** of goals, triggers and data elements written in ICL
itself. The Developer's Guide compares this explicitly to KQML wrapping KIF
(§4.3). Content stays inside ICL so the Facilitator can read a compound goal
and decompose it into independently routable pieces.

## Grammar

ICL is Prolog-like, not Prolog. It has its own operator table, smaller than
standard Prolog's, with its own precedence order. Both surviving historical
grammars (an ANTLR grammar for the Java library, a PCCTS grammar for C)
define the same chain:

| Priority (loosest first) | Operators |
|---|---|
| 1300 | `,` (only inside a group, list or argument list — never at top level) |
| 1200 | `:-` |
| 1100 | `;` |
| 1050 | `\` |
| 700 | `=` |
| 600 | `:` `::` |
| 500 | `+` `-` (infix) |
| 400 | `*` `/` |
| 200 | `+` `-` (prefix) |

Every infix operator is left-associative. A symbol run that doesn't spell
one of these stays an ordinary symbolic atom. For example, `f(x) ==> y` is two
subterms, not an implication, and deferring to a full Prolog reader would
silently accept more than the historical parser did. `src/icl/icl_ops.pl`
holds the table; `icl_lex.pl`, `icl_parse.pl` (precedence climbing) and
`icl_write.pl` implement lexing, parsing and printing against it. Full
derivation, including a correction of an earlier finding that ICL had no
operators at all, is in
[`../../research/implementation-notes/icl.md`](../../research/implementation-notes/icl.md).

## Compound goals on the wire

`(A, B)` is a group, priority 1300, and is how a conjunction is written. A
bare `A, B` at top level is a syntax error, matching the historical grammar
exactly. `A ; B` is disjunction. A subgoal inside a compound request can
carry its own address and parameters: `Address:Goal::Params`, disassembled
by `icl_disassemble_goal/4` and reassembled by `icl_assemble_goal/4`
(`src/icl/icl_term.pl`).

## Types and matching

ICL's type hierarchy is a lattice, not a tree. For instance, `icldataq/1`
descends from both `string` and `compound`, and a single-parent
representation gives wrong answers for it
(`icl_subtype/2` in `src/icl/icl_type.pl`;
[`../../research/implementation-notes/icl.md`](../../research/implementation-notes/icl.md) §1).
`icl_conforms/2` checks a value against a type spec respecting supertype
relations (`3` conforms to both `number` and `atomic`). Matching a goal
against a solvable template uses plain unification through `icl_matches/2`,
without similarity or type coercion.

## Parameter lists

`[type(data), single_value(true), persistent]` is a functor-with-arguments
list. A boolean parameter with value `true` may omit the argument entirely
(`persistent` means `persistent(true)`), and defaults are elided on the wire
and reapplied on receipt. `icl_params.pl` implements lookup
(`icl_get_param_value/2,3`), merging (`icl_param_merge/3`) and default
application (`icl_param_apply_defaults/3`), used throughout the agent
library and Facilitator rather than each module inventing its own parameter
handling.

## Term utilities

`icl_term.pl` is the module most other code reaches for: `icl_parse_term/2`
and `icl_write/1` for the round trip, `icl_term_equal/2` and
`icl_term_variant/2` for comparing terms up to renaming, `icl_matches/2` /
`icl_match/3` for solvable matching, and the goal-disassembly pair above.
Full signatures are in [`api-reference.md`](api-reference.md).
