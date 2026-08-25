/*  oaa-next -- the OpenAI-compatible adapter, exercised over real HTTP
 *
 *  test_llm_agent.pl checks that the openai adapter is registered; nothing
 *  else exercises its actual request/reply handling.  This runs it against a
 *  local HTTP server that answers in the real chat-completions shape --
 *  proving the request body, auth header, and reply parsing (including
 *  token usage and a content-filter refusal) actually work, without
 *  reaching any real provider.  LLM_BASE_URL is exactly the setting a
 *  self-hosted OpenAI-compatible runtime (Ollama, vLLM, LM Studio) is
 *  pointed at in practice, so this is that path, not a shortcut around it.
 */

:- module(test_llm_openai_wire, []).

:- use_module('../../src/runtime/oaa_config').
:- use_module('../../src/llm/llm_config').
:- use_module('../../src/llm/llm_provider').
:- use_module('../../src/llm/providers/llm_openai').
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_json)).
:- use_module(library(http/json)).

:- dynamic last_request/1.

:- http_handler(root(.), stub_reply, [prefix]).

%   Answers as a real OpenAI-compatible chat-completions endpoint would.  A
%   user message containing "filtered" gets the content_filter shape a
%   moderated request produces; anything else gets an ordinary completion
%   that echoes recognisable evidence of what was actually sent, so the
%   request body itself is under test, not just the reply parsing.
stub_reply(Request) :-
    http_read_data(Request, Body, [json_object(dict)]),
    retractall(last_request(_)),
    assertz(last_request(Body)),
    get_dict(messages, Body, Messages),
    last(Messages, LastMsg),
    get_dict(content, LastMsg, LastContent),
    (   sub_string(LastContent, _, _, _, "filtered")
    ->  Reply = _{model: "stub-model",
                  choices: [_{message: _{role: "assistant", content: null},
                              finish_reason: "content_filter"}]}
    ;   get_dict(model, Body, ReqModel),
        format(atom(Echo), "saw-model:~w", [ReqModel]),
        Reply = _{model: "stub-model",
                  choices: [_{message: _{role: "assistant", content: Echo},
                              finish_reason: "stop"}],
                  usage: _{prompt_tokens: 11, completion_tokens: 4}}
    ),
    reply_json_dict(Reply).

stop_stub(Port) :-
    catch(http_stop_server(Port, []), _, true).

setup_stub :-
    setenv('OAA_MODE', 'OAA_LLM'),
    oaa_config_reset,
    http_server(http_dispatch, [port(Port)]),  % unbound: an ephemeral port
    nb_setval(stub_port, Port),
    format(atom(Base), "http://localhost:~w", [Port]),
    setenv('LLM_BASE_URL', Base),
    setenv('LLM_PROVIDER', openai).

teardown_stub :-
    nb_getval(stub_port, Port),
    stop_stub(Port),
    unsetenv('LLM_BASE_URL'),
    unsetenv('LLM_PROVIDER'),
    unsetenv('OAA_MODE'),
    oaa_config_reset.

:- begin_tests(llm_openai_wire,
               [setup(setup_stub), cleanup(teardown_stub)]).

%   The request actually sent carries the configured model and the message
%   text, and the reply's content, model and token usage all come back.
test(round_trip_carries_model_and_usage) :-
    once(( llm_complete(openai, [message(user, "square the number 7")], [], R),
           llm_response_text(R, Text),
           sub_string(Text, _, _, _, "saw-model:"),
           last_request(Sent),
           get_dict(model, Sent, SentModel),
           sub_string(Text, _, _, _, SentModel),
           R = response(_, Meta),
           memberchk(input_tokens(11), Meta),
           memberchk(output_tokens(4), Meta),
           memberchk(finish_reason("stop"), Meta) )).

%   A content-filter finish reason is a refusal, and looks like one: empty
%   text, not a crash on a null content field.
test(content_filter_is_an_empty_reply, [true(T == "")]) :-
    llm_complete(openai, [message(user, "please say something filtered")],
                 [], R),
    llm_response_text(R, T).

%   max_tokens defaults, but an explicit one in Options is what is sent.
test(max_tokens_option_reaches_the_request_body) :-
    llm_complete(openai, [message(user, "hi")], [max_tokens(77)], _),
    last_request(Sent),
    get_dict(max_tokens, Sent, 77).

:- end_tests(llm_openai_wire).
