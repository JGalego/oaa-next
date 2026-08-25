#!/usr/bin/env swipl
/*  oaa-next example -- a prioritize meta-agent
 *
 *  A meta-agent supplies domain knowledge the Facilitator does not have.  It
 *  declares meta(Type, +Goal, +Params, +FacInfo, -Result) and the Facilitator
 *  consults it when choosing between providers.
 *
 *  The Facilitator hands over its own sorted candidate list in FacInfo and
 *  takes back whatever order this agent returns.  Nothing about the
 *  Facilitator changes to accommodate it, and nothing here tells the
 *  Facilitator how the ordering was arrived at -- user preference, load
 *  measurements, a learned model, or, in a later phase, an LLM.
 *
 *  The hook is fallible by design: returning something unusable, or not
 *  answering at all, leaves the Facilitator's own utility ordering standing.
 */

:- use_module('../../src/agents/oaa_run').

solvables([ solvable(meta(prioritize, _G, _P, _FacInfo, _Result),
                     [callback(prioritize)], []) ]).

%   This one simply reverses the Facilitator's ordering, which is enough to
%   show that the meta-agent's opinion is the one that counts.  A real one
%   would consult a preference model.
prioritize(meta(prioritize, _Goal, _Params, FacInfo, Result), _EvParams) :-
    is_list(FacInfo),
    reverse(FacInfo, Result).

:- initialization(run, main).
run :- solvables(S), oaa_agent_run(preference_agent, S, []).
