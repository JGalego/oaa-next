/*  oaa-next -- event queue and loop tests  */

:- module(test_event, []).

:- use_module('../../src/runtime/oaa_event').
:- use_module('../../src/runtime/com_tcp').

:- begin_tests(event_queue, [setup(oaa_queue_clear), cleanup(oaa_queue_clear)]).

test(fifo_within_priority, [setup(oaa_queue_clear)]) :-
    oaa_enqueue(c, a, 5), oaa_enqueue(c, b, 5), oaa_enqueue(c, d, 5),
    oaa_dequeue(_, T1, _), oaa_dequeue(_, T2, _), oaa_dequeue(_, T3, _),
    [T1,T2,T3] == [a,b,d].

%  Developer's Guide 5.5: highest priority is executed first.
test(priority_order, [setup(oaa_queue_clear)]) :-
    oaa_enqueue(c, low, 2), oaa_enqueue(c, high, 9), oaa_enqueue(c, mid, 5),
    oaa_dequeue(_, T1, _), oaa_dequeue(_, T2, _), oaa_dequeue(_, T3, _),
    [T1,T2,T3] == [high, mid, low].

test(priority_then_fifo, [setup(oaa_queue_clear)]) :-
    oaa_enqueue(c, a, 9), oaa_enqueue(c, b, 9), oaa_enqueue(c, low, 1),
    oaa_dequeue(_, T1, _), oaa_dequeue(_, T2, _), oaa_dequeue(_, T3, _),
    [T1,T2,T3] == [a, b, low].

test(empty, [setup(oaa_queue_clear)]) :-
    oaa_queue_empty,
    \+ oaa_dequeue(_, _, _).

test(dequeue_above, [setup(oaa_queue_clear)]) :-
    oaa_enqueue(c, low, 3), oaa_enqueue(c, high, 8),
    oaa_dequeue_above(5, _, T, _), T == high,
    \+ oaa_dequeue_above(5, _, _, _),
    oaa_dequeue(_, T2, _), T2 == low.

%  Priority is read from the event's parameter list, defaulting to 5.
test(priority_from_params) :-
    event_priority(ev_solve(1, g, [priority(9)]), P), P == 9.
test(priority_default) :-
    event_priority(ev_solve(1, g, []), P), P == 5.
test(priority_shorthand_ignored_for_nonint) :-
    event_priority(ev_solve(1, g, [blocking]), P), P == 5.
test(priority_of_atom_event) :-
    event_priority(plain_atom, P), P == 5.

%  flush_events discards queued events below a priority; the Developer's
%  Guide warns they are lost and never executed.
test(flush_below, [setup(oaa_queue_clear)]) :-
    oaa_enqueue(c, low, 2), oaa_enqueue(c, mid, 5), oaa_enqueue(c, high, 9),
    oaa_flush_below(5),
    oaa_dequeue(_, T1, _), oaa_dequeue(_, T2, _),
    [T1, T2] == [high, mid],
    oaa_queue_empty.

:- end_tests(event_queue).


:- begin_tests(event_loop, [cleanup(( oaa_queue_clear, com_close_all ))]).

%  A registered app_do_event callback receives dispatched events.
test(dispatch_to_callback,
     [setup(( oaa_queue_clear, retractall(seen(_)) )),
      cleanup(oaa_unregister_callback(app_do_event))]) :-
    oaa_register_callback(app_do_event, [T, _P]>>assertz(seen(T))),
    oaa_enqueue(c, hello(world), 5),
    oaa_main_loop([once(true)]),
    seen(hello(world)).

%  A timeout with an empty queue runs app_idle.
test(idle_callback,
     [setup(( oaa_queue_clear, retractall(idled) )),
      cleanup(( oaa_unregister_callback(app_idle), oaa_set_timeout(0) ))]) :-
    oaa_set_timeout(0.05),
    oaa_register_callback(app_idle, []>>assertz(idled)),
    oaa_main_loop([once(true)]),
    idled.

%  app_done runs when the loop finishes.
test(done_callback,
     [setup(( oaa_queue_clear, retractall(doned) )),
      cleanup(oaa_unregister_callback(app_done))]) :-
    oaa_register_callback(app_done, [] >>assertz(doned)),
    oaa_main_loop([once(true)]),
    doned.

%  oaa_wait_for picks the matching event out of the queue and leaves the rest.
test(wait_for_matching, [setup(oaa_queue_clear)]) :-
    oaa_enqueue(c, other(1), 5),
    oaa_enqueue(c, ev_solved(7, [], [], _, [], [ok]), 5),
    oaa_wait_for(ev_solved(7, _, _, _, _, Solutions), 1, _),
    Solutions == [ok],
    oaa_dequeue(_, Rest, _), Rest == other(1).

test(wait_for_times_out, [setup(oaa_queue_clear), fail]) :-
    oaa_wait_for(never(_), 0.05, _).

%  While waiting, a higher-priority event interrupts and is dispatched; an
%  equal-or-lower one stays queued.  Developer's Guide 5.5.
test(higher_priority_interrupts,
     [setup(( oaa_queue_clear, retractall(seen(_)) )),
      cleanup(oaa_unregister_callback(app_do_event))]) :-
    oaa_register_callback(app_do_event, [T, _P]>>assertz(seen(T))),
    oaa_enqueue(c, urgent, 9),
    oaa_enqueue(c, routine, 3),
    \+ oaa_wait_for(never_arrives(_), 0.05, _),
    seen(urgent),
    \+ seen(routine),
    oaa_dequeue(_, Left, _), Left == routine.

:- dynamic seen/1, idled/0, doned/0.

:- end_tests(event_loop).
