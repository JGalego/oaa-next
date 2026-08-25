#!/usr/bin/env swipl
/*  oaa-next example -- a provider reachable directly
 *
 *  An agent willing to take requests over a direct connection opens a
 *  listener socket before registering, because registration is what tells the
 *  Facilitator the socket exists.  Developer's Guide 10.1.
 *
 *  Nothing else changes.  The agent answers a request arriving on a direct
 *  connection exactly as it answers one relayed by the Facilitator, and it
 *  cannot tell which it is handling.
 */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').

solvables([solvable(echo(_In, _Out), [callback(echo_back)], [])]).

echo_back(echo(In, Out), _Params) :- Out = echoed(In).

:- initialization(run, main).

run :-
    solvables(S),
    oaa_setup_communication([]),
    oaa_agent_run(direct_agent, S, []).
