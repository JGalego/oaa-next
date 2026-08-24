#!/usr/bin/env swipl
/*  oaa-next example -- an agent returning several solutions
 *
 *  Shows two things the historical libraries take for granted: a callback may
 *  succeed more than once, and every solution it produces is collected and
 *  returned to the requester in one reply.
 */

:- use_module('../../src/agents/oaa_run').

solvables([ solvable(greet(_Who, _Greeting), [callback(greeting)], []),
            solvable(language(_Lang), [type(data)], [write(true)]) ]).

greeting(greet(Who, Greeting), _Params) :-
    member(Form, ['Hello', 'Good day', 'Greetings']),
    format(atom(Greeting), "~w, ~w", [Form, Who]).

:- initialization(run, main).

run :-
    solvables(S),
    oaa_agent_run(greet_agent, S, []).
