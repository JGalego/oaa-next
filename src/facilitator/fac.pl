/*  oaa-next -- the Facilitator
 *
 *  Provenance: RECONSTRUCTED.
 *  Developer's Guide v2.3.2 sections 3.2, 3.4, 5.6, 6 and 7;
 *  research/implementation-notes/facilitator.md.
 */

:- module(fac,
          [ fac_start/1,                % +Options
            fac_stop/0,
            fac_main/0,
            fac_registry/1,             % -Registry
            fac_address/1               % -Address
          ]).

:- use_module('../icl/icl_term').
:- use_module('../icl/icl_params').
:- use_module('../icl/icl_type').
:- use_module('../runtime/com_tcp').
:- use_module('../runtime/oaa_event').
:- use_module('../agents/oaa_solvable').
:- use_module('../agents/oaa_agent').
:- use_module('../agents/oaa_data').
:- use_module(fac_delegate).

/** <module> The Facilitator agent

**The Facilitator is an ordinary OAA agent.**  It uses the same agent library
as every client, declares solvables like any agent, and answers requests
through the same callback path.  This module makes that literal: its
capabilities are registered with oaa_agent and answered through
oaa_solve_local/2, not through a private mechanism.

Two consequences, both architecture rather than accident:

  * A Facilitator can be a client of another Facilitator -- pointing one at a
    parent is the whole of what makes a hierarchy, with no separate
    federation protocol.
  * Capability discovery is not a privileged API.  The registry is the data
    solvable `agent_data/6`, and asking who can solve a goal is asking the
    facilitator's `can_solve/2` solvable, through ordinary oaa_Solve.
*/

:- dynamic agent_entry/6.       % ConnId, LocalId, Name, Status, Solvables, Info
:- dynamic outstanding/1.       % request(...)
:- dynamic local_id_counter/1.
:- dynamic fac_listen_address/1.
:- dynamic fac_option/1.

local_id_counter(0).

%   The Facilitator's own capabilities.  Developer's Guide, and observed in
%   the historical fac.pl as its initial_solvables list.

initial_solvables([
    solvable(agent_data(_Id, _Type, _Status, _Solvables, _Name, _Info),
             [type(data)], [write(true)]),
    solvable(agent_host(_HId, _HName, _Host), [type(data)], [write(true)]),
    solvable(agent_location(_LId, _LName, _LHost, _LPort),
             [type(data)], [write(true)]),
    solvable(facilitator_data(_FAddr, _FStep, _FStatus, _FName, _FInfo),
             [type(data), bookkeeping(true)], [write(true)]),
    solvable(icl_type(_Sub, _Super), [type(data)], [write(true)]),
    solvable(data(_Item, _Data), [type(data)], [write(true)]),
    solvable(can_solve(_Goal, _AgentAddr), [callback(fac:handle_can_solve)], []),
    solvable(agent_version(_VId, _Lang, _Version),
             [callback(fac:handle_agent_version)], [])
]).

% ------------------------------------------------------------------- startup

%!  fac_start(+Options) is det.
%
%   Start listening and enter the event loop.  Options:
%
%     * address(tcp(Host, Port)) -- where to listen.  An unbound or zero port
%       asks the operating system for one, which the Developer's Guide allows
%       for a facilitator address.
%     * name(Name)               -- symbolic name; 'root' internally, as in
%       the historical facilitator, which is right for a single-facilitator
%       system and for the top of a hierarchy.
%     * once(true)               -- make one turn of the loop and return.
%     * write_setup_file(File)   -- record the listening address so client
%       agents can find it.

fac_start(Options) :-
    forall(member(O, Options), assertz(fac_option(O))),
    (   memberchk(address(Addr), Options)
    ->  ListenParams = [address(Addr)]
    ;   ListenParams = [address(tcp(localhost, _))]
    ),
    com_listen_at(fac_listener, ListenParams, Address),
    retractall(fac_listen_address(_)),
    assertz(fac_listen_address(Address)),
    (   memberchk(name(Name), Options) -> true ; Name = root ),
    declare_own_solvables(Name),
    seed_type_hierarchy,
    (   memberchk(write_setup_file(File), Options)
    ->  write_setup_file(File, Address)
    ;   true
    ),
    oaa_register_callback(on_connect, fac:on_connect),
    oaa_register_callback(on_disconnect, fac:on_disconnect),
    (   memberchk(once(true), Options)
    ->  oaa_main_loop([handler(fac:handle), once(true)])
    ;   oaa_main_loop([handler(fac:handle)])
    ).

%   The facilitator registers its capabilities through the agent library, the
%   same way a client would.  There is no facilitator-specific registry code.

%   Declaring without a parent to tell.  A root facilitator has no parent; a
%   node facilitator would additionally call oaa_register against its own
%   parent connection, which is all that distinguishes the two.

declare_own_solvables(Name) :-
    initial_solvables(Solvables),
    oaa_agent_reset,
    solvable_list(Solvables, Normalized),
    oaa_agent:retractall(my_name(_)),
    oaa_agent:assertz(my_name(Name)),
    oaa_agent:retractall(my_solvable(_)),
    forall(member(S, Normalized), oaa_agent:assertz(my_solvable(S))).

%   The ICL type hierarchy is exposed as a writable data solvable, so its
%   built-in edges are visible to agents as ordinary facts and can be added to
%   at runtime.

seed_type_hierarchy :-
    icl_type_edges(Edges),
    forall(member(Sub-Super, Edges),
           oaa_data_add(facilitator, icl_type(Sub, Super), [], _)).

write_setup_file(File, addr(tcp(Host, Port))) :-
    setup_call_cleanup(
        open(File, write, Stream),
        format(Stream, "default_facilitator(tcp(~q, ~w)).~n", [Host, Port]),
        close(Stream)).

fac_address(Address) :-
    fac_listen_address(Address).

fac_stop :-
    oaa_stop_loop,
    com_close_all,
    retractall(agent_entry(_, _, _, _, _, _)),
    retractall(outstanding(_)),
    retractall(fac_option(_)).

%!  fac_main is det.
%
%   Entry point for running the Facilitator as a program.

fac_main :-
    current_prolog_flag(argv, Argv),
    argv_options(Argv, Options),
    fac_start(Options).

argv_options([], []).
argv_options(['-oaa_listen', Spec|T], [address(Addr)|R]) :- !,
    parse_address(Spec, Addr),
    argv_options(T, R).
argv_options(['-oaa_name', Name|T], [name(NameAtom)|R]) :- !,
    atom_string(NameAtom, Name),
    argv_options(T, R).
argv_options(['-write_setup_file', File|T], [write_setup_file(FileAtom)|R]) :- !,
    atom_string(FileAtom, File),
    argv_options(T, R).
argv_options([_|T], R) :-
    argv_options(T, R).

parse_address(Spec, Addr) :-
    (   icl_parse_term(Spec, Addr0),
        Addr0 = tcp(_, _)
    ->  Addr = Addr0
    ;   atom_number(Spec, Port)
    ->  Addr = tcp(localhost, Port)
    ;   Addr = tcp(localhost, _)
    ).

% -------------------------------------------------------- connection events

%!  on_connect(+ConnId) is det.
%
%   A client agent has connected.  It gets a registry entry and a local id at
%   once, with status `open`; it becomes `ready` when it registers its
%   solvables.  Both statuses are visible to lookup, because an agent is
%   addressable before it has declared anything.

on_connect(ConnId) :-
    next_local_id(LocalId),
    assertz(agent_entry(ConnId, LocalId, unnamed, open, [], [])),
    (   com_address(ConnId, addr(tcp(Host, _)))
    ->  oaa_data_add(facilitator, agent_host(LocalId, unnamed, Host), [], _)
    ;   true
    ).

on_disconnect(ConnId) :-
    (   retract(agent_entry(ConnId, LocalId, _Name, _St, _Sv, _Info))
    ->  %  An agent's facts go with it.  Developer's Guide 7.5.
        oaa_data_remove(facilitator, agent_data(LocalId,_,_,_,_,_), [do_all(true)], _),
        oaa_data_remove(facilitator, agent_host(LocalId,_,_), [do_all(true)], _),
        oaa_data_remove_owner(LocalId),
        cancel_outstanding_for(ConnId)
    ;   true
    ).

next_local_id(Id) :-
    retract(local_id_counter(N)),
    Id is N + 1,
    assertz(local_id_counter(Id)).

% -------------------------------------------------------------- dispatching

%!  handle(+ConnId, +Event) is det.
%
%   The Facilitator's external event protocol, as recorded in
%   research/implementation-notes/facilitator.md section 3.

handle(ConnId, ev_register_solvables(Name, Solvables, Params)) :- !,
    register_agent(ConnId, Name, Solvables, Params).
handle(ConnId, ev_solve(GoalId, Goal, Params)) :- !,
    begin_solve(ConnId, GoalId, Goal, Params).
handle(ConnId, ev_solved(FacGoalId, _Rq, _Sv, _G, _P, Solutions)) :- !,
    provider_replied(ConnId, FacGoalId, Solutions).
handle(ConnId, ev_post_declare(Mode, Solvables, Params)) :- !,
    post_declare(ConnId, Mode, Solvables, Params).
handle(ConnId, ev_update_data(GoalId, Mode, Payload, Params)) :- !,
    update_data(ConnId, GoalId, Mode, Payload, Params).
handle(ConnId, ev_data_applied(FacGoalId, Ok)) :- !,
    data_provider_replied(ConnId, FacGoalId, Ok).
handle(_ConnId, _Event).

%   Registration is data maintenance on agent_data/6, not a bespoke registry
%   operation.  Developer's Guide 5.1.6; facilitator.md section 2.

register_agent(ConnId, Name, SolvableSpecs, _Params) :-
    (   retract(agent_entry(ConnId, LocalId, _OldName, _St, _Sv, Info))
    ->  true
    ;   next_local_id(LocalId), Info = []
    ),
    normalize_incoming(SolvableSpecs, Solvables),
    assertz(agent_entry(ConnId, LocalId, Name, ready, Solvables, Info)),
    oaa_data_remove(facilitator, agent_data(LocalId,_,_,_,_,_), [do_all(true)], _),
    oaa_data_add(facilitator,
                 agent_data(LocalId, client, ready, Solvables, Name, Info),
                 [], _),
    com_address(ConnId, Address),
    com_send(ConnId, ev_registered(LocalId, Address)).

normalize_incoming(Specs, Solvables) :-
    (   catch(solvable_list(Specs, Solvables), _, fail)
    ->  true
    ;   Solvables = []
    ).

%   An agent may ask its facilitator to declare a data solvable *on the
%   facilitator*, by including address(parent) in the parameters.  The result
%   is a shared data predicate readable and writable by all of that
%   facilitator's clients -- which is how OAA supports a blackboard style of
%   communication.  Developer's Guide 5.2 and 7.7.

post_declare(_ConnId, Mode, Specs, Params) :-
    icl_get_param_value(address(A), Params),
    memberchk(A, [parent, facilitator]), !,
    declare_on_facilitator(Mode, Specs).
post_declare(ConnId, Mode, Specs, _Params) :-
    (   agent_entry(ConnId, LocalId, Name, Status, Current, Info)
    ->  normalize_incoming(Specs, Incoming),
        apply_declare(Mode, Current, Incoming, Updated),
        retract(agent_entry(ConnId, LocalId, Name, Status, Current, Info)),
        assertz(agent_entry(ConnId, LocalId, Name, Status, Updated, Info)),
        oaa_data_remove(facilitator, agent_data(LocalId,_,_,_,_,_), [do_all(true)], _),
        oaa_data_add(facilitator,
                     agent_data(LocalId, client, Status, Updated, Name, Info),
                     [], _)
    ;   true
    ).

declare_on_facilitator(Mode, Specs) :-
    normalize_incoming(Specs, Incoming),
    oaa_solvables(Current),
    apply_declare(Mode, Current, Incoming, Updated),
    oaa_agent:retractall(my_solvable(_)),
    forall(member(S, Updated), oaa_agent:assertz(my_solvable(S))).

apply_declare(add, Current, Incoming, Updated) :-
    append(Current, Incoming, Updated).
apply_declare(remove, Current, Incoming, Updated) :-
    exclude(matches_any(Incoming), Current, Updated).
apply_declare(replace, Current, [Old, New], Updated) :-
    exclude(matches_any([Old]), Current, Without),
    append(Without, [New], Updated).

matches_any(Incoming, solvable(G, _, _)) :-
    member(solvable(G2, _, _), Incoming),
    G =@= G2.

% -------------------------------------------------------------- solving

%!  fac_registry(-Registry) is det.
%
%   The community as fac_delegate sees it: the facilitator's own capabilities
%   first -- it is an agent and can answer requests -- then its clients.

fac_registry(Registry) :-
    oaa_solvables(Own),
    findall(agent(LocalId, Name, Solvables),
            agent_entry(_, LocalId, Name, ready, Solvables, _),
            Clients),
    Registry = [agent(0, facilitator, Own)|Clients].

begin_solve(ConnId, GoalId, Goal, Params) :-
    requester_id(ConnId, RequesterId),
    fac_registry(Registry),
    fac_select(Goal, Registry, Params, RequesterId, Candidates),
    restrict_to_address(Candidates, Params, RequesterId, Selected0),
    apply_prioritize_meta(Goal, Params, Registry, Selected0, Selected),
    (   Selected == []
    ->  finish_solve(ConnId, GoalId, Goal, Params, [], [], [])
    ;   fac_dispatch_plan(Selected, Params, Mode, Batch),
        start_request(ConnId, GoalId, Goal, Params, Mode, Selected, Batch)
    ).

requester_id(ConnId, Id) :-
    (   agent_entry(ConnId, Id, _, _, _, _) -> true ; Id = 0 ).

%   An explicit address parameter bypasses delegation: the Facilitator routes
%   only to the agents named, and does not consider anyone else.  Developer's
%   Guide 6.5.  Addresses are standardized on receipt -- the reserved terms
%   self, parent and facilitator resolve, and a name/1 is looked up.

restrict_to_address(Candidates, Params, RequesterId, Selected) :-
    (   icl_get_param_value(address(Spec), Params)
    ->  address_ids(Spec, RequesterId, Ids),
        include(candidate_in(Ids), Candidates, Selected)
    ;   Selected = Candidates
    ).

candidate_in(Ids, candidate(Id, _, _)) :-
    memberchk(Id, Ids).

address_ids(Spec, RequesterId, Ids) :-
    (   is_list(Spec)
    ->  Specs = Spec
    ;   Specs = [Spec]
    ),
    findall(Id,
            ( member(S, Specs), address_id(S, RequesterId, Id) ),
            Ids).

address_id(self, RequesterId, RequesterId) :- !.
address_id(parent, _, 0) :- !.
address_id(facilitator, _, 0) :- !.
address_id(name(Name), _, Id) :- !,
    agent_entry(_, Id, Name, _, _, _).
address_id(addr(_, Id), _, Id) :- !.
address_id(Id, _, Id) :-
    integer(Id).

%   A prioritize meta-agent may reorder the candidate list.  It is optional
%   and fallible: if none is registered, or none returns a usable ordering,
%   the Facilitator's own utility ordering stands.  Developer's Guide 5.6.
%
%   This is the seam an LLM attaches to.  Nothing below this point knows or
%   cares how the meta-agent reached its answer.

%   **Phase 1 status: the hook is located, not yet wired.**  Consulting a
%   meta-agent means the Facilitator making a request of a client and waiting
%   for the answer, which a single-threaded facilitator must do without
%   deadlocking against the very client it is asking.  That is deferred, and
%   recorded as deferred in research/compatibility-matrix.md rather than
%   faked.  Until then the Facilitator's own utility ordering always stands,
%   which is exactly the documented fallback when no meta-agent returns
%   anything usable.

apply_prioritize_meta(_Goal, _Params, _Registry, Selected, Selected).

start_request(ConnId, GoalId, Goal, Params, Mode, Selected, Batch) :-
    oaa_next_goal_id(FacGoalId),
    findall(Id, member(candidate(Id, _, _), Batch), Requestees),
    assertz(outstanding(request(FacGoalId, ConnId, GoalId, Goal, Params,
                                Mode, Selected, Batch, Requestees, [], []))),
    forall(member(C, Batch), send_request(FacGoalId, Goal, Params, C)),
    (   Batch == []
    ->  complete(FacGoalId)
    ;   true
    ).

send_request(FacGoalId, Goal, Params, candidate(Id, Solvable, _U)) :-
    (   Id =:= 0
    ->  solve_on_facilitator(FacGoalId, Goal, Params)
    ;   agent_entry(ConnId, Id, _, _, _, _),
        %  The event a provider receives is the result of unifying the goal
        %  with the solvable's template.  Developer's Guide 5.1.2.
        (   solvable_match(Goal, Solvable, Event)
        ->  true
        ;   Event = Goal
        ),
        com_send(ConnId, ev_solve(FacGoalId, Event, Params))
    ).

%   The facilitator answering its own solvables goes through exactly the same
%   local-solving path a client agent uses.

solve_on_facilitator(FacGoalId, Goal, Params) :-
    copy_term(Goal, Probe),
    findall(Probe, oaa_solve_local(Probe, Params), Solutions),
    provider_replied(fac_self, FacGoalId, Solutions).

provider_replied(ConnId, FacGoalId, Solutions) :-
    (   retract(outstanding(request(FacGoalId, RConn, GoalId, Goal, Params,
                                    Mode, Selected, Batch, Requestees,
                                    Acc, Solvers)))
    ->  append(Acc, Solutions, Acc1),
        (   Solutions == []
        ->  Solvers1 = Solvers
        ;   solver_id(ConnId, SolverId),
            append(Solvers, [SolverId], Solvers1)
        ),
        assertz(outstanding(request(FacGoalId, RConn, GoalId, Goal, Params,
                                     Mode, Selected, Batch, Requestees,
                                     Acc1, Solvers1))),
        note_reply(FacGoalId, ConnId),
        maybe_complete(FacGoalId)
    ;   true
    ).

solver_id(fac_self, 0) :- !.
solver_id(ConnId, Id) :-
    (   agent_entry(ConnId, Id, _, _, _, _) -> true ; Id = unknown ).

:- dynamic replied/2.           % FacGoalId, ConnId

note_reply(FacGoalId, ConnId) :-
    assertz(replied(FacGoalId, ConnId)).

%   In parallel mode the request completes when every provider in the batch
%   has replied.  In serial mode it completes when the solution limit is met
%   or the candidate list is exhausted -- which is what makes strategy(action)
%   try one agent, and on failure the next.

maybe_complete(FacGoalId) :-
    outstanding(request(FacGoalId, _, _, _, Params, Mode, Selected, Batch,
                        _, Acc, _)),
    length(Batch, Expected),
    findall(C, replied(FacGoalId, C), Replies),
    length(Replies, Got),
    (   Got < Expected
    ->  true
    ;   Mode == parallel
    ->  complete(FacGoalId)
    ;   solution_limit_met(Acc, Params)
    ->  complete(FacGoalId)
    ;   next_serial_provider(FacGoalId, Selected, Batch, Next)
    ->  advance_serial(FacGoalId, Next)
    ;   complete(FacGoalId)
    ).

solution_limit_met(Acc, Params) :-
    icl_get_param_value(solution_limit(N), Params),
    integer(N),
    length(Acc, Len),
    Len >= N.

next_serial_provider(_FacGoalId, Selected, Batch, Next) :-
    append(Batch, _, Selected),
    length(Batch, Done),
    nth0(Done, Selected, Next).

advance_serial(FacGoalId, Next) :-
    retract(outstanding(request(FacGoalId, RConn, GoalId, Goal, Params, Mode,
                                 Selected, Batch, Requestees, Acc, Solvers))),
    append(Batch, [Next], Batch1),
    Next = candidate(NextId, _, _),
    append(Requestees, [NextId], Requestees1),
    assertz(outstanding(request(FacGoalId, RConn, GoalId, Goal, Params, Mode,
                                 Selected, Batch1, Requestees1, Acc, Solvers))),
    send_request(FacGoalId, Goal, Params, Next).

complete(FacGoalId) :-
    (   retract(outstanding(request(FacGoalId, RConn, GoalId, Goal, Params,
                                     _Mode, _Sel, _Batch, Requestees,
                                     Acc, Solvers)))
    ->  retractall(replied(FacGoalId, _)),
        finish_solve(RConn, GoalId, Goal, Params, Requestees, Solvers, Acc)
    ;   true
    ).

finish_solve(ConnId, GoalId, Goal, Params, Requestees, Solvers, Solutions0) :-
    dedupe(Solutions0, Params, Solutions),
    (   icl_get_param_value(reply(none), Params)
    ->  true
    ;   reply_goal(Goal, Params, ReplyGoal),
        com_send(ConnId,
                 ev_solved(GoalId, Requestees, Solvers, ReplyGoal,
                           Params, Solutions))
    ).

%   unique_values(true) removes duplicate solutions returning from different
%   agents.  Developer's Guide 6.7.
dedupe(Solutions, Params, Unique) :-
    (   icl_get_param_value(unique_values(true), Params)
    ->  remove_variants(Solutions, Unique)
    ;   Unique = Solutions
    ).

remove_variants([], []).
remove_variants([H|T], [H|R]) :-
    exclude([X]>>(X =@= H), T, T1),
    remove_variants(T1, R).

%   From 2.3.2 the goal is not echoed in the reply; a variable stands in that
%   position unless return_goal_with_solutions asks for the old behaviour.
reply_goal(Goal, Params, ReplyGoal) :-
    (   icl_get_param_value(return_goal_with_solutions(true), Params)
    ->  ReplyGoal = Goal
    ;   true
    ).

cancel_outstanding_for(ConnId) :-
    forall(outstanding(request(FacGoalId, ConnId, _, _, _, _, _, _, _, _, _)),
           ( retractall(outstanding(request(FacGoalId,_,_,_,_,_,_,_,_,_,_))),
             retractall(replied(FacGoalId, _)) )).

% ---------------------------------------------------------------- data ops

%   Data maintenance is routed by the same unification-based selection as a
%   solve: treat the clause as a goal and pick every agent providing a
%   matching data solvable.  Developer's Guide 7.4.

update_data(ConnId, GoalId, Mode, Payload, Params) :-
    probe_of(Mode, Payload, Probe),
    requester_id(ConnId, RequesterId),
    fac_registry(Registry),
    fac_select(Probe, Registry, Params, RequesterId, Selected),
    findall(Id, member(candidate(Id, _, _), Selected), Requestees),
    forall(member(candidate(Id, _, _), Selected),
           route_data_op(Id, GoalId, Mode, Payload, Params, ConnId)),
    (   icl_get_param_value(reply(none), Params)
    ->  true
    ;   com_send(ConnId, ev_data_updated(GoalId, Requestees, Requestees))
    ).

probe_of(replace, replace(C1, _), C1) :- !.
probe_of(_, Clause, Clause).

route_data_op(0, _GoalId, Mode, Payload, Params, ConnId) :- !,
    requester_id(ConnId, Owner),
    icl_param_merge([from(Owner)], Params, P2),
    oaa_agent:apply_data_op_locally(Mode, Payload, P2, _).
route_data_op(Id, GoalId, Mode, Payload, Params, ConnId) :-
    requester_id(ConnId, Owner),
    icl_param_merge([from(Owner)], Params, P2),
    (   agent_entry(Target, Id, _, _, _, _)
    ->  com_send(Target, ev_update_data(GoalId, Mode, Payload, P2))
    ;   true
    ).

data_provider_replied(_ConnId, _FacGoalId, _Ok).

% ------------------------------------------------------- facilitator solvables

%!  handle_can_solve(+Goal, +Params) is nondet.
%
%   can_solve(Goal, AgentAddress): which agents can solve Goal.  This is the
%   documented way for an agent to find a peer -- ask the parent facilitator
%   for solutions to can_solve.  It is a procedure rather than a data
%   solvable, so it is computed against the registry at call time rather than
%   read from a cached index.

handle_can_solve(can_solve(Goal, AgentAddr), _Params) :-
    fac_registry(Registry),
    fac_candidates(Goal, Registry, Candidates),
    fac_order(Candidates, Ordered),
    member(candidate(Id, _, _), Ordered),
    AgentAddr = Id.

handle_agent_version(agent_version(Id, Language, Version), _Params) :-
    agent_entry(_, Id, _, _, _, Info),
    (   memberchk(language(Language), Info) -> true ; Language = unknown ),
    (   memberchk(version(Version), Info) -> true ; Version = unknown ).
