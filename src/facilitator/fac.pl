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
            fac_address/1,              % -Address
            fac_is_node/0
          ]).

:- use_module('../icl/icl_term').
:- use_module('../icl/icl_params').
:- use_module('../icl/icl_type').
:- use_module('../runtime/com_tcp').
:- use_module('../runtime/oaa_event').
:- use_module('../agents/oaa_solvable').
:- use_module('../agents/oaa_agent').
:- use_module('../agents/oaa_data').
:- use_module('../agents/oaa_trigger').
:- use_module(fac_delegate).
:- use_module(fac_compound).

/** <module> The Facilitator agent

**The Facilitator is an ordinary OAA agent.**  It uses the same agent library
as every client, declares solvables like any agent, and answers requests
through the same callback path.  This module makes that literal: its
capabilities are registered with oaa_agent and answered through
oaa_solve_local/2, by the same route a client uses.

A Facilitator can therefore be a client of another Facilitator: pointing one
at a parent is all a hierarchy takes, with no separate federation protocol.
Capability discovery goes through the same door as everything else -- the
registry is the data solvable `agent_data/6`, and asking who can solve a goal
means asking the facilitator's `can_solve/2` solvable through ordinary
oaa_Solve.
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
    solvable(agent_listener(_AId2, _ListenAddress), [type(data)], [write(true)]),
    solvable(agent_listener(_AId, _AHost, _APort), [type(data)], [write(true)]),
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
    (   memberchk(connect(ParentAddr), Options)
    ->  connect_to_parent(Name, ParentAddr)
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
    retractall(comp(_, _, _, _, _, _)),
    retractall(comp_current(_, _)),
    retractall(meta_pending(_, _, _, _, _, _)),
    retractall(meta_pending_sel(_, _)),
    retractall(referred(_, _, _, _)),
    retractall(parent_facilitator(_)),
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
argv_options(['-oaa_connect', Spec|T], [connect(Addr)|R]) :- !,
    parse_address(Spec, Addr),
    argv_options(T, R).
argv_options(['-oaa_name', Name|T], [name(NameAtom)|R]) :- !,
    atom_string(NameAtom, Name),
    argv_options(T, R).
argv_options(['-use_password', Value|T], [use_password(Bool)|R]) :- !,
    atom_string(Bool, Value),
    argv_options(T, R).
argv_options(['-valid_passwords', Spec|T], [valid_passwords(Passwords)|R]) :- !,
    icl_parse_term(Spec, Passwords),
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

% ------------------------------------------------------- node facilitators
%
%   A facilitator arranged below another is started with oaa_connect pointed
%   at its parent, which makes it a *node* facilitator.  Nothing else
%   distinguishes it: the Developer's Guide describes a facilitator as just
%   another OAA agent using the same library and communication standards, and
%   a node facilitator as a "super" agent capable of solving every goal its
%   own clients can solve.
%
%   That description is also the implementation.  A node facilitator registers
%   upward with the union of its clients' solvables, so its parent selects it
%   by ordinary unification like any other provider, and hands it goals it can
%   satisfy through its own community.  There is no federation protocol, and
%   downward propagation needs no code at all -- a child facilitator is
%   already in its parent's registry.

:- dynamic parent_facilitator/1.        % Address

connect_to_parent(Name, ParentAddr) :-
    fac_address(MyAddress),
    oaa_connect(parent, ParentAddr, Name,
                [other_type(facilitator), other_address(MyAddress)]),
    retractall(parent_facilitator(_)),
    assertz(parent_facilitator(ParentAddr)),
    refresh_upward_registration(Name),
    oaa_ready(false).

fac_is_node :-
    parent_facilitator(_).

%!  refresh_upward_registration(+Name) is det.
%
%   Tell the parent what this community can solve.  Re-registering replaces
%   the previous declaration, so this is also how the parent learns that a
%   client has arrived or gone.

refresh_upward_registration(Name) :-
    (   parent_facilitator(_)
    ->  aggregate_solvables(Aggregate),
        com_send(parent, ev_register_solvables(add, Aggregate, Name,
                                                [if_exists(overwrite)]))
    ;   true
    ).

refresh_upward_registration :-
    (   oaa_name(Name) -> true ; Name = node ),
    refresh_upward_registration(Name).

%   The union of the clients' solvables.  The facilitator's own built-ins stay
%   out: agent_data and can_solve describe this community, and answering a
%   parent's question about them would be misleading.

aggregate_solvables(Aggregate) :-
    findall(S,
            ( agent_entry(Conn, _, _, ready, Solvables, _),
              Conn \== parent,
              member(S, Solvables) ),
            All),
    dedupe_solvables(All, Aggregate).

dedupe_solvables([], []).
dedupe_solvables([S|T], [S|R]) :-
    S = solvable(G, _, _),
    exclude([solvable(G2, _, _)]>>(G2 =@= G), T, T1),
    dedupe_solvables(T1, R).

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
    public_address(LocalId, AgentAddress),
    (   com_address(ConnId, addr(tcp(Host, _)))
    ->  oaa_data_add(facilitator, agent_host(AgentAddress, unnamed, Host), [], _)
    ;   true
    ).

on_disconnect(ConnId) :-
    (   retract(agent_entry(ConnId, LocalId, _Name, _St, _Sv, _Info))
    ->  %  An agent's facts go with it.  Developer's Guide 7.5.
        public_address(LocalId, AgentAddress),
        oaa_data_remove(facilitator, agent_data(AgentAddress,_,_,_,_,_), [do_all(true)], _),
        oaa_data_remove(facilitator, agent_host(AgentAddress,_,_), [do_all(true)], _),
        oaa_data_remove_owner(LocalId),
        cancel_outstanding_for(ConnId),
        refresh_upward_registration
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

handle(ConnId, Event) :-
    %  Offer every arriving event to the comm triggers before handling it.
    %  A monitoring agent installs one of those on the facilitator to watch
    %  the community's traffic.  Developer's Guide 4.3.5.
    oaa_note_event(receive, ConnId, Event),
    fail.
handle(ConnId, ev_connect(Info)) :- !,
    handshake_client(ConnId, Info).
handle(ConnId, ev_register_solvables(Mode, Solvables, Name, Params)) :- !,
    register_agent_historical(ConnId, Mode, Name, Solvables, Params).
handle(ConnId, ev_register_solvables(Name, Solvables, Params)) :- !,
    register_agent(ConnId, Name, Solvables, Params).
handle(ConnId, ev_ready(_Name)) :- !,
    mark_ready(ConnId).
handle(ConnId, ev_heartbeat) :- !,
    com_send(ConnId, ev_heartbeat_reply).
handle(_ConnId, ev_heartbeat_reply) :- !.
handle(ConnId, ev_solve(GoalId, Goal, Params)) :- !,
    begin_solve(ConnId, GoalId, Goal, Params).
handle(parent, ev_solved(UpId, Requestees, Solvers, _G, _P, Solutions)) :-
    referred(UpId, _, _, _), !,
    referred_answer(UpId, Requestees, Solvers, Solutions).
handle(_ConnId, ev_registered(_LocalId, _Address)) :- !.
handle(ConnId, ev_solved(FacGoalId, _Rq, _Sv, _G, _P, Solutions)) :- !,
    provider_replied(ConnId, FacGoalId, Solutions).
handle(ConnId, ev_post_declare(Mode, Solvables, Params)) :- !,
    post_declare(ConnId, Mode, Solvables, Params).
handle(ConnId, ev_update_data(GoalId, Mode, Payload, Params)) :- !,
    update_data(ConnId, GoalId, Mode, Payload, Params).
handle(ConnId, ev_update_trigger(GoalId, Mode, Type, Cond, Action, Params)) :- !,
    update_trigger(ConnId, GoalId, Mode, Type, Cond, Action, Params).
handle(ConnId, ev_data_applied(FacGoalId, Ok)) :- !,
    data_provider_replied(ConnId, FacGoalId, Ok).
handle(_ConnId, _Event).

%   OAA 2.3.2 starts every connection with ev_connect/1.  The response tells
%   the peer both who the facilitator is and which full OAA address has been
%   assigned to it.  The local integer remains an implementation detail used
%   by the reconstructed registry.

handshake_client(ConnId, Info) :-
    (   memberchk(other_name(Name), Info) -> true ; Name = unknown ),
    (   memberchk(other_type(Type), Info) -> true ; Type = client ),
    (   agent_entry(ConnId, LocalId, _, Status, Solvables, OldInfo)
    ->  true
    ;   next_local_id(LocalId), Status = open, Solvables = [], OldInfo = []
    ),
    (   handshake_rejection(Info, Rejection)
    ->  com_send(ConnId, ev_connected(exception(Rejection))),
        com_close(ConnId)
    ;   duplicate_name_rejected(Name, Info)
    ->  com_send(ConnId, ev_connected(exception(agent_name_in_use)))
    ;   replace_duplicate_name(Name, Info),
        retractall(agent_entry(ConnId, _, _, _, _, _)),
        assertz(agent_entry(ConnId, LocalId, Name, Status, Solvables, Info)),
        refresh_agent_data(LocalId, Type, Status, Solvables, Name, OldInfo),
        fac_address(FacAddress),
        FacAddress = addr(ProtocolAddress),
        ClientAddress = addr(ProtocolAddress, LocalId),
        oaa_name(FacName),
        Reply = [ other_address(FacAddress),
                  oaa_address(ClientAddress),
                  other_id(0),
                  other_type(facilitator),
                  other_name(FacName),
                  other_language(prolog),
                  other_version([2,3,2]),
                  other_dialect(swi),
                  format(default)
                ],
        com_send(ConnId, ev_connected(Reply))
    ).

duplicate_name_rejected(Name, Info) :-
    memberchk(unique_name(Policy), Info),
    memberchk(Policy, [true, keep_old]),
    agent_entry(_, _, Name, ready, _, _).

replace_duplicate_name(Name, Info) :-
    memberchk(unique_name(keep_new), Info), !,
    forall(agent_entry(OldConn, _, Name, _, _, _), com_close(OldConn)).
replace_duplicate_name(_, _).

handshake_rejection(Info, no_password) :-
    password_required,
    \+ memberchk(password(_), Info), !.
handshake_rejection(Info, variable_password) :-
    password_required,
    memberchk(password(Password), Info),
    var(Password), !.
handshake_rejection(Info, bad_password) :-
    password_required,
    memberchk(password(Password), Info),
    \+ valid_client_password(Password), !.

password_required :- fac_option(use_password(true)).

valid_client_password(Password) :-
    fac_option(valid_passwords(Passwords)),
    memberchk(Password, Passwords).

refresh_agent_data(LocalId, Type, Status, Solvables, Name, Info) :-
    public_address(LocalId, Address),
    oaa_data_remove(facilitator, agent_data(Address,_,_,_,_,_),
                    [do_all(true)], _),
    oaa_data_add(facilitator,
                 agent_data(Address, Type, Status, Solvables, Name, Info),
                 [], _).

public_address(0, Address) :- !,
    fac_address(Address).
public_address(Address, Address) :-
    compound(Address),
    functor(Address, addr, _), !.
public_address(LocalId, addr(ProtocolAddress, LocalId)) :-
    fac_address(addr(ProtocolAddress)).

public_addresses(Ids, Addresses) :-
    maplist(public_address, Ids, Addresses).

register_agent_historical(ConnId, Mode, Name, SolvableSpecs, Params) :-
    (   agent_entry(ConnId, LocalId, _OldName, Status, Current, Info)
    ->  true
    ;   next_local_id(LocalId), Status = open, Current = [], Info = []
    ),
    normalize_incoming(SolvableSpecs, Incoming),
    apply_declare(Mode, Current, Incoming, Updated),
    retractall(agent_entry(ConnId, _, _, _, _, _)),
    assertz(agent_entry(ConnId, LocalId, Name, Status, Updated, Info)),
    refresh_agent_data(LocalId, client, Status, Updated, Name, Info),
    record_listener(LocalId, Params),
    refresh_upward_registration.

mark_ready(ConnId) :-
    (   retract(agent_entry(ConnId, LocalId, Name, _Status, Solvables, Info))
    ->  assertz(agent_entry(ConnId, LocalId, Name, ready, Solvables, Info)),
        ( memberchk(other_type(Type), Info) -> true ; Type = client ),
        refresh_agent_data(LocalId, Type, ready, Solvables, Name, Info),
        refresh_upward_registration
    ;   true
    ).

%   Registration is data maintenance on agent_data/6.  Developer's Guide
%   5.1.6; facilitator.md section 2.

register_agent(ConnId, Name, SolvableSpecs, Params) :-
    (   retract(agent_entry(ConnId, LocalId, _OldName, _St, _Sv, Info))
    ->  true
    ;   next_local_id(LocalId), Info = []
    ),
    normalize_incoming(SolvableSpecs, Solvables),
    assertz(agent_entry(ConnId, LocalId, Name, ready, Solvables, Info)),
    refresh_agent_data(LocalId, client, ready, Solvables, Name, Info),
    record_listener(LocalId, Params),
    com_address(ConnId, Address),
    com_send(ConnId, ev_registered(LocalId, Address)),
    refresh_upward_registration.

%   A provider willing to take requests over a direct connection opens a
%   listener before registering, and reports it here.  The Facilitator keeps
%   the address for requesters that ask for direct_connect.  Developer's
%   Guide 10.1.

record_listener(LocalId, Params) :-
    oaa_data_remove(facilitator, agent_listener(LocalId, _, _),
                    [do_all(true)], _),
    public_address(LocalId, Address),
    oaa_data_remove(facilitator, agent_listener(Address, _),
                    [do_all(true)], _),
    (   icl_get_param_value(listener(tcp(Host, Port)), Params)
    ->  oaa_data_add(facilitator, agent_listener(LocalId, Host, Port), [], _),
        oaa_data_add(facilitator,
                     agent_listener(Address, addr(tcp(Host, Port))), [], _)
    ;   true
    ).

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

post_declare(ConnId, Mode, Specs, Params) :-
    icl_get_param_value(address(A), Params),
    memberchk(A, [parent, facilitator]), !,
    declare_on_facilitator(Mode, Specs),
    com_send(ConnId, ev_reply_declared(Mode, Specs, Params, Specs)).
post_declare(ConnId, Mode, Specs, Params) :-
    (   agent_entry(ConnId, LocalId, Name, Status, Current, Info)
    ->  normalize_incoming(Specs, Incoming),
        apply_declare(Mode, Current, Incoming, Updated),
        retract(agent_entry(ConnId, LocalId, Name, Status, Current, Info)),
        assertz(agent_entry(ConnId, LocalId, Name, Status, Updated, Info)),
        refresh_agent_data(LocalId, client, Status, Updated, Name, Info),
        refresh_upward_registration,
        com_send(ConnId, ev_reply_declared(Mode, Specs, Params, Incoming))
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

%   A request is answered to a ReplyTo, which is either the client that asked
%   or a compound goal execution waiting on one of its subgoals.  Routing
%   replies through one tag is what lets a subgoal be delegated by exactly the
%   same machinery as a top-level request.

begin_solve(ConnId, GoalId, Goal, Params) :-
    requester_id(ConnId, RequesterId),
    (   icl_get_param_value(test(Test), Params),
        \+ test_holds_here(Test)
    ->  %  Developer's Guide 6.9: a test parameter names a condition to
        %  evaluate on the facilitator receiving the request.  Only where it
        %  holds is the goal solved -- "send this to the interface agent, but
        %  only on a facilitator where the user's name is 'phil'".  Useful
        %  chiefly across several facilitators.
        finish_solve(ConnId, GoalId, Goal, Params, [], [], [])
    ;   begin_solve_here(ConnId, GoalId, Goal, Params, RequesterId)
    ).

%   The test is evaluated against this community, synchronously and against
%   what the facilitator can answer without delegating.  A test that needs a
%   round trip to a client would reintroduce the wait this design avoids
%   everywhere else, so it is deliberately limited to locally answerable
%   conditions: the facilitator's own solvables and its clients' declared
%   data, both of which it holds.

test_holds_here(Test) :-
    catch(once(oaa_solve_local(Test, [])), _, fail).

begin_solve_here(ConnId, GoalId, Goal, Params, RequesterId) :-
    (   is_compound_goal(Goal)
    ->  begin_compound(client(ConnId, GoalId), RequesterId, Goal, Params)
    ;   icl_disassemble_goal(Goal, Address, Bare, GoalParams),
        merge_goal_params(Address, GoalParams, Params, Params1),
        dispatch_goal(client(ConnId, GoalId), RequesterId, Bare, Params1)
    ).

%   A subgoal may carry its own address and parameters -- the nested parameter
%   lists the Developer's Guide allows within a compound goal.  They override
%   the enclosing request's.

merge_goal_params(Address, GoalParams, Params, Merged) :-
    (   Address == unknown
    ->  Extra = GoalParams
    ;   Extra = [address(Address)|GoalParams]
    ),
    icl_param_merge(Extra, Params, Merged).

%!  dispatch_goal(+ReplyTo, +RequesterId, +Goal, +Params) is det.
%
%   Select providers for one atomic goal and send it to them.

dispatch_goal(ReplyTo, RequesterId, Goal, Params) :-
    fac_registry(Registry),
    fac_select(Goal, Registry, Params, RequesterId, Candidates),
    restrict_to_address(Candidates, Params, RequesterId, Selected),
    (   meta_goal(Goal)
    ->  %  A consultation is itself a goal.  Sending it back through the
        %  meta hooks would not terminate.
        continue_dispatch(ReplyTo, RequesterId, Goal, Params, Selected)
    ;   Selected == [],
        meta_provider(Registry, lookup, LookupId)
    ->  start_meta(lookup, LookupId, ReplyTo, RequesterId, Goal, Params, [])
    ;   Selected \== [],
        meta_provider(Registry, prioritize, MetaId)
    ->  start_meta(prioritize, MetaId, ReplyTo, RequesterId, Goal, Params,
                   Selected)
    ;   continue_dispatch(ReplyTo, RequesterId, Goal, Params, Selected)
    ).

continue_dispatch(ReplyTo, RequesterId, Goal, Params, Selected) :-
    (   Selected == []
    ->  (   propagate_up(ReplyTo, Params)
        ->  propagate_upward(ReplyTo, Goal, Params)
        ;   finish_request(ReplyTo, Goal, Params, [], [], [])
        )
    ;   fac_dispatch_plan(Selected, Params, Mode, Batch),
        start_request(ReplyTo, RequesterId, Goal, Params, Mode, Selected, Batch)
    ).

%   Whether a goal this community cannot satisfy should be referred to the
%   parent facilitator.  Developer's Guide 6.10: propagate carries up/1 and
%   down/1, each true, false or if_no_solvers, defaulting to false -- so
%   nothing propagates unless a requester asks for it.
%
%   A goal that arrived *from* the parent is never sent back up, or a
%   community that cannot solve it would bounce it between levels forever.

propagate_up(ReplyTo, Params) :-
    parent_facilitator(_),
    \+ came_from_parent(ReplyTo),
    icl_get_param_value(propagate(PropParams), Params),
    icl_get_param_value(up(Up), PropParams, false),
    memberchk(Up, [true, if_no_solvers]),
    up_limit_allows(PropParams).

came_from_parent(client(parent, _)).

up_limit_allows(PropParams) :-
    (   icl_get_param_value(up_limit(Limit), PropParams),
        integer(Limit)
    ->  Limit > 0
    ;   true
    ).

%   Referring a goal upward is an ordinary request to the parent, made with
%   this facilitator's own agent library.  The continuation -- where the
%   answer has to come back to -- is the reply tag already in hand.

propagate_upward(ReplyTo, Goal, Params) :-
    oaa_next_goal_id(UpId),
    decrement_up_limit(Params, UpParams),
    assertz(referred(UpId, ReplyTo, Goal, UpParams)),
    com_send(parent, ev_solve(UpId, Goal, UpParams)).

decrement_up_limit(Params, UpParams) :-
    (   icl_get_param_value(propagate(PropParams), Params),
        icl_get_param_value(up_limit(Limit), PropParams),
        integer(Limit)
    ->  Limit1 is Limit - 1,
        icl_param_set(up_limit(Limit1), PropParams, PropParams1),
        icl_param_set(propagate(PropParams1), Params, UpParams)
    ;   UpParams = Params
    ).

:- dynamic referred/4.          % UpId, ReplyTo, Goal, Params

%   The parent has answered a referred goal.  The solution set, and the
%   identity of whoever solved it, go back to the original requester.

referred_answer(UpId, Requestees, Solvers, Solutions) :-
    (   retract(referred(UpId, ReplyTo, Goal, Params))
    ->  finish_request(ReplyTo, Goal, Params, Requestees, Solvers, Solutions)
    ;   true
    ).

meta_goal(Goal) :-
    nonvar(Goal),
    functor(Goal, meta, 5).

%   The highest-utility client agent offering a meta capability of this type.
%   The facilitator itself is skipped: it declares no meta solvables, and a
%   facilitator consulting itself would be a loop.

meta_provider(Registry, Type, Id) :-
    fac_meta_agents(Registry, Type, Providers),
    member(candidate(Id, _, _), Providers),
    Id \== 0,
    !.

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

% ------------------------------------------------------------- meta-agents
%
%   Meta-agents supply domain knowledge the Facilitator does not have.  They
%   declare meta(Type, +Goal, +Params, +FacInfo, -Result) and are consulted in
%   utility order.  Developer's Guide 5.6.
%
%   Two of the four hooks are wired here:
%
%     * `prioritize` -- given the Facilitator's sorted candidate list in
%       FacInfo, return a reordered list.  User preference, load balancing.
%     * `lookup` -- given a goal no connected agent can solve, find and start
%       an agent that can, returning true once it has connected.  This is what
%       makes the community extensible at request time.
%
%   Both are optional and fallible.  When no meta-agent is registered, or one
%   returns nothing the Facilitator can use, the Facilitator's own behaviour
%   stands -- its utility ordering for `prioritize`, plain failure for
%   `lookup`.  Nothing below this point depends on how a meta-agent reached
%   its answer, which is why an LLM can be one without the Facilitator
%   knowing.
%
%   Consultation is a dispatch like any other, answered to a meta(...) reply
%   tag, so the Facilitator never blocks on the agent it is asking.

:- dynamic meta_pending/6.      % PendingId, Type, ReplyTo, ReqId, Goal, Params
:- dynamic meta_pending_sel/2.  % PendingId, Selected
:- dynamic meta_counter/1.

meta_counter(0).

next_meta_id(Id) :-
    retract(meta_counter(N)),
    Id is N + 1,
    assertz(meta_counter(Id)).

start_meta(Type, MetaId, ReplyTo, RequesterId, Goal, Params, Selected) :-
    next_meta_id(PendingId),
    assertz(meta_pending(PendingId, Type, ReplyTo, RequesterId, Goal, Params)),
    assertz(meta_pending_sel(PendingId, Selected)),
    fac_info(Type, Selected, FacInfo),
    Consult = meta(Type, Goal, Params, FacInfo, _Result),
    dispatch_goal(meta(PendingId), RequesterId, Consult,
                  [address(MetaId), solution_limit(1)]).

%   FacInfo carries what the Facilitator knows and the meta-agent is being
%   asked to improve on: for prioritize, the sorted candidate list.

fac_info(prioritize, Selected, Ids) :-
    findall(Id, member(candidate(Id, _, _), Selected), Ids).
fac_info(lookup, _Selected, []).

meta_replied(PendingId, Solutions) :-
    (   retract(meta_pending(PendingId, Type, ReplyTo, ReqId, Goal, Params)),
        retract(meta_pending_sel(PendingId, Selected))
    ->  meta_result(Solutions, Result),
        meta_continue(Type, Result, ReplyTo, ReqId, Goal, Params, Selected)
    ;   true
    ).

meta_result(Solutions, Result) :-
    (   member(meta(_, _, _, _, R), Solutions)
    ->  Result = R
    ;   Result = '$none'
    ).

%   A prioritize result is a list of agent ids in the order the meta-agent
%   wants them tried.  Ids it does not mention keep their place behind the
%   ones it does, and ids that are not candidates are ignored.

meta_continue(prioritize, Result, ReplyTo, ReqId, Goal, Params, Selected) :-
    !,
    (   is_list(Result)
    ->  reorder_candidates(Result, Selected, Reordered)
    ;   Reordered = Selected
    ),
    continue_dispatch(ReplyTo, ReqId, Goal, Params, Reordered).

%   A lookup meta-agent returning true has connected an agent that can solve
%   the goal, so selection is worth repeating.  Anything else means it could
%   not, and the request fails as it would have anyway.

meta_continue(lookup, Result, ReplyTo, ReqId, Goal, Params, _Selected) :-
    !,
    (   Result == true
    ->  fac_registry(Registry),
        fac_select(Goal, Registry, Params, ReqId, Candidates),
        restrict_to_address(Candidates, Params, ReqId, Selected)
    ;   Selected = []
    ),
    continue_dispatch(ReplyTo, ReqId, Goal, Params, Selected).

meta_continue(_Type, _Result, ReplyTo, ReqId, Goal, Params, Selected) :-
    continue_dispatch(ReplyTo, ReqId, Goal, Params, Selected).

reorder_candidates(Order, Selected, Reordered) :-
    findall(C,
            ( member(Id, Order), member(C, Selected), C = candidate(Id, _, _) ),
            Named),
    exclude([candidate(Id, _, _)]>>memberchk(Id, Order), Selected, Unnamed),
    append(Named, Unnamed, Reordered).

start_request(ReplyTo, RequesterId, Goal, Params, Mode, Selected, Batch) :-
    oaa_next_goal_id(FacGoalId),
    findall(Id, member(candidate(Id, _, _), Batch), Requestees),
    assertz(outstanding(request(FacGoalId, ReplyTo, RequesterId, Goal, Params,
                                Mode, Selected, Batch, Requestees, [], []))),
    forall(member(C, Batch), send_request(FacGoalId, Goal, Params, C)),
    (   Batch == []
    ->  complete(FacGoalId)
    ;   true
    ).

send_request(FacGoalId, Goal, Params, candidate(Id, Solvable, _U)) :-
    outstanding(request(FacGoalId, _, RequesterId, _, _, _, _, _, _, _, _)),
    public_address(RequesterId, RequesterAddress),
    icl_param_merge([from(RequesterAddress)], Params, RoutedParams),
    (   Id =:= 0
    ->  solve_on_facilitator(FacGoalId, Goal, RoutedParams)
    ;   agent_entry(ConnId, Id, _, _, _, _),
        %  The event a provider receives is the result of unifying the goal
        %  with the solvable's template.  Developer's Guide 5.1.2.
        (   solvable_match(Goal, Solvable, Event)
        ->  true
        ;   Event = Goal
        ),
        fac_send(ConnId, ev_solve(FacGoalId, Event, RoutedParams))
    ).

%   Outgoing events are offered to the comm triggers as well, so a monitor
%   sees both halves of every exchange.

fac_send(ConnId, Event) :-
    oaa_note_event(send, ConnId, Event),
    com_send(ConnId, Event).

%   The facilitator answering its own solvables goes through the same
%   local-solving path a client agent uses.

solve_on_facilitator(FacGoalId, Goal, Params) :-
    copy_term(Goal, Probe),
    findall(Probe, oaa_solve_local(Probe, Params), Solutions),
    provider_replied(fac_self, FacGoalId, Solutions).

provider_replied(ConnId, FacGoalId, Solutions) :-
    (   retract(outstanding(request(FacGoalId, ReplyTo, ReqId, Goal, Params,
                                    Mode, Selected, Batch, Requestees,
                                    Acc, Solvers)))
    ->  append(Acc, Solutions, Acc1),
        (   Solutions == []
        ->  Solvers1 = Solvers
        ;   solver_id(ConnId, SolverId),
            append(Solvers, [SolverId], Solvers1)
        ),
        assertz(outstanding(request(FacGoalId, ReplyTo, ReqId, Goal, Params,
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
%   or the candidate list is exhausted.  That is how strategy(action) tries
%   one agent, and on failure the next.

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
    retract(outstanding(request(FacGoalId, ReplyTo, ReqId, Goal, Params, Mode,
                                 Selected, Batch, Requestees, Acc, Solvers))),
    append(Batch, [Next], Batch1),
    Next = candidate(NextId, _, _),
    append(Requestees, [NextId], Requestees1),
    assertz(outstanding(request(FacGoalId, ReplyTo, ReqId, Goal, Params, Mode,
                                 Selected, Batch1, Requestees1, Acc, Solvers))),
    send_request(FacGoalId, Goal, Params, Next).

complete(FacGoalId) :-
    (   retract(outstanding(request(FacGoalId, ReplyTo, _ReqId, Goal, Params,
                                     _Mode, _Sel, _Batch, Requestees,
                                     Acc, Solvers)))
    ->  retractall(replied(FacGoalId, _)),
        finish_request(ReplyTo, Goal, Params, Requestees, Solvers, Acc)
    ;   true
    ).

%!  finish_request(+ReplyTo, +Goal, +Params, +Requestees, +Solvers, +Solutions)
%
%   Deliver a completed request, either to the client that asked or back into
%   the compound execution that is waiting on it.

finish_request(client(ConnId, GoalId), Goal, Params, Requestees, Solvers, Sols) :-
    !,
    finish_solve(ConnId, GoalId, Goal, Params, Requestees, Solvers, Sols).
finish_request(compound(CompId), _Goal, _Params, Requestees, Solvers, Sols) :-
    !,
    compound_replied(CompId, Requestees, Solvers, Sols).
finish_request(meta(PendingId), _Goal, _Params, _Requestees, _Solvers, Sols) :-
    meta_replied(PendingId, Sols).

finish_solve(ConnId, GoalId, Goal, Params, Requestees, Solvers, Solutions0) :-
    dedupe(Solutions0, Params, Solutions1),
    apply_solution_limit(Solutions1, Params, Solutions),
    (   icl_get_param_value(reply(none), Params)
    ->  true
    ;   reply_goal(Goal, Params, ReplyGoal),
        public_addresses(Requestees, RequesteeAddresses),
        public_addresses(Solvers, SolverAddresses),
        fac_send(ConnId,
                 ev_solved(GoalId, RequesteeAddresses, SolverAddresses, ReplyGoal,
                           Params, Solutions))
    ).

apply_solution_limit(Solutions, Params, Limited) :-
    (   icl_get_param_value(solution_limit(N), Params),
        integer(N)
    ->  first_n(N, Solutions, Limited)
    ;   Limited = Solutions
    ).

first_n(N, _, []) :- N =< 0, !.
first_n(_, [], []) :- !.
first_n(N, [H|T], [H|R]) :-
    N1 is N - 1,
    first_n(N1, T, R).

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

% ------------------------------------------------------- compound goals

:- dynamic comp/6.      % CompId, ReplyTo, RequesterId, Params, Queue, Results
:- dynamic comp_current/2.      % CompId, Branch
:- dynamic comp_counter/1.

comp_counter(0).

next_comp_id(Id) :-
    retract(comp_counter(N)),
    Id is N + 1,
    assertz(comp_counter(Id)).

%   Executing a compound goal is a breadth-first walk over branches, driven
%   one dispatch at a time.  Each dispatched subgoal is an ordinary request
%   whose replies come back through finish_request, so the Facilitator never
%   blocks waiting on an agent.

begin_compound(ReplyTo, RequesterId, Goal, Params) :-
    icl_disassemble_goal(Goal, _Address, Bare, GoalParams),
    icl_param_merge(GoalParams, Params, Params1),
    next_comp_id(CompId),
    initial_branch(Bare, Branch),
    assertz(comp(CompId, ReplyTo, RequesterId, Params1, [Branch], [])),
    comp_step(CompId).

comp_step(CompId) :-
    retract(comp(CompId, ReplyTo, ReqId, Params, Queue, Results)),
    (   Queue == []
    ->  finish_compound(ReplyTo, Params, Results)
    ;   Queue = [Branch|Rest],
        branch_step(Branch, Action),
        comp_act(Action, CompId, ReplyTo, ReqId, Params, Branch, Rest, Results)
    ).

comp_act(solution(Template), CompId, ReplyTo, ReqId, Params, _B, Rest, Results) :-
    !,
    append(Results, [Template], Results1),
    assertz(comp(CompId, ReplyTo, ReqId, Params, Rest, Results1)),
    comp_step(CompId).
comp_act(expand(New), CompId, ReplyTo, ReqId, Params, _B, Rest, Results) :-
    !,
    append(New, Rest, Queue1),
    assertz(comp(CompId, ReplyTo, ReqId, Params, Queue1, Results)),
    comp_step(CompId).
comp_act(dispatch(Sub, SubParams, Address), CompId, ReplyTo, ReqId, Params,
         Branch, Rest, Results) :-
    assertz(comp(CompId, ReplyTo, ReqId, Params, Rest, Results)),
    retractall(comp_current(CompId, _)),
    assertz(comp_current(CompId, Branch)),
    merge_goal_params(Address, SubParams, Params, SubParams1),
    %  A subgoal is answered to the compound execution, never to the client.
    %  Its own reply and blocking parameters are irrelevant here.
    icl_param_merge([reply(true), blocking(true)], SubParams1, SubParams2),
    dispatch_goal(compound(CompId), ReqId, Sub, SubParams2).

%   A dispatched subgoal has come back.  Every solution continues the branch
%   it came from; no solutions kills that branch, which is how a failing
%   conjunct prunes the rest of its sequence.

compound_replied(CompId, _Requestees, _Solvers, Solutions) :-
    (   retract(comp_current(CompId, Branch))
    ->  retract(comp(CompId, ReplyTo, ReqId, Params, Queue, Results)),
        branch_advance(Branch, Solutions, New),
        append(New, Queue, Queue1),
        assertz(comp(CompId, ReplyTo, ReqId, Params, Queue1, Results)),
        comp_step(CompId)
    ;   true
    ).

finish_compound(client(ConnId, GoalId), Params, Results) :- !,
    finish_solve(ConnId, GoalId, _Goal, Params, [], [], Results).
finish_compound(compound(CompId), _Params, Results) :-
    compound_replied(CompId, [], [], Results).

%   When a client goes away, drop the requests it was waiting on, along with
%   any compound execution running on its behalf.

cancel_outstanding_for(ConnId) :-
    forall(outstanding(request(FacGoalId, client(ConnId, _), _, _, _,
                               _, _, _, _, _, _)),
           ( retractall(outstanding(request(FacGoalId, _, _, _, _,
                                            _, _, _, _, _, _))),
             retractall(replied(FacGoalId, _)) )),
    forall(comp(CompId, client(ConnId, _), _, _, _, _),
           ( retractall(comp(CompId, _, _, _, _, _)),
             retractall(comp_current(CompId, _)) )).

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
    ;   %  Six arguments, matching the shape SRI's own conformance tests
        %  expect: ev_data_updated(GoalId, Mode, Clause, Params, Requestees,
        %  Updaters).  See tests/compatibility/.
        public_addresses(Requestees, Addresses),
        com_send(ConnId, ev_data_updated(GoalId, Mode, Payload, Params,
                         Addresses, Addresses))
    ).

probe_of(replace, replace(C1, _), C1) :- !.
probe_of(_, Clause, Clause).

%   Trigger installation is routed like everything else: treat the condition
%   as a goal and select the agents whose solvables unify with it.  A data
%   trigger wants a data solvable, a task trigger a solvable of type trigger.
%   Developer's Guide 8.2.

update_trigger(ConnId, GoalId, Mode, Type, Cond, Action, Params) :-
    requester_id(ConnId, RequesterId),
    fac_registry(Registry),
    fac_select(Cond, Registry, Params, RequesterId, Candidates),
    restrict_to_address(Candidates, Params, RequesterId, Selected),
    include(trigger_capable(Type, Cond), Selected, Targets),
    forall(member(candidate(Id, _, _), Targets),
           route_trigger_op(Id, GoalId, Mode, Type, Cond, Action, Params,
                            RequesterId)),
    (   icl_get_param_value(reply(none), Params)
    ->  true
    ;   findall(Id, member(candidate(Id, _, _), Targets), Requestees),
        public_addresses(Requestees, Addresses),
        com_send(ConnId, ev_trigger_updated(GoalId, Mode, Type, Cond, Action,
                                            Params, Addresses, Addresses))
    ).

trigger_capable(data, _Cond, candidate(_, S, _)) :- !,
    solvable_type(S, data).
trigger_capable(task, _Cond, candidate(_, S, _)) :- !,
    solvable_type(S, trigger).
trigger_capable(_Type, _Cond, _Candidate).

route_trigger_op(0, _GoalId, Mode, Type, Cond, Action, Params, _Owner) :- !,
    (   Mode == add
    ->  oaa_install_trigger(Type, Cond, Action, Params)
    ;   oaa_remove_trigger(Type, Cond, Action, [address(self)])
    ).
route_trigger_op(Id, GoalId, Mode, Type, Cond, Action, Params, Owner) :-
    public_address(Owner, OwnerAddress),
    icl_param_merge([from(OwnerAddress)], Params, P2),
    (   agent_entry(Target, Id, _, _, _, _)
    ->  com_send(Target, ev_update_trigger(GoalId, Mode, Type, Cond, Action, P2))
    ;   true
    ).

route_data_op(0, _GoalId, Mode, Payload, Params, ConnId) :- !,
    requester_id(ConnId, Owner),
    public_address(Owner, OwnerAddress),
    icl_param_merge([from(OwnerAddress)], Params, P2),
    oaa_agent:apply_data_op_locally(Mode, Payload, P2, _).
route_data_op(Id, GoalId, Mode, Payload, Params, ConnId) :-
    requester_id(ConnId, Owner),
    public_address(Owner, OwnerAddress),
    icl_param_merge([from(OwnerAddress)], Params, P2),
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
    public_address(Id, AgentAddr).

handle_agent_version(agent_version(Address, Language, Version), _Params) :-
    address_id(Address, 0, Id),
    agent_entry(_, Id, _, _, _, Info),
    (   memberchk(other_language(Language), Info) -> true ; Language = unknown ),
    (   memberchk(other_version(Version), Info) -> true ; Version = unknown ).
