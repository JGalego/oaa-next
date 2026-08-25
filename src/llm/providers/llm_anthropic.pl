/*  oaa-next -- LLM extension: the Anthropic adapter
 *
 *  Provenance: NEW / LLM EXTENSION.
 */

:- module(llm_anthropic,
          [ ]).      % complete/3 is reached module-qualified; see llm_scripted

:- use_module(library(http/http_open)).
:- use_module(library(http/http_json)).
:- use_module(library(http/json)).
:- use_module('../llm_provider').
:- use_module('../llm_config').

/** <module> Anthropic Messages API

Raw HTTP, because there is no official Anthropic SDK for Prolog.

Credentials come from `ANTHROPIC_API_KEY`.  Nothing here reads it until a
completion is actually requested, so an installation with the extension
enabled but never used still makes no demand for one.
*/

endpoint('https://api.anthropic.com/v1/messages').
api_version('2023-06-01').

complete(Messages, Options, response(Text, Meta)) :-
    api_key(Key),
    llm_model(Model),
    request_body(Model, Messages, Options, Body),
    endpoint(URL),
    api_version(Version),
    setup_call_cleanup(
        http_open(URL, Stream,
                  [ method(post),
                    request_header('x-api-key'=Key),
                    request_header('anthropic-version'=Version),
                                        post(json(Body)),
                    status_code(Status),
                    timeout(120)
                  ]),
        read_reply(Status, Stream, Text, Meta),
        close(Stream)).

api_key(Key) :-
    (   getenv('ANTHROPIC_API_KEY', Key)
    ->  true
    ;   throw(oaa_error(no_anthropic_api_key))
    ).

%   Adaptive thinking is the current default for anything non-trivial, and
%   budget_tokens is rejected outright by this model family.  max_tokens is
%   kept modest here because an agent's replies are short; a caller that needs
%   more passes it.

request_body(Model, Messages, Options, Body) :-
    partition_system(Messages, System, Turns),
    maplist(turn_dict, Turns, TurnDicts),
    ( memberchk(max_tokens(Max), Options) -> true ; Max = 4096 ),
    Base = _{ model: Model,
              max_tokens: Max,
              thinking: _{type: "adaptive"},
              messages: TurnDicts },
    (   System == ""
    ->  Body = Base
    ;   Body = Base.put(system, System)
    ).

%   A system prompt is a top-level field rather than a message.

partition_system(Messages, System, Turns) :-
    findall(T, member(message(system, T), Messages), Systems),
    exclude([message(system, _)]>>true, Messages, Turns),
    atomic_list_concat(Systems, '\n', SystemAtom),
    atom_string(SystemAtom, System).

turn_dict(message(Role, Text), _{role: RoleStr, content: Content}) :-
    atom_string(Role, RoleStr),
    text_to_string(Text, Content).

read_reply(200, Stream, Text, Meta) :- !,
    json_read_dict(Stream, Reply),
    reply_text(Reply, Text),
    reply_meta(Reply, Meta).
read_reply(Status, Stream, _, _) :-
    read_string(Stream, _, Body),
    throw(oaa_error(anthropic_http_error(Status, Body))).

%   A refusal comes back as a normal 200 with stop_reason "refusal", so the
%   stop reason has to be checked before the content is read.

reply_text(Reply, Text) :-
    (   get_dict(stop_reason, Reply, "refusal")
    ->  Text = ""
    ;   get_dict(content, Reply, Blocks)
    ->  findall(T,
                ( member(B, Blocks),
                  get_dict(type, B, "text"),
                  get_dict(text, B, T) ),
                Texts),
        atomic_list_concat(Texts, '', Atom),
        atom_string(Atom, Text)
    ;   Text = ""
    ).

reply_meta(Reply, Meta) :-
    ( get_dict(stop_reason, Reply, Stop) -> true ; Stop = unknown ),
    ( get_dict(model, Reply, Model) -> true ; Model = unknown ),
    (   get_dict(usage, Reply, Usage),
        get_dict(input_tokens, Usage, In),
        get_dict(output_tokens, Usage, Out)
    ->  Meta = [provider(anthropic), model(Model), stop_reason(Stop),
                input_tokens(In), output_tokens(Out)]
    ;   Meta = [provider(anthropic), model(Model), stop_reason(Stop)]
    ).

:- llm_register_provider(anthropic, llm_anthropic).
