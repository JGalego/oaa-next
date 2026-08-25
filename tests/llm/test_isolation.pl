/*  oaa-next -- the classic mode contains no LLM
 *
 *  The project's central claim about LLM support is negative: with the
 *  extension off, an installation has no LLM in it at all.  Not initialised
 *  and ignored -- absent.  These tests are what makes that claim checkable
 *  rather than aspirational.
 */

:- module(test_isolation, []).

:- use_module('../../src/runtime/oaa_config').
:- use_module('../../src/llm/llm_config').

core_dir('src/icl').
core_dir('src/runtime').
core_dir('src/agents').
core_dir('src/facilitator').
core_dir('src/adt').

repo_root(Root) :-
    source_file(repo_root(_), File),
    file_directory_name(File, D1),
    file_directory_name(D1, D2),
    file_directory_name(D2, Root).

core_file(Path) :-
    repo_root(Root),
    core_dir(Rel),
    atomic_list_concat([Root, '/', Rel, '/*.pl'], Pattern),
    expand_file_name(Pattern, Files),
    member(Path, Files).

:- begin_tests(llm_isolation).

%   No core module may mention the LLM extension, by import or by name.  A
%   single reference would make the classic mode a configuration rather than
%   a fact about what is installed.
test(core_does_not_reference_the_extension) :-
    findall(Path-Line,
            ( core_file(Path),
              read_file_to_string(Path, S, []),
              split_string(S, "\n", "", Lines),
              member(Line, Lines),
              offending(Line) ),
            Offenders),
    (   Offenders == []
    ->  true
    ;   format(user_error, "core references the LLM extension:~n~q~n",
               [Offenders]),
        fail
    ).

%   Prose may discuss the extension; code may not reach it.
offending(Line) :-
    \+ sub_string(Line, _, _, _, "%"),
    \+ sub_string(Line, _, _, _, "*"),
    ( sub_string(Line, _, _, _, "llm_") ; sub_string(Line, _, _, _, "src/llm") ).

%   No core module may import anything from src/llm.
test(core_imports_nothing_from_the_extension) :-
    findall(Path,
            ( core_file(Path),
              read_file_to_string(Path, S, []),
              sub_string(S, _, _, _, "use_module('../llm") ),
            Bad),
    Bad == [].

%   The default mode is classic; nothing has to be set to get it.
test(default_mode_is_classic, [setup(oaa_config_reset)]) :-
    ( getenv('OAA_MODE', _) -> unsetenv('OAA_MODE') ; true ),
    oaa_mode(M),
    M == 'OAA_CLASSIC'.

%   An unrecognised mode is refused rather than silently treated as classic.
test(unknown_mode_refused,
     [setup(( oaa_config_reset, setenv('OAA_MODE', 'OAA_MAGIC') )),
      cleanup(unsetenv('OAA_MODE')),
      throws(oaa_error(unsupported_mode(_)))]) :-
    oaa_mode(_).

%   The extension refuses to do anything in classic mode, with a reason.
test(extension_refuses_in_classic_mode,
     [setup(( oaa_config_reset,
              ( getenv('OAA_MODE', _) -> unsetenv('OAA_MODE') ; true ) )),
      throws(oaa_error(llm_disabled(_)))]) :-
    llm_require_enabled.

test(extension_permitted_when_enabled,
     [setup(( oaa_config_reset, setenv('OAA_MODE', 'OAA_LLM') )),
      cleanup(( unsetenv('OAA_MODE'), oaa_config_reset ))]) :-
    llm_require_enabled.

:- end_tests(llm_isolation).
