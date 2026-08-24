#!/usr/bin/env swipl
/*  oaa-next example -- a minimal agent
 *
 *  The smallest thing that is recognisably an OAA agent: it declares one
 *  procedure solvable, defines the callback that implements it, connects,
 *  registers, and runs the event loop.  Compare the Prolog agent template in
 *  the OAA FAQ, section 3.2.
 */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').

%   1. Decide what services this agent provides.
solvables([ solvable(square(_X, _Y),
                     [ callback(square_of),
                       argspecs(in(number, true), out(number, true)) ],
                     []) ]).

%   2. Implement each procedure solvable.  A callback receives the incoming
%      goal and a parameter list, and returns solutions by the usual means --
%      in Prolog, by binding and by backtracking.
square_of(square(X, Y), _Params) :-
    number(X),
    Y is X * X.

:- initialization(run, main).

run :-
    solvables(S),
    oaa_agent_run(square_agent, S, []).
