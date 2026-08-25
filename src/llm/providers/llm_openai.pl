/*  oaa-next -- LLM extension: an OpenAI-compatible adapter
 *
 *  Provenance: NEW / LLM EXTENSION.
 */

:- module(llm_openai,
          [ ]).      % complete/3 is reached module-qualified; see llm_scripted

:- use_module(library(http/http_open)).
:- use_module(library(http/json)).
:- use_module('../llm_provider').
:- use_module('../llm_config').

/** <module> An OpenAI-compatible chat-completions adapter

Written against the chat-completions shape that several services and most
local runtimes accept, so the base URL is configurable: the same adapter
reaches a hosted service or a model running on the same machine.

Its presence is the point of the provider interface.  The OAA layer must not
acquire a dependency on any one vendor, and the way to keep that honest is to
have more than one adapter from the start.
*/

complete(Messages, Options, response(Text, Meta)) :-
    base_url(Base),
    atom_concat(Base, '/chat/completions', URL),
    llm_model(Model),
    maplist(turn_dict, Messages, Turns),
    ( memberchk(max_tokens(Max), Options) -> true ; Max = 4096 ),
    Body = _{model: Model, max_tokens: Max, messages: Turns},
    atom_json_dict(BodyAtom, Body, [as(atom)]),
    auth_headers(Headers),
    append([ method(post),
             request_header('content-type'='application/json'),
             post(atom('application/json', BodyAtom)),
             status_code(Status),
             timeout(120) ],
           Headers, OpenOptions),
    setup_call_cleanup(
        http_open(URL, Stream, OpenOptions),
        read_reply(Status, Stream, Text, Meta),
        close(Stream)).

base_url(Base) :-
    llm_setting(llm_base_url, Base, 'https://api.openai.com/v1').

%   A local runtime often needs no key at all, so a missing one is not an
%   error here as it is for a hosted service.

auth_headers(Headers) :-
    (   getenv('OPENAI_API_KEY', Key)
    ->  atom_concat('Bearer ', Key, Auth),
        Headers = [request_header('authorization'=Auth)]
    ;   Headers = []
    ).

turn_dict(message(Role, Text), _{role: RoleStr, content: Content}) :-
    atom_string(Role, RoleStr),
    text_to_string(Text, Content).

read_reply(200, Stream, Text, Meta) :- !,
    json_read_dict(Stream, Reply),
    (   get_dict(choices, Reply, [Choice|_]),
        get_dict(message, Choice, Msg),
        get_dict(content, Msg, Content)
    ->  Text = Content
    ;   Text = ""
    ),
    ( get_dict(model, Reply, M) -> true ; M = unknown ),
    Meta = [provider(openai), model(M)].
read_reply(Status, Stream, _, _) :-
    read_string(Stream, _, Body),
    throw(oaa_error(openai_http_error(Status, Body))).

:- llm_register_provider(openai, llm_openai).
