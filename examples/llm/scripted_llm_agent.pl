#!/usr/bin/env swipl
/*  oaa-next example -- an LLM-backed agent, with a scripted model
 *
 *  The same agent as bin/oaa-llm-agent.pl, with the scripted provider standing
 *  in for a real model so the behaviour is deterministic and no network call
 *  is made.  What the community sees is identical either way: an agent that
 *  declares interpret/2, registers like any other, and asks for services with
 *  oaa_Solve.
 *
 *  Run with -oaa_mode OAA_LLM; the extension refuses to start otherwise.
 */

:- use_module('../../src/llm/llm_config').
:- use_module('../../src/llm/llm_agent').
:- use_module('../../src/llm/providers/llm_scripted').
:- use_module('../../src/agents/oaa_run').

:- initialization(run, main).

run :-
    llm_require_enabled,
    script,
    llm_agent_solvables(S),
    oaa_agent_run(llm_agent, S, []).

%   Standing in for a model that has read the community's capabilities and
%   written an ICL goal against them.
script :-
    scripted_reply("square", "square(7, Answer)"),
    scripted_reply("greet the world", "greet(world, Greeting)"),
    scripted_reply("both", "(square(3, N), greet(world, G))"),
    scripted_reply("impossible", "cannot").
