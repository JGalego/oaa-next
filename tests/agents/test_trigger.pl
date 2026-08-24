/*  oaa-next -- trigger tests  */

:- module(test_trigger, []).

:- use_module('../../src/agents/oaa_trigger').
:- use_module('../../src/agents/oaa_data').
:- use_module('../../src/runtime/oaa_event').

:- dynamic fired/1.

reset :-
    oaa_data_clear,
    oaa_trigger_clear,
    retractall(fired(_)),
    oaa_register_callback(trigger_solve, test_trigger:record_solve),
    oaa_register_callback(trigger_interpret, test_trigger:record_interpret).

record_solve(Goal, _Params) :- assertz(fired(Goal)).
record_interpret(Goal) :- assertz(fired(Goal)).

:- begin_tests(triggers, [setup(reset), cleanup(oaa_trigger_clear)]).

%  Developer's Guide 4.3.5: triggers are recorded as instances of a built-in
%  data solvable, so an agent can query its installed triggers with oaa_Solve
%  just as it would query any other data.
test(triggers_are_data, [setup(reset)]) :-
    oaa_add_trigger(data, position(car1, _, _), oaa_Solve(alarm, []), [recurrence(whenever)]),
    oaa_data_query(oaa_trigger(data, _Cond, _Action, _P, _Id)).

test(query_installed, [setup(reset)]) :-
    oaa_add_trigger(task, arrives(mail), oaa_Solve(notify, []), []),
    oaa_triggers(Ts),
    Ts = [oaa_trigger(task, arrives(mail), _, _, _)].

test(remove_trigger, [setup(reset)]) :-
    oaa_add_trigger(task, arrives(mail), oaa_Solve(notify, []), []),
    oaa_remove_trigger(task, arrives(mail), oaa_Solve(notify, []), []),
    oaa_triggers([]).

%  A data trigger fires on a matching change.
test(data_trigger_on_add, [setup(reset)]) :-
    oaa_add_trigger(data, alert(_), oaa_Solve(notify_admin, []), [on(add), recurrence(whenever)]),
    oaa_note_data_change(add, alert(disk_full)),
    fired(notify_admin).

test(data_trigger_ignores_other_solvable, [setup(reset)]) :-
    oaa_add_trigger(data, alert(_), oaa_Solve(notify_admin, []), [on(add), recurrence(whenever)]),
    oaa_note_data_change(add, unrelated(thing)),
    \+ fired(_).

%  on/1 restricts which operations select the trigger.
test(on_restricts_operation, [setup(reset)]) :-
    oaa_add_trigger(data, alert(_), oaa_Solve(notify_admin, []), [on(remove), recurrence(whenever)]),
    oaa_note_data_change(add, alert(x)),
    \+ fired(_),
    oaa_note_data_change(remove, alert(x)),
    fired(notify_admin).

%  Replacement binds both the old and the new value, which is what lets a
%  trigger react to a change rather than to a state.  Developer's Guide 8.3.
test(replace_binds_old_and_new, [setup(reset)]) :-
    oaa_add_trigger(data,
                    replace(position(car1, _X1, _Y1), position(car1, X2, Y2)),
                    oaa_Solve(moved(X2, Y2), []),
                    [on(replace), recurrence(whenever)]),
    oaa_note_data_change(replace(position(car1, 0, 0), position(car1, 5, 9)),
                         position(car1, 0, 0)),
    fired(moved(5, 9)).

%  test/1 must succeed as well as the condition matching.
test(test_param_blocks, [setup(reset)]) :-
    oaa_register_callback(trigger_interpret, test_trigger:always_fail),
    oaa_add_trigger(data, alert(_), oaa_Solve(notify, []),
                    [on(add), recurrence(whenever), test(never_true)]),
    oaa_note_data_change(add, alert(x)),
    \+ fired(_),
    oaa_register_callback(trigger_interpret, test_trigger:record_interpret).

always_fail(_) :- fail.

%  Recurrence.  Developer's Guide 8.4.
test(when_fires_once, [setup(reset)]) :-
    oaa_add_trigger(data, alert(_), oaa_Solve(notify, []), [on(add)]),
    oaa_note_data_change(add, alert(a)),
    oaa_note_data_change(add, alert(b)),
    findall(X, fired(X), Fired),
    length(Fired, 1),
    oaa_triggers([]).

test(whenever_persists, [setup(reset)]) :-
    oaa_add_trigger(data, alert(_), oaa_Solve(notify, []), [on(add), recurrence(whenever)]),
    oaa_note_data_change(add, alert(a)),
    oaa_note_data_change(add, alert(b)),
    findall(X, fired(X), Fired),
    length(Fired, 2),
    oaa_triggers([_]).

test(integer_recurrence_counts_down, [setup(reset)]) :-
    oaa_add_trigger(data, alert(_), oaa_Solve(notify, []), [on(add), recurrence(2)]),
    oaa_note_data_change(add, alert(a)),
    oaa_triggers([_]),
    oaa_note_data_change(add, alert(b)),
    oaa_triggers([]),
    findall(X, fired(X), Fired),
    length(Fired, 2).

%  Comm triggers watch traffic.  Developer's Guide 8.3: the condition has the
%  form event(FromToAgtId, Content, Params).
test(comm_trigger_on_receive, [setup(reset)]) :-
    oaa_add_trigger(comm,
                    event(_From, ev_solved(_, _, _, _, _, _), _P),
                    oaa_Solve(display, []),
                    [on(receive), recurrence(whenever)]),
    oaa_note_event(receive, parent, ev_solved(1, [], [], _, [], [ok])),
    fired(display).

test(comm_trigger_direction, [setup(reset)]) :-
    oaa_add_trigger(comm, event(_, _, _), oaa_Solve(seen, []),
                    [on(send), recurrence(whenever)]),
    oaa_note_event(receive, parent, anything),
    \+ fired(_),
    oaa_note_event(send, parent, anything),
    fired(seen).

%  Task triggers: the library does not check the condition -- application
%  code does, and then calls oaa_CheckTriggers.  Developer's Guide 8.3.
test(task_trigger_not_checked_by_library, [setup(reset)]) :-
    oaa_add_trigger(task, arrives(mail, [about(security)]),
                    oaa_Solve(notify, []), [recurrence(whenever)]),
    %  Nothing the library does can fire it; only an explicit check.
    oaa_note_data_change(add, arrives(mail, [about(security)])),
    \+ fired(_),
    oaa_check_triggers(task, arrives(mail, [about(security)]), []),
    fired(notify).

test(task_trigger_condition_must_match, [setup(reset)]) :-
    oaa_add_trigger(task, arrives(mail, [about(security)]),
                    oaa_Solve(notify, []), [recurrence(whenever)]),
    oaa_check_triggers(task, arrives(fax, []), []),
    \+ fired(_).

%  An agent offering a task trigger is told when one is installed, so it can
%  set up whatever it needs to notice the condition.
test(app_setup_trigger_called,
     [setup(( reset, retractall(setup_seen(_)) )),
      cleanup(oaa_unregister_callback(app_setup_trigger))]) :-
    oaa_register_callback(app_setup_trigger,
                          [_T, C, _A, _P]>>assertz(setup_seen(C))),
    oaa_add_trigger(task, arrives(mail), oaa_Solve(notify, []), []),
    setup_seen(arrives(mail)).

%  A bare goal as the action is accepted for backwards compatibility and
%  behaves as though wrapped in oaa_Interpret.  Developer's Guide 8.5.
test(bare_goal_action, [setup(reset)]) :-
    oaa_add_trigger(data, alert(_), plain_goal, [on(add), recurrence(whenever)]),
    oaa_note_data_change(add, alert(x)),
    fired(plain_goal).

:- dynamic setup_seen/1.

:- end_tests(triggers).
