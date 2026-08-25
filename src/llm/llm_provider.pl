/*  oaa-next -- LLM extension: the provider interface
 *
 *  Provenance: NEW / LLM EXTENSION.
 */

:- module(llm_provider,
          [ llm_complete/3,             % +Messages, +Options, -Response
            llm_complete/4,             % +Provider, +Messages, +Options, -Response
            llm_register_provider/2,    % +Name, +Module
            llm_known_provider/2,       % ?Name, ?Module
            llm_response_text/2         % +Response, -Text
          ]).

:- use_module(llm_config).

/** <module> A provider-independent interface

Everything above this module speaks in messages and completions.  Which
service answers, and over what protocol, is an adapter's business.

An adapter is a module exporting

    complete(+Messages, +Options, -Response)

where Messages is a list of `message(Role, Text)` with Role one of `system`,
`user` or `assistant`, and Response is

    response(Text, Meta)

with Meta a parameter list carrying whatever the provider reported -- token
counts, stop reason, model.

Keeping the interface this narrow is the point.  The OAA layer must not
acquire a dependency on any particular vendor, and an adapter must be
replaceable without anything above it noticing.
*/

:- dynamic provider_module/2.

%!  llm_register_provider(+Name, +Module) is det.

llm_register_provider(Name, Module) :-
    retractall(provider_module(Name, _)),
    assertz(provider_module(Name, Module)).

llm_known_provider(Name, Module) :-
    provider_module(Name, Module).

%!  llm_complete(+Messages, +Options, -Response) is semidet.
%
%   Complete using the configured provider.  Refuses to run unless the
%   extension is enabled, so a stray call in classic mode is an error with a
%   reason rather than an unexplained network attempt.

llm_complete(Messages, Options, Response) :-
    llm_require_enabled,
    llm_provider_name(Name),
    llm_complete(Name, Messages, Options, Response).

%!  llm_complete(+Provider, +Messages, +Options, -Response) is semidet.

llm_complete(Name, Messages, Options, Response) :-
    llm_require_enabled,
    (   provider_module(Name, Module)
    ->  true
    ;   throw(oaa_error(unknown_llm_provider(Name)))
    ),
    Module:complete(Messages, Options, Response).

%!  llm_response_text(+Response, -Text) is det.

llm_response_text(response(Text, _Meta), Text).
