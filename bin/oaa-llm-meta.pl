#!/usr/bin/env swipl
/*  oaa-next -- llm-meta
 *
 *  Part of the optional LLM extension.  Refuses to start unless
 *  OAA_MODE=OAA_LLM.
 */

:- use_module('../src/llm/llm_meta_agent').

:- initialization(run, main).

run :- llm_meta_main.
