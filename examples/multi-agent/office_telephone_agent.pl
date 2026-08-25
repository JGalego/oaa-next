#!/usr/bin/env swipl
/*  oaa-next example -- the Office Assistant demo: the Telephone Agent
 *
 *  Provenance: NEW / ILLUSTRATIVE.  research/office-demo.md quotes the
 *  historical notify sequence for a different trigger (a rental listing):
 *  the Facilitator "contacts the Telephone agent with a request to dial the
 *  telephone, ask for the user, confirm his identity with password ...
 *  and finally play the message."  That location-aware, password-confirmed
 *  pipeline is not reconstructed here -- it is attested only in prose about
 *  a different example, not in enough detail to rebuild faithfully.  What
 *  is reconstructed is the shape the screenshot's own command needs: a
 *  channel agent, reached the ordinary way, that takes delivery of a piece
 *  of text.  A real deployment would put text-to-speech and an actual call
 *  behind this solvable; standing in for both keeps the example runnable
 *  with no telephony dependency, exactly as the scripted LLM provider
 *  stands in for a network call elsewhere in examples/llm/.
 */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').

%   delivered/1 records what was delivered, purely so an observer -- the
%   client below, or a test -- can confirm a delivery happened without
%   needing to capture this agent's own stdout, which a live community
%   otherwise gives no other agent access to.
solvables([ solvable(deliver_by_phone(_Text),
                     [callback(handle_delivery)], []),
            solvable(delivered(_Delivered), [type(data)], [write(true)]) ]).

handle_delivery(deliver_by_phone(Text), _Params) :-
    format("~n[office_telephone_agent] (ring ring) ... delivering by phone: ~w~n~n", [Text]),
    oaa_add_data(delivered(Text), []).

:- initialization(run, main).

run :- solvables(S), oaa_agent_run(office_telephone_agent, S, []).
