/*  oaa-next -- the LLM extension  */

:- module(test_llm_agent, []).

:- use_module('../../src/runtime/oaa_config').
:- use_module('../../src/llm/llm_config').
:- use_module('../../src/llm/llm_provider').
:- use_module('../../src/llm/providers/llm_scripted').
:- use_module('../../src/llm/providers/llm_anthropic').
:- use_module('../../src/llm/providers/llm_openai').
:- use_module('../../src/llm/llm_agent').
:- use_module('../../src/icl/icl_term').

enable :-
    setenv('OAA_MODE', 'OAA_LLM'),
    oaa_config_reset,
    scripted_clear.

disable :-
    unsetenv('OAA_MODE'),
    oaa_config_reset,
    scripted_clear.

:- begin_tests(llm_provider, [setup(enable), cleanup(disable)]).

test(scripted_provider_answers) :-
    scripted_reply("weather", "weather(london, Forecast)"),
    llm_complete(scripted, [message(user, "what is the weather")], [], R),
    llm_response_text(R, T),
    T == "weather(london, Forecast)".

test(unmatched_prompt_gives_nothing) :-
    llm_complete(scripted, [message(user, "unrelated")], [], R),
    llm_response_text(R, T),
    T == "".

test(unknown_provider_is_an_error,
     [throws(oaa_error(unknown_llm_provider(_)))]) :-
    llm_complete(no_such_provider, [message(user, "hi")], [], _).

%   Adapters for more than one vendor are registered, which is what keeps the
%   interface honest: the OAA layer must not depend on any single provider.
test(several_providers_are_available) :-
    llm_known_provider(anthropic, _),
    llm_known_provider(openai, _),
    llm_known_provider(scripted, _).

test(default_provider_reaches_no_network) :-
    llm_provider_name(P),
    P == scripted.

:- end_tests(llm_provider).


:- begin_tests(llm_goal_extraction, [setup(enable), cleanup(disable)]).

%   A model's reply becomes a goal only if it is well-formed ICL.
test(plain_goal) :-
    icl_from_reply("square(7, X)", G), G =@= square(7, _).
test(compound_goal) :-
    icl_from_reply("(square(3, N), greet(world, G))", Goal),
    Goal = (A, B), A =@= square(3, _), B =@= greet(world, _).
test(tolerates_code_fences) :-
    icl_from_reply("```\nsquare(7, X)\n```", G), G =@= square(7, _).
test(tolerates_surrounding_space) :-
    icl_from_reply("   square(7, X)  \n", G), G =@= square(7, _).

%   A refusal is a refusal, not something to salvage.
test(refusal_is_rejected, [fail]) :-
    icl_from_reply("cannot", _).
test(empty_is_rejected, [fail]) :-
    icl_from_reply("", _).
test(prose_is_rejected, [fail]) :-
    icl_from_reply("I would suggest calling the square agent", _).
test(malformed_icl_is_rejected, [fail]) :-
    icl_from_reply("square(7, ", _).

%   A bare atom is not a goal worth routing.
test(bare_atom_is_rejected, [fail]) :-
    icl_from_reply("square", _).

:- end_tests(llm_goal_extraction).
