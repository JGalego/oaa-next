/*  oaa-next -- ICL time expressions
 *
 *  Provenance: RECONSTRUCTED.
 *  Developer's Guide v2.3.2 sections 4.3.5 and 8.3.
 */

:- module(oaa_time,
          [ icl_date_stamp/2,           % +IclDate, -UnixSeconds
            icl_date_now/1,             % -IclDate
            icl_time_expr_due/3,        % +TimeExpr, +Now, -Due
            icl_recurrence_seconds/2,   % +Recurrence, -Seconds
            icl_time_expr_next/3        % +TimeExpr, +Now, -NextExpr
          ]).

/** <module> Time expressions

A time trigger's condition is

    time_expr(FromDateTime, ToDateTime, Recurrence)

where each date is written

    date(Year-1900, Month-1, Day, Hr, Min, Sec)

so that 2:15pm on 15 December 2001 is `date(101, 11, 15, 14, 15, 0)`.  The
offsets are the C `struct tm` convention, which is where the historical
libraries took them from.

`Recurrence` is `recurrence(Value, Unit)` -- `recurrence(3, minute)` for every
three minutes -- and `recurrence(0, 0)` for a trigger that fires once.

These conversions live in the agent library because the format is part of
ICL.  Deciding when a trigger is due, and firing it, belongs to the Alarm
agent: the historical agent libraries do not implement time triggers, and
neither does this one.
*/

%!  icl_date_stamp(+IclDate, -UnixSeconds) is semidet.

icl_date_stamp(date(Y1900, M0, D, H, Mi, S), Stamp) :-
    Year is Y1900 + 1900,
    Month is M0 + 1,
    catch(date_time_stamp(date(Year, Month, D, H, Mi, S, 0, -, -), Stamp), _, fail).

%!  icl_date_now(-IclDate) is det.

icl_date_now(date(Y1900, M0, D, H, Mi, S)) :-
    get_time(Now),
    stamp_date_time(Now, date(Year, Month, D, H, Mi, SF, _, _, _), 'UTC'),
    Y1900 is Year - 1900,
    M0 is Month - 1,
    S is truncate(SF).

%!  icl_recurrence_seconds(+Recurrence, -Seconds) is semidet.
%
%   Fails for `recurrence(0, 0)`, the form that means "does not recur".

icl_recurrence_seconds(recurrence(V, U), Seconds) :-
    integer(V), V > 0,
    unit_seconds(U, Per),
    Seconds is V * Per.

unit_seconds(second, 1).
unit_seconds(seconds, 1).
unit_seconds(minute, 60).
unit_seconds(minutes, 60).
unit_seconds(hour, 3600).
unit_seconds(hours, 3600).
unit_seconds(day, 86400).
unit_seconds(days, 86400).
unit_seconds(week, 604800).
unit_seconds(weeks, 604800).

%!  icl_time_expr_due(+TimeExpr, +Now, -Due) is semidet.
%
%   Due is `fire` when the moment has arrived, `expired` when the window has
%   closed, and `waiting` otherwise.  A recurring trigger keeps firing until
%   its ToDateTime passes; a one-shot fires once when its FromDateTime does.

icl_time_expr_due(time_expr(From, To, Recurrence), Now, Due) :-
    icl_date_stamp(From, FromStamp),
    (   icl_date_stamp(To, ToStamp) -> true ; ToStamp = FromStamp ),
    (   Now >= FromStamp
    ->  (   icl_recurrence_seconds(Recurrence, _)
        ->  ( Now =< ToStamp -> Due = fire ; Due = expired )
        ;   Due = fire
        )
    ;   Due = waiting
    ).

%!  icl_time_expr_next(+TimeExpr, +Now, -NextExpr) is semidet.
%
%   The same expression moved on to its next occurrence.  Fails when the
%   trigger does not recur, which is how a one-shot retires.

icl_time_expr_next(time_expr(From, To, Recurrence), Now, time_expr(Next, To, Recurrence)) :-
    icl_recurrence_seconds(Recurrence, Step),
    icl_date_stamp(From, FromStamp),
    advance(FromStamp, Step, Now, NextStamp),
    stamp_icl_date(NextStamp, Next).

advance(Stamp, Step, Now, Next) :-
    (   Stamp + Step > Now
    ->  Next is Stamp + Step
    ;   Elapsed is Now - Stamp,
        Steps is truncate(Elapsed / Step) + 1,
        Next is Stamp + Steps * Step
    ).

stamp_icl_date(Stamp, date(Y1900, M0, D, H, Mi, S)) :-
    stamp_date_time(Stamp, date(Year, Month, D, H, Mi, SF, _, _, _), 'UTC'),
    Y1900 is Year - 1900,
    M0 is Month - 1,
    S is truncate(SF).
