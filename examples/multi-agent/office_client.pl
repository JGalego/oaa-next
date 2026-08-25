#!/usr/bin/env swipl
/*  oaa-next example -- the Office Assistant demo
 *
 *  Reconstructs the pattern documented in research/office-demo.md: a
 *  natural-language sentence -- the exact command visible in the demo
 *  screenshot cited there -- installs a trigger that watches for mail on a
 *  topic and delivers it through a different channel when it arrives.
 *  Provenance: NEW / ILLUSTRATIVE.  See office_assistant.pl,
 *  office_mail_agent.pl and office_telephone_agent.pl for what each stands
 *  in for and why; none of this claims to reproduce the historical Notify
 *  agent's location-aware delegation, only the trigger pattern the
 *  screenshot itself attests.
 *
 *  Run alongside office_mail_agent.pl, office_telephone_agent.pl and
 *  llm/office_assistant.pl (-oaa_mode OAA_LLM).
 */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').
:- use_module('../../src/agents/oaa_trigger').

:- initialization(run, main).

run :-
    oaa_agent_start(office_client, [], []),
    await_capability(propose_goal(_, _), 60),
    await_capability(mail(_, about(_), _), 60),
    await_capability(deliver_by_phone(_), 60),

    Sentence = "When mail arrives for me about \"security\" get it to me by telephone.",
    (   oaa_solve(propose_goal(Sentence, Goal), [time_limit(30)])
    ->  format("office_assistant proposed: ~q~n", [Goal]),
        execute_proposal(Goal)
    ;   format("office_assistant gave no proposal~n"), halt(1)
    ),

    %  Mail "arrives" -- another agent (here, this client, standing in for
    %  a mail delivery agent no one has built) adding a fact to the mail
    %  data solvable is all "arrival" ever was; see office_mail_agent.pl.
    oaa_add_data(mail(alice,
                      about(security),
                      'Please rotate the shared credentials by Friday.'),
                 []),
    oaa_add_data(mail(bob, about(lunch), 'Want to grab lunch at noon?'), []),

    sleep(0.3),  %  Let the trigger's own oaa_Solve reach the telephone agent.
    findall(T, oaa_solve(delivered(T), [time_limit(5)]), Delivered),
    format("delivered by phone: ~q~n", [Delivered]),
    halt(0).

%   The proposal names the trigger to install using the ICL spelling of the
%   library call it maps to -- the same mapping oaa_trigger.pl already makes
%   for oaa_Solve, oaa_AddData and oaa_RemoveData inside a trigger action,
%   just made here for the one call that installs a trigger in the first
%   place, which nothing delegates a request to.
execute_proposal(oaa_AddTrigger(Type, Cond, Action, Params)) :- !,
    oaa_add_trigger(Type, Cond, Action, Params),
    format("trigger installed: ~q~n", [oaa_trigger(Type, Cond, Action, Params)]).
execute_proposal(Goal) :-
    format("don't know how to install proposal: ~q~n", [Goal]).

await_capability(_, 0) :- !, throw(oaa_error(capability_never_appeared)).
await_capability(Goal, N) :-
    (   oaa_solve(can_solve(Goal, _), [address(parent), time_limit(1)])
    ->  true
    ;   sleep(0.1), N1 is N - 1, await_capability(Goal, N1)
    ).
