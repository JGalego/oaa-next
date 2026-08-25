#!/usr/bin/env swipl
/*  oaa-next example -- the Office Assistant demo: natural-language front end
 *
 *  Provenance: NEW / ILLUSTRATIVE.  Stands in for the historical Natural
 *  Language Agent shown at the hub of the architecture diagram in
 *  research/office-demo.md.  The scripted reply below is not a guess at
 *  what SRI's NL agent produced internally -- nothing in the recovered
 *  material says that -- it is this project's own translation of the
 *  screenshot's verbatim command into an installable oaa-next trigger,
 *  using propose_goal/2 exactly as any other LLM-mediated request would.
 *
 *  Run with -oaa_mode OAA_LLM; the extension refuses to start otherwise.
 */

:- use_module('../../src/llm/llm_config').
:- use_module('../../src/llm/llm_agent').
:- use_module('../../src/llm/providers/llm_scripted').
:- use_module('../../src/agents/oaa_run').

:- initialization(run, main).

run :-
    llm_require_enabled,
    script,
    llm_agent_solvables(S),
    oaa_agent_run(llm_agent, S, []).

%   The screenshot's own command, verbatim (research/office-demo.md), mapped
%   to the oaa-next trigger it installs: watch the mail data solvable for a
%   message about "security", and when one arrives, deliver it through the
%   Telephone agent.  propose_goal/2 returns this goal without solving it --
%   installing a trigger is not itself a delegatable request.
script :-
    scripted_reply(
        "When mail arrives for me about \"security\" get it to me by telephone.",
        "oaa_AddTrigger(data, mail(_, about(security), Body), \c
                        oaa_Solve(deliver_by_phone(Body), []), \c
                        [on(add), recurrence(whenever)])").
