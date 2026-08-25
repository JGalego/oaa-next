/*  oaa-next -- triggers
 *
 *  Provenance: RECONSTRUCTED.
 *  Developer's Guide v2.3.2 sections 4.3.5 and 8.
 */

:- module(oaa_trigger,
          [ oaa_add_trigger/4,          % +Type, +Condition, +Action, +Params
            oaa_remove_trigger/4,       % +Type, +Condition, +Action, +Params
            oaa_check_triggers/3,       % +Type, +Condition, +Params
            oaa_triggers/1,             % -Triggers
            oaa_trigger_clear/0,
            oaa_note_data_change/2,     % +Operation, +Clause
            oaa_note_event/3,           % +Direction, +From, +Event
            oaa_install_trigger/4,      % +Type, +Condition, +Action, +Params
            trigger_is_local/2,         % +Type, +Params
            oaa_fire_trigger/1,         % +Trigger
            oaa_replace_trigger_condition/2 % +Trigger, +NewCondition
          ]).

:- use_module('../icl/icl_term').
:- use_module('../icl/icl_params').
:- use_module('../runtime/oaa_event').
:- use_module(oaa_data).

/** <module> Triggers

A trigger says: when some condition is met, take some action.  There are four
types -- `comm`, `data`, `task` and `time` -- and an agent can install one
locally on itself, on its facilitator, or on a peer.

Triggers are themselves data solvables.  Installing one records it as an
instance of `oaa_trigger/5`, a built-in data solvable declared implicitly for
every agent, so an agent can query its own installed triggers with oaa_Solve
as it would query any other data.  Triggers live in the ordinary data store
here for the same reason.

The library does not check a task trigger's condition.  The Guide states this
explicitly, and it differs from OAA 1.x: application code checks the condition
at whatever times suit it and calls oaa_CheckTriggers once it holds.  An agent
offering a task trigger learns that one has been installed through the
app_setup_trigger callback, and can then set up whatever it needs to notice
the condition.

`time` triggers are absent from this module.  They were never in the
historical agent libraries either: a separate Alarm agent supplies them, and
they are available only while that agent is connected.
*/

:- dynamic trigger_counter/1.

trigger_counter(0).

oaa_trigger_clear :-
    forall(oaa_data_query(oaa_trigger(T, C, A, P, I)),
           oaa_data_remove(self, oaa_trigger(T, C, A, P, I), [do_all(true)], _)),
    retractall(trigger_counter(_)),
    assertz(trigger_counter(0)).

next_trigger_id(Id) :-
    retract(trigger_counter(N)),
    Id is N + 1,
    assertz(trigger_counter(Id)).

%!  oaa_add_trigger(+Type, +Condition, +Action, +Params) is det.
%
%   Install a trigger.  Type is comm, data or task; time triggers belong to
%   the Alarm agent.
%
%   Params may carry:
%
%     * on(What)          -- for comm, `send`, `receive` or both; for data,
%                            `add`, `remove`, `replace` or a combination.  A
%                            variable means every applicable case.
%     * test(Goal)        -- an additional condition that must succeed for the
%                            trigger to fire
%     * recurrence(R)     -- `when` (the default: fire once, then remove),
%                            `whenever`, or a positive integer count
%     * address(A)        -- where to install it; handled by the caller

%   Where a trigger goes.  Developer's Guide 8.2: comm and time triggers
%   default to the installing agent itself, while data and task triggers with
%   no address are routed by the facilitator, which treats the condition as a
%   goal and picks agents whose solvables match it.
%
%   Note what that means for time triggers: their default is `self`, and no
%   agent library implements them, so a time trigger left at its default never
%   fires.  It has to be addressed to an agent that provides them -- the Alarm
%   agent.  That is historical behaviour, not an oversight here.

trigger_is_local(Type, Params) :-
    (   icl_get_param_value(address(A), Params)
    ->  local_address(A)
    ;   memberchk(Type, [comm, time])
    ).

local_address(self) :- !.
local_address([self]) :- !.
local_address(A) :- is_list(A), memberchk(self, A), !.

%!  oaa_install_trigger(+Type, +Condition, +Action, +Params) is det.
%
%   Install a trigger on this agent, whether it was asked for locally or
%   arrived from the facilitator on another agent's behalf.

oaa_install_trigger(Type, Condition, Action, Params) :-
    next_trigger_id(Id),
    oaa_data_add(self, oaa_trigger(Type, Condition, Action, Params, Id), [], _),
    (   Type == task,
        oaa_callback(app_setup_trigger, Closure)
    ->  ignore(call(Closure, Type, Condition, Action, Params))
    ;   true
    ).

oaa_add_trigger(Type, Condition, Action, Params) :-
    (   trigger_is_local(Type, Params)
    ->  oaa_install_trigger(Type, Condition, Action, Params)
    ;   route_trigger(add, Type, Condition, Action, Params)
    ).

%   Installing a trigger elsewhere is routed by the facilitator, using the
%   same unification-based agent selection as a request or a data update.

route_trigger(Mode, Type, Condition, Action, Params) :-
    (   oaa_callback(trigger_route, Closure)
    ->  ignore(call(Closure, Mode, Type, Condition, Action, Params))
    ;   true
    ).

%!  oaa_remove_trigger(+Type, +Condition, +Action, +Params) is det.
%
%   Remove at most one trigger: the first stored whose type, condition and
%   action unify with those given.  Params takes no part in the selection,
%   which the Developer's Guide states explicitly.

oaa_remove_trigger(Type, Condition, Action, Params) :-
    (   trigger_is_local(Type, Params)
    ->  remove_local_trigger(Type, Condition, Action)
    ;   route_trigger(remove, Type, Condition, Action, Params)
    ).

remove_local_trigger(Type, Condition, Action) :-
    (   oaa_data_query(oaa_trigger(Type, Condition, Action, P, Id))
    ->  oaa_data_remove(self, oaa_trigger(Type, Condition, Action, P, Id), [], _)
    ;   true
    ).

oaa_triggers(Triggers) :-
    findall(oaa_trigger(T, C, A, P, I),
            oaa_data_query(oaa_trigger(T, C, A, P, I)),
            Triggers).

% -------------------------------------------------------------- data triggers

%!  oaa_note_data_change(+Operation, +Clause) is det.
%
%   Called after a data solvable is modified.  Operation is add, remove, or
%   replace(Old, New).  Every active data trigger is considered.
%
%   The Developer's Guide is specific about the replace case: the condition
%   is written as replace(OldPattern, NewPattern), so that both the old and
%   the new values are bound when the action runs, letting a
%   trigger able to say "fire when the distance became less than 100".

oaa_note_data_change(Operation, Clause) :-
    operation_key(Operation, Key),
    forall(candidate_trigger(data, Cond, Action, Params, Id),
           consider_data(Key, Operation, Clause, Cond, Action, Params, Id)).

operation_key(replace(_, _), replace) :- !.
operation_key(Op, Op).

consider_data(Key, Operation, Clause, Cond, Action, Params, Id) :-
    (   on_matches(Params, Key, [add, remove, replace]),
        data_condition_matches(Cond, Operation, Clause, Bound),
        test_succeeds(Params)
    ->  fire(Bound, Action, Params, Id)
    ;   true
    ).

%   A bound condition is unified against the changed clause; an unbound one
%   means the trigger is considered for every data modification.

data_condition_matches(Cond, replace(Old, New), _Clause, Bound) :- !,
    (   var(Cond)
    ->  Bound = replace(Old, New)
    ;   Cond = replace(_, _),
        copy_term(Cond, replace(OldPat, NewPat)),
        OldPat = Old, NewPat = New,
        Bound = replace(Old, New)
    ).
data_condition_matches(Cond, _Operation, Clause, Bound) :-
    (   var(Cond)
    ->  Bound = Clause
    ;   copy_term(Cond, Pat),
        Pat = Clause,
        Bound = Clause
    ).

% -------------------------------------------------------------- comm triggers

%!  oaa_note_event(+Direction, +From, +Event) is det.
%
%   Called whenever an event is sent or received.  Direction is `send` or
%   `receive`.
%
%   A comm trigger's condition has the form event(FromToAgtId, Content,
%   Params) and is unified against the traffic.  The Guide notes that Params
%   should be left as a variable when installing one: it is Content that
%   selects the event of interest, and Params is bound for the action's use.

oaa_note_event(Direction, From, Event) :-
    forall(candidate_trigger(comm, Cond, Action, Params, Id),
           consider_comm(Direction, From, Event, Cond, Action, Params, Id)).

consider_comm(Direction, From, Event, Cond, Action, Params, Id) :-
    (   on_matches(Params, Direction, [send, receive]),
        comm_condition_matches(Cond, From, Event, Bound),
        test_succeeds(Params)
    ->  fire(Bound, Action, Params, Id)
    ;   true
    ).

comm_condition_matches(Cond, From, Event, Bound) :-
    (   var(Cond)
    ->  Bound = event(From, Event, [])
    ;   copy_term(Cond, event(F, Content, P)),
        F = From, Content = Event, ( var(P) -> P = [] ; true ),
        Bound = event(From, Event, P)
    ).

% -------------------------------------------------------------- task triggers

%!  oaa_check_triggers(+Type, +Condition, +Params) is det.
%
%   Application code calls this when a task trigger's condition has become
%   true.  The library then checks the trigger's own test/1 parameter, if it
%   has one, before firing -- which is the division of labour the Developer's
%   Guide describes: the application knows when the condition holds, the
%   library owns everything after that.

oaa_check_triggers(Type, Condition, _Params) :-
    forall(candidate_trigger(Type, Cond, Action, TParams, Id),
           consider_task(Condition, Cond, Action, TParams, Id)).

consider_task(Condition, Cond, Action, Params, Id) :-
    (   copy_term(Cond, Pat),
        Pat = Condition,
        test_succeeds(Params)
    ->  fire(Condition, Action, Params, Id)
    ;   true
    ).

% ------------------------------------------------------------------ firing

candidate_trigger(Type, Cond, Action, Params, Id) :-
    oaa_data_query(oaa_trigger(Type, Cond, Action, Params, Id)).

%   on/1 restricts which circumstances select a trigger.  A variable, or an
%   absent parameter, means all of them.

on_matches(Params, What, All) :-
    (   icl_get_param_value(on(On), Params)
    ->  (   var(On)
        ->  memberchk(What, All)
        ;   is_list(On)
        ->  memberchk(What, On)
        ;   On == What
        )
    ;   memberchk(What, All)
    ).

%   test/1 is an extra condition that must succeed for the trigger to fire,
%   over and above the condition matching.

test_succeeds(Params) :-
    (   icl_get_param_value(test(Test), Params)
    ->  catch(run_action_goal(Test), _, fail)
    ;   true
    ).

%   Firing runs the action, then applies the recurrence rule.

fire(_Bound, Action, Params, Id) :-
    catch(run_action(Action), E, print_message(error, E)),
    apply_recurrence(Params, Id).

%   An action is an oaa_Solve or oaa_Interpret term, or -- for backwards
%   compatibility with earlier libraries -- a bare ICL goal, which behaves as
%   though it were wrapped in oaa_Interpret.
%
%   Inside a trigger, oaa_Solve's reply parameter defaults to `none` rather
%   than the usual `true`, since a trigger action is a notification and
%   nobody is waiting on its answer.

run_action(Action) :-
    (   solve_action(Action, Goal, Params0)
    ->  icl_param_apply_defaults([reply(none), blocking(false)], Params0, Params),
        run_solve(Goal, Params)
    ;   interpret_action(Action, Goal, _Params)
    ->  run_action_goal(Goal)
    ;   run_action_goal(Action)
    ).

solve_action(oaa_Solve(G, P), G, P).
solve_action(oaa_Solve(G), G, []).
solve_action(oaa_solve(G, P), G, P).
solve_action(oaa_solve(G), G, []).

interpret_action(oaa_Interpret(G, P), G, P).
interpret_action(oaa_Interpret(G), G, []).
interpret_action(oaa_interpret(G, P), G, P).
interpret_action(oaa_interpret(G), G, []).

%   The library must not call the agent layer directly -- that would make the
%   dependency circular -- so the executor is registered as a callback, the
%   same mechanism the agent library uses for everything else it hands back to
%   application code.

run_solve(Goal, Params) :-
    (   oaa_callback(trigger_solve, Closure)
    ->  ignore(call(Closure, Goal, Params))
    ;   true
    ).

run_action_goal(Goal) :-
    (   oaa_callback(trigger_interpret, Closure)
    ->  ignore(call(Closure, Goal))
    ;   true
    ).

%!  apply_recurrence(+Params, +Id) is det.
%
%   `when` -- the default -- fires once and removes the trigger.  `whenever`
%   leaves it in place indefinitely; only oaa_RemoveTrigger takes it away.  A
%   positive integer counts down, and the trigger goes when it reaches zero.

apply_recurrence(Params, Id) :-
    icl_get_param_value(recurrence(R), Params, when),
    (   R == whenever
    ->  true
    ;   integer(R), R > 1
    ->  decrement_recurrence(Id, R)
    ;   remove_by_id(Id)
    ).

decrement_recurrence(Id, R) :-
    (   oaa_data_query(oaa_trigger(T, C, A, P, Id))
    ->  R1 is R - 1,
        icl_param_set(recurrence(R1), P, P1),
        oaa_data_remove(self, oaa_trigger(T, C, A, P, Id), [], _),
        oaa_data_add(self, oaa_trigger(T, C, A, P1, Id), [], _)
    ;   true
    ).

remove_by_id(Id) :-
    (   oaa_data_query(oaa_trigger(T, C, A, P, Id))
    ->  oaa_data_remove(self, oaa_trigger(T, C, A, P, Id), [], _)
    ;   true
    ).

%!  oaa_fire_trigger(+Trigger) is det.
%
%   Run an installed trigger's action and apply its recurrence rule.  An agent
%   that decides for itself when a trigger is due -- the Alarm agent, for time
%   triggers -- calls this once it has decided.

oaa_fire_trigger(oaa_trigger(_Type, Condition, Action, Params, Id)) :-
    fire(Condition, Action, Params, Id).

%!  oaa_replace_trigger_condition(+Trigger, +NewCondition) is det.
%
%   Move an installed trigger on to a new condition, keeping its identity.
%   A recurring time trigger uses this to advance to its next occurrence.

oaa_replace_trigger_condition(oaa_trigger(Type, Cond, Action, Params, Id), New) :-
    (   oaa_data_query(oaa_trigger(Type, Cond, Action, Params, Id))
    ->  oaa_data_remove(self, oaa_trigger(Type, Cond, Action, Params, Id), [], _),
        oaa_data_add(self, oaa_trigger(Type, New, Action, Params, Id), [], _)
    ;   true
    ).
