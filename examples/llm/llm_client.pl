#!/usr/bin/env swipl
/*  oaa-next example -- asking the community in English
 *
 *  This client has no idea an LLM is involved.  It asks for interpret/2, the
 *  Facilitator finds an agent that provides it, and an answer comes back.
 *  Swapping the LLM agent for a hand-written parser would change nothing
 *  here, which is the property worth having.
 */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').

:- initialization(run, main).

run :-
    oaa_agent_start(llm_client, [], []),
    Session = llm_demo,
    await_capability(interpret(Session, "x", _), 60),
    oaa_solve(reset_conversation(Session), [time_limit(10)]),
    ask(Session, "square the number 7"),
    ask(Session, "greet the world"),
    ask(Session, "do both"),
    ask(Session, "something impossible"),
    halt(0).

ask(Session, Request) :-
    (   oaa_solve(interpret(Session, Request, Result), [time_limit(30)])
    ->  format("~w => ~q~n", [Request, Result])
    ;   format("~w => no answer~n", [Request])
    ).

await_capability(_, 0) :- !, throw(oaa_error(capability_never_appeared)).
await_capability(Goal, N) :-
    (   oaa_solve(can_solve(Goal, _), [address(parent), time_limit(1)])
    ->  true
    ;   sleep(0.1), N1 is N - 1, await_capability(Goal, N1)
    ).
