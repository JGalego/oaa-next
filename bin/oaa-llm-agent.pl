#!/usr/bin/env swipl
/*  oaa-next -- llm-agent
 *
 *  Part of the optional LLM extension.  Refuses to start unless
 *  OAA_MODE=OAA_LLM.
 */

:- use_module('../src/llm/llm_agent').

:- initialization(run, main).

run :- llm_agent_main.
