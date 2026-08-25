#!/usr/bin/env swipl
/*  oaa-next example -- delaying a solution
 *
 *  Some goals cannot be answered quickly.  The Developer's Guide gives a
 *  robot asked to reach a position: the task takes time, and progress arrives
 *  asynchronously, so the handler returns at once and answers when it knows.
 *
 *  None of that is visible to the requester.  Its oaa_Solve blocks until the
 *  robot has succeeded or given up, exactly as for any other goal -- which is
 *  the point of the mechanism.
 */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').
:- use_module('../../src/runtime/oaa_event').

:- dynamic moving/3.            % RobotId, X, Y

solvables([ solvable(move_robot(_Robot, _X, _Y), [callback(move)], []),
            solvable(robot_position(_R, _PX, _PY), [type(data)], [write(true)]) ]).

%   The handler starts the movement and says that the answer will come later.
%   Anything the requester needs to see must arrive through
%   oaa_ReturnDelayedSolutions.
move(move_robot(Robot, X, Y), _Params) :-
    assertz(moving(Robot, X, Y)),
    oaa_delay_solution(Robot).

%   Standing in for the robot's own progress reports: after a couple of idle
%   turns, it has arrived.
:- dynamic ticks/1.
ticks(0).

progress :-
    (   moving(Robot, X, Y)
    ->  retract(ticks(N)), N1 is N + 1, assertz(ticks(N1)),
        (   N1 >= 2
        ->  retract(moving(Robot, X, Y)),
            retractall(ticks(_)), assertz(ticks(0)),
            oaa_return_delayed_solutions(Robot, [move_robot(Robot, X, Y)])
        ;   true
        )
    ;   true
    ).

:- initialization(run, main).

run :-
    solvables(S),
    oaa_agent_start(robot, S, [timeout(0.1)]),
    oaa_register_callback(app_idle, robot:progress),
    oaa_agent_loop.
