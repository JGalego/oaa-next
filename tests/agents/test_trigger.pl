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
    oaa_add_trigger(data, position(car1, _, _), oaa_Solve(alarm, []),
                    [recurrence(whenever), address(self)]),
    oaa_data_query(oaa_trigger(data, _Cond, _Action, _P, _Id)).

test(query_installed, [setup(reset)]) :-
    oaa_add_trigger(task, arrives(mail), oaa_Solve(notify, []), [address(self)]),
    oaa_triggers(Ts),
    Ts = [oaa_trigger(task, arrives(mail), _, _, _)].

test(remove_trigger, [setup(reset)]) :-
    oaa_add_trigger(task, arrives(mail), oaa_Solve(notify, []), [address(self)]),
    oaa_remove_trigger(task, arrives(mail), oaa_Solve(notify, []), [address(self)]),
    oaa_triggers([]).

%  A data trigger fires on a matching change.
test(data_trigger_on_add, [setup(reset)]) :-
    oaa_add_trigger(data, alert(_), oaa_Solve(notify_admin, []),
                    [on(add), recurrence(whenever), address(self)]),
    oaa_note_data_change(add, alert(disk_full)),
    fired(notify_admin).

test(data_trigger_ignores_other_solvable, [setup(reset)]) :-
    oaa_add_trigger(data, alert(_), oaa_Solve(notify_admin, []),
                    [on(add), recurrence(whenever), address(self)]),
    oaa_note_data_change(add, unrelated(thing)),
    \+ fired(_).

%  on/1 restricts which operations select the trigger.
test(on_restricts_operation, [setup(reset)]) :-
    oaa_add_trigger(data, alert(_), oaa_Solve(notify_admin, []),
                    [on(remove), recurrence(whenever), address(self)]),
    oaa_note_data_change(add, alert(x)),
    \+ fired(_),
    oaa_note_data_change(remove, alert(x)),
    fired(notify_admin).

%  Replacement binds both the old and the new value, letting a trigger react
%  to a change rather than to a state.  Developer's Guide 8.3.
test(replace_binds_old_and_new, [setup(reset)]) :-
    oaa_add_trigger(data,
                    replace(position(car1, _X1, _Y1), position(car1, X2, Y2)),
                    oaa_Solve(moved(X2, Y2), []),
                    [on(replace), recurrence(whenever), address(self)]),
    oaa_note_data_change(replace(position(car1, 0, 0), position(car1, 5, 9)),
                         position(car1, 0, 0)),
    fired(moved(5, 9)).

%  test/1 must succeed as well as the condition matching.
test(test_param_blocks, [setup(reset)]) :-
    oaa_register_callback(trigger_interpret, test_trigger:always_fail),
    oaa_add_trigger(data, alert(_), oaa_Solve(notify, []),
                    [on(add), recurrence(whenever), test(never_true), address(self)]),
    oaa_note_data_change(add, alert(x)),
    \+ fired(_),
    oaa_register_callback(trigger_interpret, test_trigger:record_interpret).

always_fail(_) :- fail.

%  Recurrence.  Developer's Guide 8.4.
test(when_fires_once, [setup(reset)]) :-
    oaa_add_trigger(data, alert(_), oaa_Solve(notify, []), [on(add), address(self)]),
    oaa_note_data_change(add, alert(a)),
    oaa_note_data_change(add, alert(b)),
    findall(X, fired(X), Fired),
    length(Fired, 1),
    oaa_triggers([]).

test(whenever_persists, [setup(reset)]) :-
    oaa_add_trigger(data, alert(_), oaa_Solve(notify, []),
                    [on(add), recurrence(whenever), address(self)]),
    oaa_note_data_change(add, alert(a)),
    oaa_note_data_change(add, alert(b)),
    findall(X, fired(X), Fired),
    length(Fired, 2),
    oaa_triggers([_]).

test(integer_recurrence_counts_down, [setup(reset)]) :-
    oaa_add_trigger(data, alert(_), oaa_Solve(notify, []),
                    [on(add), recurrence(2), address(self)]),
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
                    oaa_Solve(notify, []), [recurrence(whenever), address(self)]),
    %  Nothing the library does can fire it; only an explicit check.
    oaa_note_data_change(add, arrives(mail, [about(security)])),
    \+ fired(_),
    oaa_check_triggers(task, arrives(mail, [about(security)]), []),
    fired(notify).

test(task_trigger_condition_must_match, [setup(reset)]) :-
    oaa_add_trigger(task, arrives(mail, [about(security)]),
                    oaa_Solve(notify, []), [recurrence(whenever), address(self)]),
    oaa_check_triggers(task, arrives(fax, []), []),
    \+ fired(_).

%  An agent offering a task trigger is told when one is installed, so it can
%  set up whatever it needs to notice the condition.
test(app_setup_trigger_called,
     [setup(( reset, retractall(setup_seen(_)) )),
      cleanup(oaa_unregister_callback(app_setup_trigger))]) :-
    oaa_register_callback(app_setup_trigger,
                          [_T, C, _A, _P]>>assertz(setup_seen(C))),
    oaa_add_trigger(task, arrives(mail), oaa_Solve(notify, []), [address(self)]),
    setup_seen(arrives(mail)).

%  A bare goal as the action is accepted for backwards compatibility and
%  behaves as though wrapped in oaa_Interpret.  Developer's Guide 8.5.
test(bare_goal_action, [setup(reset)]) :-
    oaa_add_trigger(data, alert(_), plain_goal,
                    [on(add), recurrence(whenever), address(self)]),
    oaa_note_data_change(add, alert(x)),
    fired(plain_goal).

:- dynamic setup_seen/1.

%  Developer's Guide 8.2: comm and time triggers default to the installing
%  agent, while data and task triggers with no address are routed by the
%  facilitator.  With no facilitator attached, an unaddressed data trigger
%  therefore installs nowhere.
test(unaddressed_data_trigger_is_routed, [setup(reset)]) :-
    oaa_add_trigger(data, alert(_), oaa_Solve(notify, []), [on(add)]),
    oaa_triggers([]).

test(comm_trigger_defaults_to_self, [setup(reset)]) :-
    oaa_add_trigger(comm, event(_, _, _), oaa_Solve(seen, []), []),
    oaa_triggers([_]).

:- end_tests(triggers).


:- use_module('../../src/agents/oaa_time').

:- begin_tests(icl_time).

%  Developer's Guide 4.3.5: dates use the C struct tm offsets, so the year is
%  given less 1900 and the month less one.  2:15pm on 15 December 2001 is
%  date(101, 11, 15, 14, 15, 0).
test(devguide_date_example) :-
    icl_date_stamp(date(101, 11, 15, 14, 15, 0), Stamp),
    stamp_date_time(Stamp, date(Y, M, D, H, Mi, _, _, _, _), 'UTC'),
    Y == 2001, M == 12, D == 15, H == 14, Mi == 15.

test(now_round_trips) :-
    icl_date_now(Now),
    icl_date_stamp(Now, _).

test(recurrence_units) :-
    icl_recurrence_seconds(recurrence(3, minute), S1), S1 == 180,
    icl_recurrence_seconds(recurrence(2, hour), S2), S2 == 7200,
    icl_recurrence_seconds(recurrence(1, day), S3), S3 == 86400.

%  recurrence(0, 0) is the form for a trigger that does not recur.
test(no_recurrence, [fail]) :-
    icl_recurrence_seconds(recurrence(0, 0), _).

test(due_when_time_has_come) :-
    icl_date_stamp(date(101, 0, 1, 0, 0, 0), Past),
    Now is Past + 100,
    icl_time_expr_due(time_expr(date(101,0,1,0,0,0), date(101,0,1,0,0,0),
                                recurrence(0,0)), Now, Due),
    Due == fire.

test(waiting_before_the_time) :-
    icl_date_stamp(date(101, 0, 1, 0, 0, 0), Future),
    Now is Future - 100,
    icl_time_expr_due(time_expr(date(101,0,1,0,0,0), date(101,0,1,0,0,0),
                                recurrence(0,0)), Now, Due),
    Due == waiting.

%  A recurring trigger stops when its window closes.
test(recurring_expires_after_window) :-
    icl_date_stamp(date(101, 0, 2, 0, 0, 0), End),
    Now is End + 3600,
    icl_time_expr_due(time_expr(date(101,0,1,0,0,0), date(101,0,2,0,0,0),
                                recurrence(3, minute)), Now, Due),
    Due == expired.

test(next_occurrence_advances) :-
    icl_date_stamp(date(101, 0, 1, 0, 0, 0), Start),
    Now is Start + 10,
    icl_time_expr_next(time_expr(date(101,0,1,0,0,0), date(101,0,2,0,0,0),
                                 recurrence(3, minute)), Now, Next),
    Next = time_expr(NextFrom, _, _),
    icl_date_stamp(NextFrom, NextStamp),
    NextStamp =:= Start + 180.

test(one_shot_has_no_next, [fail]) :-
    icl_date_stamp(date(101, 0, 1, 0, 0, 0), Start),
    Now is Start + 10,
    icl_time_expr_next(time_expr(date(101,0,1,0,0,0), date(101,0,1,0,0,0),
                                 recurrence(0,0)), Now, _).

:- end_tests(icl_time).


:- begin_tests(trigger_bindings, [setup(reset), cleanup(oaa_trigger_clear)]).

%  Developer's Guide 8.3: variables bound by a trigger's condition are
%  available in its action.  A replace condition names both the old and the
%  new value precisely so the action can use them.
test(data_condition_binds_action, [setup(reset)]) :-
    oaa_add_trigger(data, alert(Level), oaa_Solve(raised(Level), []),
                    [on(add), recurrence(whenever), address(self)]),
    oaa_note_data_change(add, alert(critical)),
    fired(raised(critical)).

test(comm_condition_binds_action, [setup(reset)]) :-
    oaa_add_trigger(comm, event(From, Content, _P),
                    oaa_Solve(saw(From, Content), []),
                    [on(receive), recurrence(whenever)]),
    oaa_note_event(receive, parent, ping(7)),
    fired(saw(parent, ping(7))).

test(task_condition_binds_action, [setup(reset)]) :-
    oaa_add_trigger(task, arrives(mail, Subject),
                    oaa_Solve(notify(Subject), []),
                    [recurrence(whenever), address(self)]),
    oaa_check_triggers(task, arrives(mail, security), []),
    fired(notify(security)).

%  A recurring trigger must not carry bindings from one firing to the next.
test(bindings_do_not_persist, [setup(reset)]) :-
    oaa_add_trigger(data, alert(Level), oaa_Solve(raised(Level), []),
                    [on(add), recurrence(whenever), address(self)]),
    oaa_note_data_change(add, alert(first)),
    oaa_note_data_change(add, alert(second)),
    fired(raised(first)),
    fired(raised(second)).

:- end_tests(trigger_bindings).
