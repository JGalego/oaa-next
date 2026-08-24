/*  oaa-next -- event queue and event loop
 *
 *  Provenance: RECONSTRUCTED.
 *  Developer's Guide v2.3.2 sections 4.4, 4.5 and 5.5.
 */

:- module(oaa_event,
          [ oaa_register_callback/2,    % +Name, +Closure
            oaa_unregister_callback/1,  % +Name
            oaa_callback/2,             % ?Name, ?Closure
            oaa_set_timeout/1,          % +Seconds
            oaa_get_timeout/1,          % -Seconds

            oaa_enqueue/2,              % +ConnId, +Term
            oaa_enqueue/3,              % +ConnId, +Term, +Priority
            oaa_dequeue/3,              % -ConnId, -Term, -Priority
            oaa_dequeue_above/4,        % +MinPriority, -ConnId, -Term, -Priority
            oaa_queue_empty/0,
            oaa_queue_clear/0,
            oaa_flush_below/1,          % +Priority

            oaa_pump/1,                 % +Timeout
            oaa_main_loop/0,
            oaa_main_loop/1,            % +Options
            oaa_stop_loop/0,
            oaa_wait_for/3,             % +Pattern, +Timeout, -Term

            event_priority/2            % +Term, -Priority
          ]).

:- use_module(com_tcp).
:- use_module('../icl/icl_params').

/** <module> The agent event loop

Every agent's activity is structured around an event loop, started by
oaa_MainLoop, which repeatedly checks the event queue and dispatches whatever
arrives.  Three things about the historical design are reproduced here
because they are visible to agent code:

  * **Priorities interrupt.**  Events carry a priority from 1 to 10, default
    5.  While an agent is blocked waiting for solutions to a goal, an arriving
    event of the same or lower priority is queued for later, and one of higher
    priority is executed immediately, interrupting the current goal
    (Developer's Guide 5.5).  That is implemented here as a re-entrant loop
    rather than with threads: oaa_wait_for/3 runs a nested pump that admits
    only events above the priority it was entered at.

  * **Timeouts drive app_idle.**  oaa_SetTimeout supplies the delay used when
    polling; whenever it elapses with nothing to do, the app_idle callback
    runs.  Its default of 0 means no timeout.

  * **Callbacks are registered by name**, as oaa_RegisterCallback did:
    app_do_event, app_idle, app_done, app_setup_trigger.
*/

:- meta_predicate
       oaa_register_callback(+, :),
       oaa_main_loop(:).

:- dynamic callback_entry/2.    % Name, Closure
:- dynamic timeout_delay/1.     % Seconds
:- dynamic pending/4.           % Priority, Seq, ConnId, Term
:- dynamic event_seq/1.
:- dynamic loop_running/0.
:- dynamic loop_floor/1.        % priority floor of the innermost nested pump

event_seq(0).
timeout_delay(0).

% ---------------------------------------------------------------- callbacks

%!  oaa_register_callback(+Name, :Closure) is det.
%
%   Register one of the callbacks the library calls: app_do_event, app_idle,
%   app_done, app_setup_trigger.  Registering again replaces.
%
%   The closure is stored module-qualified.  Without that, a callback stored
%   here and called back from this module would resolve its predicates in this
%   module rather than in the agent that registered it.

oaa_register_callback(Name, Closure) :-
    retractall(callback_entry(Name, _)),
    assertz(callback_entry(Name, Closure)).

oaa_unregister_callback(Name) :-
    retractall(callback_entry(Name, _)).

oaa_callback(Name, Closure) :-
    callback_entry(Name, Closure).

%!  oaa_set_timeout(+Seconds) is det.
%
%   The delay used when polling the event queue.  0 means no timeout, which
%   is the historical default, and means app_idle is never called.

oaa_set_timeout(Seconds) :-
    retractall(timeout_delay(_)),
    assertz(timeout_delay(Seconds)).

oaa_get_timeout(Seconds) :-
    timeout_delay(Seconds).

% -------------------------------------------------------------- event queue

%!  event_priority(+Term, -Priority) is det.
%
%   An event's priority comes from a priority/1 parameter in its parameter
%   list, where it has one.  Default 5.

event_priority(Term, Priority) :-
    (   compound(Term),
        Term =.. [_|Args],
        member(A, Args),
        is_list(A),
        icl_get_param_value(priority(P), A),
        integer(P)
    ->  Priority = P
    ;   Priority = 5
    ).

oaa_enqueue(ConnId, Term) :-
    event_priority(Term, Priority),
    oaa_enqueue(ConnId, Term, Priority).

oaa_enqueue(ConnId, Term, Priority) :-
    retract(event_seq(N)),
    N1 is N + 1,
    assertz(event_seq(N1)),
    assertz(pending(Priority, N1, ConnId, Term)).

%!  oaa_dequeue(-ConnId, -Term, -Priority) is semidet.
%
%   Take the most urgent event: highest priority first, and within one
%   priority, the order it arrived.

oaa_dequeue(ConnId, Term, Priority) :-
    oaa_dequeue_above(0, ConnId, Term, Priority).

%!  oaa_dequeue_above(+MinPriority, -ConnId, -Term, -Priority) is semidet.
%
%   As oaa_dequeue/3, but consider only events strictly above MinPriority.
%   This is what makes a nested pump admit interrupting events while leaving
%   everything else queued for the outer loop.

oaa_dequeue_above(Min, ConnId, Term, Priority) :-
    findall(P-S, ( pending(P, S, _, _), P > Min ), Candidates),
    Candidates \== [],
    best(Candidates, Priority-Seq),
    retract(pending(Priority, Seq, ConnId, Term)).

best([H|T], Best) :-
    foldl(better, T, H, Best).

better(P1-S1, P2-S2, Best) :-
    (   P1 > P2
    ->  Best = P1-S1
    ;   P1 =:= P2, S1 < S2
    ->  Best = P1-S1
    ;   Best = P2-S2
    ).

oaa_queue_empty :-
    \+ pending(_, _, _, _).

oaa_queue_clear :-
    retractall(pending(_, _, _, _)).

%!  oaa_flush_below(+Priority) is det.
%
%   Discard every queued event below Priority.  This backs the flush_events
%   parameter, which the Developer's Guide flags as dangerous precisely
%   because the discarded events are lost and never executed.

oaa_flush_below(Priority) :-
    forall(( pending(P, S, C, T), P < Priority ),
           retract(pending(P, S, C, T))).

% ---------------------------------------------------------------- the pump

%!  oaa_pump(+Timeout) is det.
%
%   One turn of the loop: wait up to Timeout for input on any connection,
%   accept anything pending on a listener, and move whatever arrived onto the
%   queue.  Does not dispatch.

oaa_pump(Timeout) :-
    com_connections(All),
    (   All == []
    ->  true
    ;   com_poll(All, Timeout, Ready),
        forall(member(Id, Ready), service(Id))
    ).

service(Id) :-
    (   com_is_listener(Id)
    ->  accept_pending(Id)
    ;   catch(com_read_pending(Id, Terms), com_eof(Id),
              ( notify_disconnect(Id), Terms = [] )),
        forall(member(T, Terms), oaa_enqueue(Id, T))
    ).

accept_pending(ListenerId) :-
    catch(com_accept(ListenerId, ConnId), _, fail), !,
    (   oaa_callback(on_connect, Closure)
    ->  ignore(call(Closure, ConnId))
    ;   true
    ).
accept_pending(_).

notify_disconnect(Id) :-
    com_close(Id),
    (   oaa_callback(on_disconnect, Closure)
    ->  ignore(call(Closure, Id))
    ;   true
    ).

% ------------------------------------------------------------- the main loop

%!  oaa_main_loop is det.
%!  oaa_main_loop(+Options) is det.
%
%   Run until oaa_stop_loop/0 is called or every connection has closed.
%   Options:
%
%     * handler(Closure)  -- called as call(Closure, ConnId, Event).  Defaults
%       to the registered app_do_event callback.
%     * once(true)        -- make a single turn and return, for testing.

oaa_main_loop :-
    oaa_main_loop([]).

oaa_main_loop(Module:Options) :-
    assertz(loop_running),
    (   memberchk(handler(H), Options)
    ->  Handler = Module:H
    ;   Handler = default_handler
    ),
    catch(loop(Handler, Options), Ball,
          ( retractall(loop_running), throw(Ball) )),
    retractall(loop_running),
    run_app_done.

loop(Handler, Options) :-
    (   \+ loop_running
    ->  true
    ;   turn(Handler),
        (   memberchk(once(true), Options)
        ->  true
        ;   com_connections([])
        ->  true
        ;   loop(Handler, Options)
        )
    ).

turn(Handler) :-
    oaa_get_timeout(Delay),
    %  Only block on the transport when there is nothing already queued.  A
    %  single read can yield several terms -- a client that sends two events
    %  back to back arrives as one batch -- and blocking here with work still
    %  in the queue would leave the later events unhandled until unrelated
    %  traffic happened to wake the loop.
    (   oaa_queue_empty
    ->  poll_delay(Delay, Timeout)
    ;   Timeout = 0
    ),
    oaa_pump(Timeout),
    (   oaa_dequeue(ConnId, Term, _P)
    ->  dispatch(Handler, ConnId, Term)
    ;   run_app_idle(Delay)
    ).

%   With no timeout configured the loop still must not spin, so a bare poll
%   blocks.  A configured timeout is what makes app_idle fire.
poll_delay(0, infinite) :- !.
poll_delay(D, D).

dispatch(Handler, ConnId, Term) :-
    catch(ignore(call(Handler, ConnId, Term)), E, report_error(E)).

default_handler(ConnId, Term) :-
    (   oaa_callback(app_do_event, Closure)
    ->  call(Closure, Term, [from(ConnId)])
    ;   true
    ).

run_app_idle(0) :- !.
run_app_idle(_) :-
    (   oaa_callback(app_idle, Closure)
    ->  catch(ignore(call(Closure)), E, report_error(E))
    ;   true
    ).

run_app_done :-
    (   oaa_callback(app_done, Closure)
    ->  catch(ignore(call(Closure)), E, report_error(E))
    ;   true
    ).

report_error(E) :-
    print_message(error, E).

oaa_stop_loop :-
    retractall(loop_running).

% ------------------------------------------------------- nested waiting

%!  oaa_wait_for(+Pattern, +Timeout, -Term) is semidet.
%
%   Block until an event unifying with Pattern arrives, or Timeout seconds
%   elapse.  This is what a blocking oaa_Solve does while its solutions are
%   in flight.
%
%   While waiting, the priority rule of Developer's Guide 5.5 applies: events
%   above the floor are dispatched immediately, interrupting; events at or
%   below it stay queued for the outer loop.  The floor is the priority of the
%   goal being waited on.

oaa_wait_for(Pattern, Timeout, Term) :-
    event_priority(Pattern, Floor),
    deadline(Timeout, Deadline),
    setup_call_cleanup(
        assertz(loop_floor(Floor)),
        wait_loop(Pattern, Floor, Deadline, Term),
        retract(loop_floor(Floor))).

deadline(infinite, infinite) :- !.
deadline(Timeout, Deadline) :-
    get_time(Now),
    Deadline is Now + Timeout.

wait_loop(Pattern, Floor, Deadline, Term) :-
    (   take_matching(Pattern, Found)
    ->  Term = Found
    ;   remaining(Deadline, Remaining),
        Remaining \== expired,
        oaa_pump(Remaining),
        (   take_matching(Pattern, Found)
        ->  Term = Found
        ;   %  Nothing for us: run anything urgent enough to interrupt, then
            %  go round again.
            (   oaa_dequeue_above(Floor, ConnId, Urgent, _)
            ->  dispatch(default_handler, ConnId, Urgent)
            ;   true
            ),
            wait_loop(Pattern, Floor, Deadline, Term)
        )
    ).

take_matching(Pattern, Term) :-
    pending(P, S, _ConnId, Candidate),
    \+ \+ Candidate = Pattern,
    !,
    retract(pending(P, S, _, Candidate)),
    Term = Candidate,
    Term = Pattern.

remaining(infinite, infinite) :- !.
remaining(Deadline, Remaining) :-
    get_time(Now),
    Left is Deadline - Now,
    (   Left =< 0
    ->  Remaining = expired
    ;   Remaining = Left
    ).
