# Delegation

Delegation is the Facilitator's central act: turning a requester's goal into
one or more dispatches to agents whose declared solvables match it, without
the requester ever having to know who answered.

## The pipeline

1. **Candidates.** `fac_candidates/3` filters the registry
   (`agent_data/6`) to agents with a solvable whose `GoalTemplate` unifies
   with the goal. Matching uses unification, without similarity or
   fuzzy scoring (Developer's Guide §5.1.2).
2. **Order.** `fac_order/2` sorts by descending `utility/1`, keysorted so
   equal utilities keep registration order rather than an arbitrary one.
3. **Select.** `fac_select/5` applies the requester's parameters:
   `solution_limit`, `provider_limit`, an explicit `address` that bypasses
   matching entirely and names recipients directly, and so on.
4. **Dispatch.** `fac_dispatch_plan/4` decides how: a simple goal dispatches
   to every selected agent in one round; a compound goal advances one step
   of its branch walk (see below) and dispatches only that step's targets.
5. **Collect and relay.** Replies come back tagged with a continuation
   (`client(...)`, `compound(...)`, `meta(...)`); the Facilitator resolves
   the tag and either relays to the original requester or feeds the result
   into the next step of a compound goal or meta-agent consultation.

## Address bypasses matching

`address(Agent)` or `address([A1, A2])` sends the request straight to the
named agent(s), skipping the matching step. `address(parent)` addresses the
requester's own facilitator directly. This is how a blackboard is declared
on the Facilitator itself. `address(self)` addresses the requesting agent.

## Compound goals

`(A, B)` and `A ; B` are not routed as one opaque unit. `fac_compound.pl`
walks a compound goal breadth-first: `branch_step/2` inspects a branch and
returns the next action: report a `solution`, `expand` a disjunction into
parallel branches, or `dispatch` the next conjunct. It advances one step at a time, so
the Facilitator's own event loop never blocks waiting on one leg while
others in the same request are ready. `branch_advance/3` copies a branch
per incoming solution, so parallel solutions to an earlier conjunct don't
cross-contaminate each other's bindings. Variables shared between conjuncts
bind later conjuncts from earlier ones' solutions, following ordinary
logic-programming conjunction semantics.

## Meta-agent consultation

Two optional meta-agent hooks can advise delegation without overriding it.
`prioritize` reorders the already-matched candidate list;
`lookup` is asked when no local agent matches at all, and selection repeats
once one registers. Both are consulted through the same reply-tag mechanism
as any other delegated request. This keeps the Facilitator from deadlocking
on a meta-agent that itself needs the
Facilitator to answer something first (see
[`../../research/implementation-notes/facilitator.md`](../../research/implementation-notes/facilitator.md)
§5a). Neither is required; the Facilitator's own default behaviour runs
whenever no meta-agent is registered or none returns a usable answer. This
is the seam used by an LLM-backed `prioritize` or `lookup` agent. See
[`llm-agents.md`](llm-agents.md).

## Referred goals and hierarchies

In a facilitator hierarchy, a goal that a node facilitator cannot satisfy
locally can be referred up to its parent, or answered by children if
`propagate(down(true))` is set. A goal that arrived *from* the parent is
never referred back up, preventing referral loops. The
referring facilitator's address travels with the referred goal as
continuation information, so the answer returns along the same path it
came by (Developer's Guide §10.2).

## Direct connect

`direct_connect(true)` still uses the Facilitator to match, order and choose
a single provider. The goal and its solutions
then travel directly between requester and provider over a socket the
provider registered in advance, bypassing the Facilitator for message flow.
Single provider, single facilitator, `oaa_Solve` only; `time_limit` and
`parallel_ok` are ignored in this mode (Developer's Guide §10.1).
