/*  oaa-next -- configuration tests  */

:- module(test_config, []).

:- use_module('../../src/runtime/oaa_config').

setup_tmp(File) :-
    tmp_file_stream(text, File, S),
    format(S, "default_facilitator(tcp('acapulco.ai.sri.com', 3333)).~n", []),
    format(S, "oaa_name(my_agent).~n", []),
    format(S, "on_port_exception(next_highest(100)).~n", []),
    close(S).

:- begin_tests(oaa_config, [cleanup(oaa_config_reset)]).

%  Developer's Guide 4.6: the setup file is Prolog syntax, and
%  default_facilitator is the preferred way to name a facilitator in one.
test(reads_setup_file,
     [setup(( oaa_config_reset, setup_tmp(F) )), cleanup(delete_file(F))]) :-
    oaa_load_setup_file(F),
    oaa_setup_fact(default_facilitator(tcp(Host, Port))),
    Host == 'acapulco.ai.sri.com',
    Port == 3333.

test(facilitator_address_from_setup,
     [setup(( oaa_config_reset, setup_tmp(F) )), cleanup(delete_file(F))]) :-
    oaa_load_setup_file(F),
    oaa_facilitator_address(tcp(Host, Port)),
    Host == 'acapulco.ai.sri.com', Port == 3333.

test(resolves_named_argument,
     [setup(( oaa_config_reset, setup_tmp(F) )), cleanup(delete_file(F))]) :-
    oaa_load_setup_file(F),
    oaa_resolve(oaa_name, Name),
    Name == my_agent.

test(default_when_absent, [setup(oaa_config_reset)]) :-
    oaa_resolve(no_such_argument, V, fallback),
    V == fallback.

%  The environment is consulted before the setup file, and after the command
%  line.  Developer's Guide 4.6: command line, then environment, then setup
%  file, first value found wins.
test(environment_beats_setup_file,
     [setup(( oaa_config_reset, setup_tmp(F), setenv('OAA_NAME', from_env) )),
      cleanup(( delete_file(F), unsetenv('OAA_NAME') ))]) :-
    oaa_load_setup_file(F),
    oaa_resolve(oaa_name, Name),
    Name == from_env.

test(setup_file_used_when_environment_absent,
     [setup(( oaa_config_reset, setup_tmp(F) )), cleanup(delete_file(F))]) :-
    ( getenv('OAA_NAME', _) -> unsetenv('OAA_NAME') ; true ),
    oaa_load_setup_file(F),
    oaa_resolve(oaa_name, Name),
    Name == my_agent.

%  Values may be compound ICL terms, atoms or numbers.
test(compound_value,
     [setup(( oaa_config_reset, setup_tmp(F) )), cleanup(delete_file(F))]) :-
    oaa_load_setup_file(F),
    oaa_resolve(on_port_exception, V),
    V == next_highest(100).

%  Phase 1 runs in OAA_CLASSIC and accepts no other mode.  Enabling an LLM
%  mode here would do nothing, because nothing in the core consults it.
test(mode_is_classic, [setup(oaa_config_reset)]) :-
    oaa_mode(M),
    M == 'OAA_CLASSIC'.

test(unknown_mode_rejected,
     [setup(( oaa_config_reset, setenv('OAA_MODE', 'OAA_LLM') )),
      cleanup(unsetenv('OAA_MODE')),
      throws(oaa_error(unsupported_mode(_)))]) :-
    oaa_mode(_).

:- end_tests(oaa_config).
