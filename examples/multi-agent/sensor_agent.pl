#!/usr/bin/env swipl
/*  oaa-next example -- a blackboard writer
 *
 *  Declares a data solvable *on the facilitator*, by passing address(parent),
 *  and then writes to it.  The result is a shared data predicate that every
 *  client of that facilitator can read and write: the blackboard style of
 *  communication described in the Developer's Guide, section 7.7.
 *
 *  Note that the facts are owned by this agent.  If it goes offline they go
 *  with it, unless the solvable is declared persistent -- ownership is
 *  maintained transparently by the library, and is the mechanism behind that.
 */

:- use_module('../../src/agents/oaa_run').
:- use_module('../../src/agents/oaa_agent').

:- initialization(run, main).

run :-
    oaa_agent_start(sensor, [], []),
    oaa_declare(solvable(observation(_Sensor, _Value), [type(data)], [write(true)]),
                [address(parent)]),
    oaa_add_data(observation(temperature, 21), []),
    oaa_add_data(observation(humidity, 40), []),
    oaa_agent_loop.
