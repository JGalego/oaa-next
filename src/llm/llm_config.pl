/*  oaa-next -- LLM extension: configuration and mode gate
 *
 *  Provenance: NEW / LLM EXTENSION.
 *  No part of the historical OAA corresponds to this.
 */

:- module(llm_config,
          [ llm_enabled/0,
            llm_require_enabled/0,
            llm_provider_name/1,        % -Name
            llm_model/1,                % -Model
            llm_setting/2,              % +Key, -Value
            llm_setting/3               % +Key, -Value, +Default
          ]).

:- use_module('../runtime/oaa_config').

/** <module> Whether the LLM extension may run at all

The extension is off by default and refuses to start unless it is switched on
deliberately:

    OAA_MODE=OAA_LLM

or `oaa_mode('OAA_LLM').` in a setup file.

The gate lives here rather than in the core because the core does not know an
LLM exists.  That is the whole substance of the classic mode: with the
extension off, there is no provider to initialise, no credential to supply and
no network call to make, because nothing that could make one has been loaded.
An installation can run indefinitely that way.

`llm_require_enabled/0` throws rather than failing quietly.  An agent that
needs the extension should refuse to start with a clear reason instead of
registering and then answering nothing.
*/

%!  llm_enabled is semidet.

llm_enabled :-
    oaa_mode('OAA_LLM').

%!  llm_require_enabled is det.

llm_require_enabled :-
    (   llm_enabled
    ->  true
    ;   throw(oaa_error(llm_disabled(
              'set OAA_MODE=OAA_LLM to enable the LLM extension')))
    ).

%!  llm_provider_name(-Name) is det.
%
%   Which provider adapter to use.  Defaults to `scripted`, which answers from
%   a local script and reaches no network -- so a misconfigured deployment
%   fails visibly rather than by calling out unexpectedly.

llm_provider_name(Name) :-
    llm_setting(llm_provider, Name, scripted).

%!  llm_model(-Model) is det.

llm_model(Model) :-
    llm_provider_name(Provider),
    default_model(Provider, Default),
    llm_setting(llm_model, Model, Default).

default_model(anthropic, 'claude-opus-5').
default_model(openai, 'gpt-4o-mini').
default_model(scripted, scripted).

%!  llm_setting(+Key, -Value) is semidet.
%!  llm_setting(+Key, -Value, +Default) is det.
%
%   Settings follow the same precedence as every other OAA invocation
%   argument: command line, then environment, then setup file.

llm_setting(Key, Value) :-
    oaa_resolve(Key, Value).

llm_setting(Key, Value, Default) :-
    oaa_resolve(Key, Value, Default).
