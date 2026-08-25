/*  oaa-next -- LLM extension: the scripted provider
 *
 *  Provenance: NEW / LLM EXTENSION.
 */

:- module(llm_scripted,
          [ scripted_reply/2,           % +Pattern, +Reply
            scripted_clear/0
          ]).

%   complete/3 is deliberately not exported.  Every adapter defines one, and
%   the registry reaches them module-qualified, so exporting would make two
%   adapters unloadable side by side -- which is exactly what a
%   provider-independent interface has to allow.

:- use_module('../llm_provider').

/** <module> A provider that answers from a local script

Reaches no network and needs no credential.  It exists so that the LLM
extension can be exercised deterministically: a test that depends on a live
model tests the model, not the code.

It is also the default provider, so a deployment that enables the extension
without configuring one fails visibly instead of calling out unexpectedly.
*/

:- dynamic reply_rule/2.

%!  scripted_reply(+Pattern, +Reply) is det.
%
%   Answer Reply whenever the last user message contains Pattern as a
%   substring.  Rules are tried in the order they were added.

scripted_reply(Pattern, Reply) :-
    assertz(reply_rule(Pattern, Reply)).

scripted_clear :-
    retractall(reply_rule(_, _)).

complete(Messages, _Options, response(Text, Meta)) :-
    last_user_text(Messages, Prompt),
    (   reply_rule(Pattern, Reply),
        sub_string(Prompt, _, _, _, Pattern)
    ->  Text = Reply
    ;   Text = ""
    ),
    Meta = [provider(scripted), stop_reason(end_turn)].

last_user_text(Messages, Text) :-
    findall(T, member(message(user, T), Messages), Texts),
    (   Texts == []
    ->  Text = ""
    ;   last(Texts, Last),
        text_to_string(Last, Text)
    ).

:- llm_register_provider(scripted, llm_scripted).
