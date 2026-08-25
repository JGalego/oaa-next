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
    await_capability(interpret("x", _), 60),
    ask("square the number 7"),
    ask("greet the world"),
    ask("do both"),
    ask("something impossible"),
    halt(0).

ask(Request) :-
    (   oaa_solve(interpret(Request, Result), [time_limit(30)])
    ->  format("~w => ~q~n", [Request, Result])
    ;   format("~w => no answer~n", [Request])
    ).

await_capability(_, 0) :- !, throw(oaa_error(capability_never_appeared)).
await_capability(Goal, N) :-
    (   oaa_solve(can_solve(Goal, _), [address(parent), time_limit(1)])
    ->  true
    ;   sleep(0.1), N1 is N - 1, await_capability(Goal, N1)
    ).
