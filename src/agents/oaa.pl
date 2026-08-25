/*  oaa-next -- OAA 2.3.2 source compatibility facade
 *
 *  Provenance: RECONSTRUCTED.  This module deliberately preserves the public
 *  predicate names and arities exported by SRI's Prolog agent library.
 */

:- module(oaa,
          [ icl_GetParamValue/2,
            icl_GetNestedParamValue/3,
            icl_GetPermValue/2,
            icl_BasicGoal/1,
            icl_GoalComponents/4,
            icl_ConsistentParams/2,
            icl_BuiltIn/1,
            icl_ConvertSolvables/2,
            oaa_LibraryVersion/1,
            oaa_Connect/4,
            oaa_SetupCommunication/1,
            oaa_Register/4,
            oaa_Disconnect/2,
            oaa_RegisterCallback/2,
            oaa_ResolveVariables/1,
            oaa_Ready/1,
            oaa_MainLoop/1,
            oaa_SetTimeout/1,
            oaa_GetEvent/4,
            oaa_ProcessEvent/2,
            oaa_Interpret/2,
            oaa_DelaySolution/1,
            oaa_ReturnDelayedSolutions/2,
            oaa_AddDelayedContextParams/3,
            oaa_PostEvent/2,
            oaa_CanSolve/2,
            oaa_Version/3,
            oaa_Ping/3,
            oaa_Declare/5,
            oaa_Undeclare/3,
            oaa_Redeclare/3,
            oaa_AddData/2,
            oaa_RemoveData/2,
            oaa_ReplaceData/3,
            oaa_LoadData/2,
            oaa_SaveData/2,
            oaa_CheckTriggers/3,
            oaa_AddTrigger/4,
            oaa_RemoveTrigger/4,
            oaa_Solve/1,
            oaa_Solve/2,
            oaa_InCache/2,
            oaa_AddToCache/2,
            oaa_ClearCache/0,
            oaa_TraceMsg/2,
            oaa_ComTraceMsg/3,
            oaa_Inform/3,
            oaa_Address/3,
            oaa_PrimaryAddress/1,
            oaa_Name/1,
            oaa_LastSeqNum/2,
            oaa_SupportsSequenceNumbers/1,
            oaa_SeqNumLessThan/2
          ]).

:- use_module(oaa_agent).
:- use_module(oaa_solvable).
:- use_module(oaa_trigger).
:- use_module(oaa_data).
:- use_module('../icl/icl_params').
:- use_module('../icl/icl_term').
:- use_module('../runtime/com_tcp').
:- use_module('../runtime/oaa_event').
:- use_module('../runtime/oaa_config').

:- meta_predicate oaa_RegisterCallback(+, :). 

:- dynamic oaa_cache/2.
:- dynamic oaa_trace/1.
:- dynamic oaa_com_trace/1.
:- dynamic oaa_last_seen_seq_num/2.

oaa_trace(off).
oaa_com_trace(off).

% -------------------------------------------------------------------- ICL API

icl_GetParamValue(Pattern, Params) :-
    icl_get_param_value(Pattern, Params).

icl_GetNestedParamValue(Outer, Inner, Params) :-
    icl_get_param_value(Outer, Params),
    arg(1, Outer, Nested),
    icl_get_param_value(Inner, Nested).

icl_GetPermValue(Pattern, Perms) :-
    icl_get_param_value(Pattern, Perms).

icl_BasicGoal(Goal) :-
    nonvar(Goal),
    \+ Goal = (_:_),
    \+ (compound(Goal), functor(Goal, '::', 2)),
    \+ Goal = (_,_),
    \+ Goal = (_;_).

icl_GoalComponents(Full, Address, Goal, Params) :-
    icl_disassemble_goal(Full, Address, Goal, Params).

icl_ConsistentParams(A, B) :-
    icl_param_expand(A, EA),
    icl_param_expand(B, EB),
    \+ ( member(P, EA), member(Q, EB),
         functor(P, N, Arity), functor(Q, N, Arity),
         \+ P = Q ).

icl_BuiltIn(Goal) :-
    nonvar(Goal),
    functor(Goal, Name, Arity),
    current_predicate(oaa:Name/Arity).
icl_BuiltIn(Goal) :-
    nonvar(Goal),
    predicate_property(system:Goal, built_in).

icl_ConvertSolvables(Specs, Solvables) :-
    solvable_list(Specs, Solvables).

% --------------------------------------------------------------- lifecycle API

oaa_LibraryVersion([2,3,2]).

oaa_Connect(ConnectionId, Address, InitialName, Params) :-
    oaa_connect(ConnectionId, Address, InitialName, Params).

oaa_SetupCommunication(InitialName) :-
    oaa_facilitator_address(Address),
    (   oaa_resolve(use_password, true),
        oaa_resolve(client_password, Password)
    ->  Params = [password(Password)]
    ;   Params = []
    ),
    oaa_connect(parent, Address, InitialName, Params).

oaa_Register(ConnectionId, Name, Solvables, Params) :-
    (   oaa_agent:assigned_address(ConnectionId, _)
    ->  true
    ;   oaa_handshake(ConnectionId, Name, Params)
    ),
    oaa_register(ConnectionId, Name, Solvables, Params).

oaa_Disconnect(ConnectionId, Params) :-
    oaa_disconnect(ConnectionId, Params).

oaa_RegisterCallback(Id, Callback) :-
    oaa_register_callback(Id, Callback).

oaa_ResolveVariables(Alternatives) :-
    member(Alternative, Alternatives),
    maplist(resolve_compat_variable, Alternative),
    !.

resolve_compat_variable(cmd(Flag, Value)) :-
    current_prolog_flag(argv, Argv),
    append(_, [Flag, Raw|_], Argv),
    compat_value(Raw, Value).
resolve_compat_variable(env(Name, Value)) :-
    getenv(Name, Raw),
    compat_value(Raw, Value).
resolve_compat_variable(env_int(Name, Value)) :-
    getenv(Name, Raw),
    atom_number(Raw, Value).
resolve_compat_variable(setup(File, Name, Value)) :-
    (   var(File) -> true ; oaa_load_setup_file(File) ),
    oaa_setup_fact(Fact),
    Fact =.. [Name, Value].

compat_value(Raw, Value) :-
    (   atom(Raw) -> Atom = Raw ; atom_string(Atom, Raw) ),
    (   catch(atom_to_term(Atom, Parsed, []), _, fail)
    ->  Value = Parsed
    ;   Value = Atom
    ).

oaa_Ready(ShouldPrint) :-
    oaa_ready(ShouldPrint).

oaa_MainLoop(ShouldPrint) :-
    oaa_ready(ShouldPrint),
    oaa_main_loop([handler(oaa_agent:oaa_handle_event)]).

oaa_SetTimeout(Seconds) :-
    oaa_set_timeout(Seconds).

oaa_GetEvent(LowestPriority, PollUntil, Contents, Params) :-
    (   matching_queued_event(LowestPriority, PollUntil, ConnId, Contents)
    ->  Params = [connection_id(ConnId), from(ConnId)]
    ;   oaa_get_timeout(Timeout0),
        compat_poll_timeout(Timeout0, Timeout),
        oaa_pump(Timeout),
        (   matching_queued_event(LowestPriority, PollUntil, ConnId, Contents)
        ->  Params = [connection_id(ConnId), from(ConnId)]
        ;   Contents = timeout, Params = []
        )
    ).

compat_poll_timeout(0, 0) :- !.
compat_poll_timeout(T, T).

matching_queued_event(Lowest, PollUntil, ConnId, Contents) :-
    (   member(Pattern, PollUntil),
        oaa_dequeue(ConnId0, Candidate, Priority),
        ( Candidate = Pattern
        -> ConnId = ConnId0, Contents = Candidate
        ;  oaa_enqueue(ConnId0, Candidate, Priority), fail )
    ->  true
    ;   oaa_dequeue_above(Lowest, ConnId, Contents, _)
    ).

oaa_ProcessEvent(timeout, _Params) :- !,
    ( oaa_callback(app_idle, Callback) -> ignore(call(Callback)) ; true ).
oaa_ProcessEvent(Contents, Params) :-
    ( memberchk(connection_id(ConnId), Params) -> true ; ConnId = parent ),
    oaa_handle_event(ConnId, Contents).

oaa_Interpret(Goal, _) :- var(Goal), !, fail.
oaa_Interpret(true, _) :- !.
oaa_Interpret(fail, _) :- !, fail.
oaa_Interpret(false, _) :- !, fail.
oaa_Interpret((\+ P), Params) :- !, \+ oaa_Interpret(P, Params).
oaa_Interpret((P -> Q ; _), Params) :- oaa_Interpret(P, Params), !,
    oaa_Interpret(Q, Params).
oaa_Interpret((_ -> _ ; R), Params) :- !, oaa_Interpret(R, Params).
oaa_Interpret((P -> Q), Params) :- !, oaa_Interpret((P -> Q ; fail), Params).
oaa_Interpret((P,Q), Params) :- !, oaa_Interpret(P, Params), oaa_Interpret(Q, Params).
oaa_Interpret((P;Q), Params) :- !,
    ( oaa_Interpret(P, Params) ; oaa_Interpret(Q, Params) ).
oaa_Interpret(findall(V, G, L), Params) :- !,
    findall(V, oaa_Interpret(G, Params), L).
oaa_Interpret(Goal, _Params) :- icl_BuiltIn(Goal), !, call(Goal).
oaa_Interpret(Goal, Params) :-
    ( oaa_callback(app_do_event, Callback) -> call(Callback, Goal, Params) ; fail ).

oaa_PostEvent(Content, Params) :-
    (   memberchk(connection_id(ConnectionId), Params) -> true
    ;   ConnectionId = parent
    ),
    com_send(ConnectionId, event(Content, Params)).

% -------------------------------------------------------------- service API

oaa_Solve(Goal) :- oaa_solve(Goal).
oaa_Solve(Goal, Params) :- oaa_solve(Goal, Params).
oaa_CanSolve(Goal, Agent) :- oaa_solve(can_solve(Goal, Agent), [address(parent)]).

oaa_Version(self, prolog, Version) :- !, oaa_LibraryVersion(Version).
oaa_Version(Address, Language, Version) :-
    oaa_solve(agent_version(Address, Language, Version), [address(parent)]), !.
oaa_Version(_, prolog, 1.0).

oaa_Ping(Address, TimeLimit, ResponseTime) :-
    ground(Address), number(TimeLimit), TimeLimit >= 0,
    get_time(Before),
    oaa_solve(true, [address(Address), time_limit(TimeLimit)]),
    get_time(After),
    ResponseTime is After - Before.

% ----------------------------------------------------------- declarations API

oaa_Declare(Specs, CommonPerms, CommonParams, Params, Declared) :-
    solvable_list(Specs, Normalized),
    maplist(add_common(CommonPerms, CommonParams), Normalized, Declared),
    oaa_declare(Declared, Params).

add_common(CommonPerms, CommonParams,
           solvable(Goal, Params, Perms), solvable(Goal, AllParams, AllPerms)) :-
    append(Params, CommonParams, AllParams),
    append(Perms, CommonPerms, AllPerms).

oaa_Undeclare(Specs, Params, Undeclared) :-
    solvable_list(Specs, Undeclared),
    oaa_undeclare(Undeclared, Params).

oaa_Redeclare(Old, New, Params) :- oaa_redeclare(Old, New, Params).

% ------------------------------------------------------------------- data API

oaa_AddData(Clause, Params) :- oaa_add_data(Clause, Params).
oaa_RemoveData(Clause, Params) :- oaa_remove_data(Clause, Params).
oaa_ReplaceData(Old, New, Params) :- oaa_replace_data(Old, New, Params).

oaa_LoadData(Clause, Params) :- oaa_load_data(Clause, Params).
oaa_SaveData(Clause, Params) :- oaa_save_data(Clause, Params).

% ---------------------------------------------------------------- trigger API

oaa_CheckTriggers(Type, Condition, Params) :- oaa_check_triggers(Type, Condition, Params).
oaa_AddTrigger(Type, Condition, Action, Params) :- oaa_add_trigger(Type, Condition, Action, Params).
oaa_RemoveTrigger(Type, Condition, Action, Params) :- oaa_remove_trigger(Type, Condition, Action, Params).

% ------------------------------------------------------- delayed solution API

oaa_DelaySolution(Id) :- oaa_delay_solution(Id).
oaa_ReturnDelayedSolutions(Id, Solutions) :- oaa_return_delayed_solutions(Id, Solutions).
oaa_AddDelayedContextParams(Id, Params, NewParams) :-
    oaa_add_delayed_context_params(Id, Params, NewParams).

% --------------------------------------------------------------- cache/debug

oaa_InCache(Goal, Solutions) :-
    oaa_cache(CachedGoal, _), subsumes_term(CachedGoal, Goal), !,
    findall(Solution, oaa_cache(Goal, Solution), Solutions).

oaa_AddToCache(Goal, Solutions) :-
    forall(member(Solution, Solutions),
           ( oaa_cache(Goal, Solution) -> true ; assertz(oaa_cache(Goal, Solution)) )).

oaa_ClearCache :- retractall(oaa_cache(_, _)).

oaa_TraceMsg(Format, Args) :-
    ( oaa_trace(on) -> format(Format, Args) ; true ).

oaa_ComTraceMsg(Format, Args, Message) :-
    (   oaa_com_trace(on)
    ->  format(Format, Args),
        ( var(Message) -> true ; icl_write(Message), nl )
    ;   true
    ).

oaa_Inform(Type, Format, Args) :-
    oaa_TraceMsg(Format, Args),
    format(string(Message), Format, Args),
    ignore(oaa_solve(inform(Type, Message), [strategy(inform)])).

% ------------------------------------------------------------- identity/seq

oaa_Address(ConnectionId, Type, Address) :- oaa_address(ConnectionId, Type, Address).
oaa_PrimaryAddress(Address) :- oaa_primary_address(Address).
oaa_Name(Name) :- oaa_name(Name).

oaa_LastSeqNum(ConnectionId, SeqNum) :-
    (   var(SeqNum)
    ->  ( oaa_last_seen_seq_num(ConnectionId, SeqNum) -> true ; SeqNum = -1 )
    ;   retractall(oaa_last_seen_seq_num(ConnectionId, _)),
        assertz(oaa_last_seen_seq_num(ConnectionId, SeqNum))
    ).

% OAA library version [2,3,2] predates the negotiated sequence-number
% protocol ([2,3,3] internally), so a 2.3.2 peer correctly fails this query.
oaa_SupportsSequenceNumbers(_ConnectionId) :- fail.

oaa_SeqNumLessThan(A, B) :-
    (   A =< B
    ->  B - A =< 2147483647 // 3
    ;   A - B >= (2147483647 // 3) * 2
    ).
