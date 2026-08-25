#!/usr/bin/env swipl
/*  oaa-next example -- the Alarm agent
 *
 *  Time triggers are not part of any OAA agent library, and are not part of
 *  this one either.  The Developer's Guide says they are supplied by a
 *  separate Alarm agent and are available only while that agent is connected.
 *  Keeping that separation is a fidelity decision: an agent community without
 *  an Alarm agent genuinely cannot set a time trigger.
 *
 *  The agent declares a trigger solvable matching time expressions, so the
 *  Facilitator routes time-trigger installations here, and then checks the
 *  clock in its idle callback.
 */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').
:- use_module('../../src/agents/oaa_trigger').
:- use_module('../../src/agents/oaa_time').
:- use_module('../../src/runtime/oaa_event').

solvables([ solvable(time_expr(_From, _To, _Recurrence), [type(trigger)], []) ]).

:- initialization(run, main).

run :-
    solvables(S),
    oaa_agent_start(alarm, S, [timeout(0.2)]),
    oaa_register_callback(app_idle, alarm:check_alarms),
    oaa_agent_loop.

%   Fire whatever is due, then either retire the trigger or move it on to its
%   next occurrence.  oaa_SetTimeout is what makes this run: the Developer's
%   Guide notes that the timeout delay is sometimes useful precisely for
%   driving task triggers that need checking at intervals.
check_alarms :-
    get_time(Now),
    forall(due_trigger(Trigger, Cond, Now),
           fire_and_reschedule(Trigger, Cond, Now)).

due_trigger(Trigger, Cond, Now) :-
    oaa_triggers(Triggers),
    member(Trigger, Triggers),
    Trigger = oaa_trigger(time, Cond, _Action, _Params, _Id),
    icl_time_expr_due(Cond, Now, fire).

fire_and_reschedule(Trigger, Cond, Now) :-
    oaa_fire_trigger(Trigger),
    (   icl_time_expr_next(Cond, Now, Next)
    ->  oaa_replace_trigger_condition(Trigger, Next)
    ;   true
    ).
