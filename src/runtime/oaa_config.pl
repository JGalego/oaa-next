/*  oaa-next -- invocation arguments, environment and the setup file
 *
 *  Provenance: RECONSTRUCTED.
 *  Developer's Guide v2.3.2 section 4.6.
 */

:- module(oaa_config,
          [ oaa_resolve/2,              % +Name, -Value
            oaa_resolve/3,              % +Name, -Value, +Default
            oaa_load_setup_file/1,      % +File
            oaa_setup_fact/1,           % ?Fact
            oaa_facilitator_address/1,  % -tcp(Host, Port)
            oaa_mode/1,                 % -Mode
            oaa_config_reset/0
          ]).

/** <module> Configuration

The Developer's Guide fixes both the sources of an invocation argument and the
order they are consulted:

    1. the command line
    2. environment variables
    3. the setup file

taken in that order, first value found wins.  Library code searches all three
whenever it resolves a variable, and developers adding their own arguments are
encouraged to follow the same convention, so the precedence carries beyond
the library's own arguments.

The setup file is Prolog syntax.  It is looked for, in order, at a path given
by -setup_file or SETUP_FILE, then setup.pl in the working directory, then
setup.pl in the user's home directory, then setup.pl in the root directory;
the first one found is used.

`default_facilitator(tcp(Host, Port))` is the preferred way to name a
facilitator in a setup file, because oaa_connect and oaa_listen in a file
shared between a facilitator and its clients confuse the two -- a client reads
it as where to connect, a facilitator as where to listen.

## Mode

Two modes exist: `OAA_CLASSIC`, the default, and `OAA_LLM`.

Nothing in the core consults the mode.  That is deliberate, and it is what
makes the classic mode mean something: with LLM support off there is no
provider to initialise, no credential to supply and no package to install,
because no part of the core knows an LLM exists.  The mode is read by the LLM
extension, which lives outside the core and refuses to start unless it is set.

Setting `OAA_LLM` therefore changes nothing on its own.  It permits an LLM
agent to run; it does not conjure one.
*/

:- dynamic setup_fact/1.
:- dynamic setup_loaded/1.

oaa_config_reset :-
    retractall(setup_fact(_)),
    retractall(setup_loaded(_)).

%!  oaa_resolve(+Name, -Value) is semidet.
%!  oaa_resolve(+Name, -Value, +Default) is det.
%
%   Resolve an invocation argument by the documented precedence.  Name is the
%   bare argument name: `oaa_connect` is looked for as -oaa_connect on the
%   command line, OAA_CONNECT in the environment, and oaa_connect/1 in the
%   setup file.

oaa_resolve(Name, Value) :-
    (   from_command_line(Name, V)
    ->  Value = V
    ;   from_environment(Name, V)
    ->  Value = V
    ;   from_setup_file(Name, V)
    ->  Value = V
    ).

oaa_resolve(Name, Value, Default) :-
    (   oaa_resolve(Name, V)
    ->  Value = V
    ;   Value = Default
    ).

from_command_line(Name, Value) :-
    current_prolog_flag(argv, Argv),
    atom_concat('-', Name, Flag),
    append(_, [Flag, Raw|_], Argv),
    parse_value(Raw, Value).

from_environment(Name, Value) :-
    upcase_atom(Name, Var),
    getenv(Var, Raw),
    parse_value(Raw, Value).

from_setup_file(Name, Value) :-
    ensure_setup_loaded,
    Probe =.. [Name, Value],
    setup_fact(Probe).

%   Values arrive as text and may be an ICL term -- tcp('host', 3345) -- or a
%   bare atom or number.

parse_value(Raw, Value) :-
    atom_string(Raw, S),
    (   catch(term_string(T, S), _, fail),
        compound(T)
    ->  Value = T
    ;   atom_number(Raw, N)
    ->  Value = N
    ;   atom_string(Value, S)
    ).

% ---------------------------------------------------------------- setup file

ensure_setup_loaded :-
    (   setup_loaded(_)
    ->  true
    ;   (   setup_file_path(File)
        ->  oaa_load_setup_file(File)
        ;   assertz(setup_loaded(none))
        )
    ).

setup_file_path(File) :-
    (   from_command_line(setup_file, F) ; from_environment(setup_file, F) ),
    exists_file(F), !,
    File = F.
setup_file_path('setup.pl') :-
    exists_file('setup.pl'), !.
setup_file_path(File) :-
    getenv('HOME', Home),
    atomic_list_concat([Home, '/setup.pl'], File),
    exists_file(File), !.
setup_file_path('/setup.pl') :-
    exists_file('/setup.pl').

%!  oaa_load_setup_file(+File) is det.
%
%   Read a setup file.  Its contents are period-terminated Prolog facts; they
%   are stored rather than asserted as predicates, so that a setup file can
%   never redefine library code.

oaa_load_setup_file(File) :-
    retractall(setup_loaded(_)),
    assertz(setup_loaded(File)),
    setup_call_cleanup(
        open(File, read, Stream),
        read_facts(Stream),
        close(Stream)).

read_facts(Stream) :-
    read_term(Stream, Term, []),
    (   Term == end_of_file
    ->  true
    ;   assertz(setup_fact(Term)),
        read_facts(Stream)
    ).

oaa_setup_fact(Fact) :-
    ensure_setup_loaded,
    setup_fact(Fact).

%!  oaa_facilitator_address(-Address) is semidet.
%
%   Where to find a facilitator.  oaa_connect wins over default_facilitator,
%   because the former is normally given on the command line for one agent
%   while the latter is normally in a setup file shared by several.

oaa_facilitator_address(Address) :-
    (   oaa_resolve(oaa_connect, A), A = tcp(_, _)
    ->  Address = A
    ;   ensure_setup_loaded,
        setup_fact(default_facilitator(A))
    ->  Address = A
    ).

%!  oaa_mode(-Mode) is det.
%
%   The operating mode: `'OAA_CLASSIC'` unless `OAA_MODE` says otherwise.
%   Read by the LLM extension; never by the core.

oaa_mode(Mode) :-
    oaa_resolve(oaa_mode, Raw, 'OAA_CLASSIC'),
    (   memberchk(Raw, ['OAA_CLASSIC', 'OAA_LLM'])
    ->  Mode = Raw
    ;   throw(oaa_error(unsupported_mode(Raw)))
    ).
