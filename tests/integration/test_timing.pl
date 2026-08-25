/*  oaa-next -- delayed solutions and time triggers  */

:- module(test_timing, []).

:- use_module(community).

agents([ '/examples/multi-agent/robot_agent.pl',
         '/examples/multi-agent/alarm_agent.pl' ]).

:- begin_tests(timing,
               [ setup(( agents(A), start_community(A, C), nb_setval(tc, C) )),
                 cleanup(( nb_getval(tc, C), stop_community(C) )) ]).

lines(Lines) :-
    nb_getval(tc, C),
    run_program(C, '/examples/multi-agent/timed_client.pl', Lines).

%   A handler that calls oaa_DelaySolution answers later, and the requester
%   cannot tell: its oaa_Solve blocks until the answer arrives, as for any
%   other goal.  Developer's Guide 5.4.
test(delayed_solution_still_blocks) :-
    lines(Lines),
    memberchk("robot arrived", Lines).

%   Time triggers belong to the Alarm agent, not to any agent library, so a
%   time trigger has to be addressed to it.  Developer's Guide 4.3.5.
test(time_trigger_fires_via_alarm_agent) :-
    lines(Lines),
    memberchk("time trigger fired", Lines).

:- end_tests(timing).
