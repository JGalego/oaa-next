:- module(test_classic_api, []).

:- use_module('../../src/agents/oaa').
:- use_module('../../src/agents/oaa_agent').
:- use_module('../../src/runtime/com_tcp').
:- use_module('../../src/runtime/oaa_event').
:- use_module('../integration/community').
:- use_module(library(socket)).
:- use_module(library(filesex)).

:- dynamic callback_seen/1.

classic_callback(classic_echo(In, Out), _Params) :-
    Out = In,
    assertz(callback_seen(In)).

:- begin_tests(classic_api).

setup_state :-
    oaa_agent_reset,
    oaa_queue_clear,
    oaa_ClearCache,
    retractall(callback_seen(_)),
    oaa_unregister_callback(app_do_event).

historical_exports([
    icl_GetParamValue/2, icl_GetNestedParamValue/3, icl_GetPermValue/2,
    icl_BasicGoal/1, icl_GoalComponents/4, icl_ConsistentParams/2,
    icl_BuiltIn/1, icl_ConvertSolvables/2, oaa_LibraryVersion/1,
    oaa_Connect/4, oaa_SetupCommunication/1, oaa_Register/4,
    oaa_Disconnect/2, oaa_RegisterCallback/2, oaa_ResolveVariables/1, oaa_Ready/1,
    oaa_MainLoop/1, oaa_SetTimeout/1, oaa_GetEvent/4,
    oaa_ProcessEvent/2, oaa_Interpret/2, oaa_DelaySolution/1,
    oaa_ReturnDelayedSolutions/2, oaa_AddDelayedContextParams/3,
    oaa_PostEvent/2, oaa_CanSolve/2, oaa_Version/3, oaa_Ping/3,
    oaa_Declare/5, oaa_Undeclare/3, oaa_Redeclare/3, oaa_AddData/2,
    oaa_RemoveData/2, oaa_ReplaceData/3, oaa_LoadData/2,
    oaa_SaveData/2, oaa_CheckTriggers/3, oaa_AddTrigger/4,
    oaa_RemoveTrigger/4, oaa_Solve/1, oaa_Solve/2, oaa_InCache/2,
    oaa_AddToCache/2, oaa_ClearCache/0, oaa_TraceMsg/2,
    oaa_ComTraceMsg/3, oaa_Inform/3, oaa_Address/3,
    oaa_PrimaryAddress/1, oaa_Name/1, oaa_LastSeqNum/2,
    oaa_SupportsSequenceNumbers/1, oaa_SeqNumLessThan/2
]).

test(exports_every_historical_predicate) :-
    historical_exports(Required),
    module_property(oaa, exports(Actual)),
    forall(member(P, Required), memberchk(P, Actual)).

test(reports_historical_library_version) :-
    oaa_LibraryVersion([2,3,2]).

test(historical_icl_helpers) :-
    icl_GetParamValue(priority(P), [blocking, priority(7)]),
    P == 7,
    icl_GoalComponents(::(:(parent, ping(X)), [reply(none)]),
                       parent, ping(X), [reply(none)]),
    icl_ConvertSolvables(ping(_), [solvable(ping(_), [], [])]).

test(wire_uses_event_envelope) :-
    com_tcp:wire_encode(ev_solve(g1, ping(_), []), Wire),
    Wire = event(ev_solve(g1, ping(_), []), []).

test(event_envelope_decodes_for_runtime) :-
    com_tcp:wire_decode(event(ev_ready(agent), [sequence(3)]), Decoded),
    Decoded == ev_ready(agent).

test(default_callback_solves_historical_solvable, [setup(setup_state)]) :-
    oaa_agent:assertz(my_solvable(solvable(classic_echo(_,_), [], []))),
    oaa_RegisterCallback(app_do_event, test_classic_api:classic_callback),
    oaa_agent:oaa_solve_local(classic_echo(hello, Reply), []),
    Reply == hello,
    test_classic_api:callback_seen(hello).

test(cache_round_trip, [setup(setup_state)]) :-
    oaa_AddToCache(item(_), [item(a), item(b)]),
    oaa_InCache(item(X), Solutions),
    var(X),
    Solutions == [item(a), item(b)],
    oaa_ClearCache,
    \+ oaa_InCache(item(_), _).

test(data_save_and_load_round_trip, [setup(setup_state)]) :-
    oaa_agent:assertz(my_solvable(
        solvable(classic_item(_), [type(data)], [write(true)]))),
    oaa_AddData(classic_item(one), [address(self)]),
    tmp_file(oaa_classic_data, File),
    setup_call_cleanup(
        true,
        ( oaa_SaveData(classic_item(_),
                       [address(self), filename(File)]),
          oaa_RemoveData(classic_item(_),
                         [address(self), do_all(true)]),
          \+ oaa_data:oaa_data_query(classic_item(_)),
          oaa_LoadData(classic_item(_),
                       [address(self), filename(File)]),
          oaa_data:oaa_data_query(classic_item(one))
        ),
        delete_file(File)).

test(sequence_comparison_without_wrap) :-
    oaa_SeqNumLessThan(3, 4),
    \+ oaa_SeqNumLessThan(4, 3).

test(sequence_comparison_with_wrap) :-
    oaa_SeqNumLessThan(2147483646, 2).

test(version_232_does_not_negotiate_sequences, [fail]) :-
    oaa_SupportsSequenceNumbers(parent).

:- end_tests(classic_api).


:- begin_tests(classic_wire,
               [ setup((start_community([], Community),
                         nb_setval(classic_wire_community, Community))),
                 cleanup((nb_getval(classic_wire_community, Community),
                          stop_community(Community))) ]).

test(original_client_handshake_registers_and_solves) :-
    nb_getval(classic_wire_community, community(Dir, _)),
    directory_file_path(Dir, 'setup.pl', Setup),
    setup_call_cleanup(open(Setup, read, SetupIn),
                       read_term(SetupIn, default_facilitator(tcp(_, Port)), []),
                       close(SetupIn)),
    setup_call_cleanup(
        tcp_socket(Socket),
        ( tcp_connect(Socket, localhost:Port),
          tcp_open_socket(Socket, In, Out),
          set_stream(In, encoding(utf8)),
          set_stream(Out, encoding(utf8)),
          legacy_send(Out,
              event(ev_connect([other_name(legacy_client),
                                other_language(prolog),
                                other_dialect(sicstus),
                                other_type(client),
                                format(default),
                                other_version([2,3,2])]), [])),
          read_term(In, event(ev_connected(Info), []), []),
          memberchk(oaa_address(Address), Info),
          legacy_send(Out,
              event(ev_register_solvables(add,
                      [solvable(classic_ping(_), [], [])],
                      legacy_client, []), [])),
          legacy_send(Out, event(ev_ready(legacy_client), [])),
          legacy_send(Out,
              event(ev_solve(classic_goal,
                             agent_data(Address, client, ready, _,
                                        legacy_client, _),
                             [address(parent)]), [])),
          read_term(In, Reply, []),
          Reply = event(ev_solved(classic_goal, [_], [_], _, _, Solutions), []),
          Solutions = [agent_data(Address, client, ready, _, legacy_client, _)],
          close(In), close(Out)
        ),
        catch(tcp_close_socket(Socket), _, true)).

test(historical_prolog_api_runs_unchanged) :-
    nb_getval(classic_wire_community, Community),
    run_program(Community, '/tests/compatibility/classic_client.pl', Lines),
    member(Line, Lines),
    sub_string(Line, 0, _, _, "classic API registered: addr(").

legacy_send(Out, Term) :-
    write_term(Out, Term, [quoted(true), fullstop(true), nl(true)]),
    flush_output(Out).

:- end_tests(classic_wire).
