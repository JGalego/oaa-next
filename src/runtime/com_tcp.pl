/*  oaa-next -- transport layer, TCP implementation
 *
 *  Provenance: RECONSTRUCTED.
 *  Developer's Guide v2.3.2 sections 4.2 and 4.3.7.
 */

:- module(com_tcp,
          [ com_connect/3,              % +ConnId, +Params, -Address
            com_listen_at/3,            % +ConnId, +Params, -Address
            com_accept/2,               % +ListenerId, -ConnId
            com_send/2,                 % +ConnId, +Term
            com_read/2,                 % +ConnId, -Term
            com_read_pending/2,         % +ConnId, -Terms
            com_poll/3,                 % +ConnIds, +Timeout, -Ready
            com_close/1,                % +ConnId
            com_close_all/0,
            com_connection/2,           % ?ConnId, ?Kind
            com_connections/1,          % -ConnIds
            com_address/2,              % ?ConnId, ?Address
            com_is_listener/1,          % ?ConnId
            com_frame/3,                % +Codes, -TermCodes, -Rest

            com_StandardizeAddress/2,
            com_Connect/3,
            com_Connect/4,
            com_Disconnect/1,
            com_DisconnectWithFailure/1,
            com_ShutdownAll/0,
            com_Shutdown/1,
            com_TcpShutdown/1,
            com_Connected/4,
            com_ReportConnections/1,
            com_ListenAt/3,
            com_ListenAt/4,
            com_SendData/2,
            com_SelectEvent/2,
            com_AddInfo/2,
            com_UpdateInfo/2,
            com_GetInfo/2,
            com_GetAllInfo/2,
            com_CancelWakeup/2,
            com_ScheduleWakeup/2,
            com_RecordAddressForId/2,
            com_AddressForId/2,
            com_write_term/1
          ]).

:- use_module(library(socket)).
:- use_module(library(time)).
:- use_module('../icl/icl_term').
:- use_module('../runtime/oaa_config').

/** <module> The com_ transport API

All interagent communication passes through this boundary.  The Developer's
Guide is explicit that OAA was structured to allow other transports by
specifying an API for the transport layer, loaded as a distinct module, with
every procedure prefixed `com_`.  TCP is the only transport the historical
system ever shipped; the seam it left behind is kept here, so nothing above
this module knows what a socket is.

Framing is a stream of period-terminated ICL terms, which the historical
grammars' multi-term entry point exists to read.
*/

:- dynamic connection/4.        % ConnId, Kind, InStream, OutStream
:- dynamic listener_socket/2.   % ConnId, Socket
:- dynamic conn_buffer/2.       % ConnId, Codes
:- dynamic conn_address/2.      % ConnId, Address
:- dynamic conn_counter/1.
:- dynamic compat_info/2.      % ConnId, historical com_GetInfo element
:- dynamic compat_alarm/3.     % Time, Event, AlarmId

conn_counter(0).

% ------------------------------------------------------------------ connect

%!  com_connect(+ConnId, +Params, -Address) is det.
%
%   Open a client connection.  Params must carry address(tcp(Host, Port)).
%   The historical signature is com_Connect(parent, [], _Address), with the
%   address normally coming from the command line, the environment or the
%   setup file; resolving it from those sources is the caller's job (see
%   oaa_config.pl), and the resolved value arrives here.

com_connect(ConnId, Params, Address) :-
    memberchk(address(tcp(Host, Port)), Params),
    setup_call_cleanup(
        tcp_socket(Socket),
        tcp_connect(Socket, Host:Port),
        true),
    tcp_open_socket(Socket, In, Out),
    set_stream(In, encoding(utf8)),
    set_stream(Out, encoding(utf8)),
    retractall(connection(ConnId, _, _, _)),
    assertz(connection(ConnId, client, In, Out)),
    set_buffer(ConnId, []),
    Address = addr(tcp(Host, Port)),
    retractall(conn_address(ConnId, _)),
    assertz(conn_address(ConnId, Address)),
    retractall(compat_info(ConnId, _)),
    forall(member(I, [status(connected), type(client), protocol(tcp),
                      other_address(Address)]), assertz(compat_info(ConnId, I))).

%!  com_listen_at(+ConnId, +Params, -Address) is det.
%
%   Open a listener socket.  A port of 0, or an unbound port, asks the
%   operating system for an available one -- the Developer's Guide notes that
%   a facilitator address may leave the host or port unspecified, in which
%   case acceptable values are chosen by the system.

com_listen_at(ConnId, Params, Address) :-
    (   memberchk(address(tcp(Host, Port0)), Params)
    ->  true
    ;   Host = localhost, Port0 = 0
    ),
    tcp_socket(Socket),
    tcp_setopt(Socket, reuseaddr),
    %  Binding an unbound port asks the operating system for a free one and
    %  unifies Port with what it gave us.  The Developer's Guide notes that a
    %  facilitator address may leave the port unspecified for this.
    (   ( var(Port0) ; Port0 == 0 )
    ->  true
    ;   Port = Port0
    ),
    catch(tcp_bind(Socket, Port), E,
          ( tcp_close_socket(Socket), throw(E) )),
    tcp_listen(Socket, 32),
    tcp_open_socket(Socket, In, _Out),
    retractall(connection(ConnId, _, _, _)),
    assertz(connection(ConnId, listener, In, none)),
    assertz(listener_socket(ConnId, Socket)),
    Address = addr(tcp(Host, Port)),
    retractall(conn_address(ConnId, _)),
    assertz(conn_address(ConnId, Address)),
    retractall(compat_info(ConnId, _)),
    forall(member(I, [status(connected), type(server), protocol(tcp),
                      oaa_address(Address)]), assertz(compat_info(ConnId, I))).

%!  com_accept(+ListenerId, -ConnId) is det.
%
%   Accept one pending connection on a listener, giving it a fresh connection
%   id.  Callers normally reach this only after com_poll/3 has reported the
%   listener ready.

com_accept(ListenerId, ConnId) :-
    listener_socket(ListenerId, Socket),
    tcp_accept(Socket, Client, Peer),
    tcp_open_socket(Client, In, Out),
    set_stream(In, encoding(utf8)),
    set_stream(Out, encoding(utf8)),
    next_conn_id(ConnId),
    assertz(connection(ConnId, peer, In, Out)),
    set_buffer(ConnId, []),
    peer_address(Peer, Address),
    assertz(conn_address(ConnId, Address)),
    forall(member(I, [status(connected), type(peer), protocol(tcp),
                      other_address(Address)]), assertz(compat_info(ConnId, I))).

peer_address(Host:Port, addr(tcp(Host, Port))) :- !.
peer_address(ip(A,B,C,D), addr(tcp(Host, 0))) :- !,
    atomic_list_concat([A,B,C,D], '.', Host).
peer_address(_, addr(tcp(unknown, 0))).

next_conn_id(ConnId) :-
    retract(conn_counter(N)),
    N1 is N + 1,
    assertz(conn_counter(N1)),
    atom_concat(conn_, N1, ConnId).

% --------------------------------------------------------------------- send

%!  com_send(+ConnId, +Term) is det.
%
%   Write one ICL term, period-terminated, and flush.

com_send(ConnId, Term) :-
    (   connection(ConnId, _, _, Out),
        Out \== none
    ->  wire_encode(Term, WireTerm),
        catch(icl_write_event(Out, WireTerm), E, throw(com_error(ConnId, E)))
    ;   throw(com_error(ConnId, no_such_connection))
    ).

%   OAA 2.x puts conversational content inside event(Content, Params).  Keep
%   that historical representation on the TCP stream while exposing Content
%   to the reconstructed runtime, whose handlers already receive the source
%   connection separately.  Non-OAA terms remain untouched so com_ is still
%   a general term transport.

wire_encode(event(Content, Params), event(Content, Params)) :- !.
wire_encode(Term, event(Term, [])) :-
    oaa_event_content(Term), !.
wire_encode(Term, Term).

wire_decode(event(Content, _Params), Content) :- !.
wire_decode(Term, Term).

oaa_event_content(Term) :-
    compound(Term),
    functor(Term, Name, _),
    atom_concat(ev_, _, Name).

% --------------------------------------------------------------------- read

%!  com_read(+ConnId, -Term) is semidet.
%
%   Block until one complete term is available.  Throws com_eof(ConnId) when
%   the peer closes.

com_read(ConnId, Term) :-
    (   take_buffered(ConnId, Wire)
    ->  wire_decode(Wire, Term)
    ;   fill(ConnId, infinite),
        com_read(ConnId, Term)
    ).

%!  com_read_pending(+ConnId, -Terms) is det.
%
%   Read whatever has arrived and return every complete term in it.  Does not
%   block.  Throws com_eof(ConnId) at end of stream.

com_read_pending(ConnId, Terms) :-
    fill(ConnId, 0),
    drain(ConnId, Terms).

drain(ConnId, [T|Ts]) :-
    take_buffered(ConnId, Wire), !,
    wire_decode(Wire, T),
    drain(ConnId, Ts).
drain(_, []).

%   fill(+ConnId, +Timeout) appends whatever bytes are available.

fill(ConnId, Timeout) :-
    connection(ConnId, _, In, _),
    (   Timeout == infinite
    ->  Wait = infinite
    ;   Wait = Timeout
    ),
    (   wait_for_input([In], [In], Wait)
    ->  (   at_end_of_stream(In)
        ->  throw(com_eof(ConnId))
        ;   read_pending_codes(In, Codes, []),
            (   Codes == []
            ->  throw(com_eof(ConnId))
            ;   append_buffer(ConnId, Codes)
            )
        )
    ;   true
    ).

take_buffered(ConnId, Term) :-
    conn_buffer(ConnId, Codes),
    com_frame(Codes, TermCodes, Rest),
    (   icl_parse_term(TermCodes, Term)
    ->  set_buffer(ConnId, Rest)
    ;   %  A framed but unparsable term is dropped rather than wedging the
        %  connection; a malformed message must not stall every later one.
        set_buffer(ConnId, Rest),
        fail
    ).

set_buffer(ConnId, Codes) :-
    retractall(conn_buffer(ConnId, _)),
    assertz(conn_buffer(ConnId, Codes)).

append_buffer(ConnId, New) :-
    (   retract(conn_buffer(ConnId, Old))
    ->  true
    ;   Old = []
    ),
    append(Old, New, Codes),
    assertz(conn_buffer(ConnId, Codes)).

% ------------------------------------------------------------------ framing

%!  com_frame(+Codes, -TermCodes, -Rest) is semidet.
%
%   Split off the first complete term.  A term ends at the first period that
%   is outside any quoted text and is followed by layout.  Requiring the
%   following layout character keeps the scan safe against a buffer that
%   ends on the period: the term is not complete yet.
%
%   Quote state is tracked so that a period inside 'an atom. like this' or
%   inside a double-quoted body does not end the term.

com_frame(Codes, TermCodes, Rest) :-
    scan(Codes, normal, [], TermCodes, Rest).

scan([0'., C|T], normal, Acc, TermCodes, Rest) :-
    code_type(C, space), !,
    reverse(Acc, TermCodes),
    Rest = T.
scan([0'\\, C|T], State, Acc, TermCodes, Rest) :-
    State \== normal, !,
    scan(T, State, [C, 0'\\|Acc], TermCodes, Rest).
scan([0''|T], normal, Acc, TermCodes, Rest) :- !,
    scan(T, single, [0''|Acc], TermCodes, Rest).
scan([0''|T], single, Acc, TermCodes, Rest) :- !,
    scan(T, normal, [0''|Acc], TermCodes, Rest).
scan([0'"|T], normal, Acc, TermCodes, Rest) :- !,
    scan(T, double, [0'"|Acc], TermCodes, Rest).
scan([0'"|T], double, Acc, TermCodes, Rest) :- !,
    scan(T, normal, [0'"|Acc], TermCodes, Rest).
scan([C|T], State, Acc, TermCodes, Rest) :- !,
    scan(T, State, [C|Acc], TermCodes, Rest).

% --------------------------------------------------------------------- poll

%!  com_poll(+ConnIds, +Timeout, -Ready) is det.
%
%   Wait until one of the given connections has input, or Timeout seconds
%   elapse.  A listener counts as ready when a connection is pending, which is
%   what lets an agent -- the Facilitator included -- serve its listener and
%   its peers from one single-threaded event loop, as oaa_MainLoop does.

com_poll(ConnIds, Timeout, Ready) :-
    findall(In-Id,
            ( member(Id, ConnIds), connection(Id, _, In, _), In \== none ),
            Pairs),
    (   Pairs == []
    ->  Ready = []
    ;   pairs_keys(Pairs, Streams),
        (   buffered_ready(ConnIds, Buffered), Buffered \== []
        ->  Ready = Buffered
        ;   wait_for_input(Streams, ReadyStreams, Timeout),
            findall(Id,
                    ( member(S, ReadyStreams), memberchk(S-Id, Pairs) ),
                    Ready)
        )
    ).

%   A connection whose buffer already holds a complete term is ready even
%   though its socket has nothing pending.

buffered_ready(ConnIds, Ready) :-
    findall(Id,
            ( member(Id, ConnIds),
              conn_buffer(Id, Codes),
              com_frame(Codes, _, _) ),
            Ready).

% -------------------------------------------------------------------- close

com_close(ConnId) :-
    (   retract(connection(ConnId, _Kind, In, Out))
    ->  catch(close(In), _, true),
        ( Out == none -> true ; catch(close(Out), _, true) )
    ;   true
    ),
    (   retract(listener_socket(ConnId, Socket))
    ->  catch(tcp_close_socket(Socket), _, true)
    ;   true
    ),
    retractall(conn_buffer(ConnId, _)),
    retractall(conn_address(ConnId, _)),
    retractall(compat_info(ConnId, _)).

com_close_all :-
    forall(connection(Id, _, _, _), com_close(Id)),
    forall(listener_socket(Id, _), com_close(Id)).

% ------------------------------------------------------------------ queries

com_connection(ConnId, Kind) :-
    connection(ConnId, Kind, _, _).

com_connections(ConnIds) :-
    findall(Id, connection(Id, _, _, _), ConnIds).

com_address(ConnId, Address) :-
    conn_address(ConnId, Address).

com_is_listener(ConnId) :-
    connection(ConnId, listener, _, _).

% ------------------------------------------------ OAA 2.3.2 com_ compatibility

com_StandardizeAddress(tcp(Host, Port), tcp(Host, Port)).

com_Connect(ConnectionId, Params, Address) :-
    com_Connect(ConnectionId, Params, Address, _).

com_Connect(ConnectionId, Params, Address0, ActualAddress) :-
    compat_connect_address(Address0, Address),
    com_connect(ConnectionId, [address(Address)|Params], addr(ActualAddress)).

compat_connect_address(Address, Address) :- nonvar(Address), !.
compat_connect_address(_Address, Address) :-
    oaa_facilitator_address(Address).

com_Disconnect(ConnectionId) :- com_close(ConnectionId).
com_DisconnectWithFailure(ConnectionId) :- com_close(ConnectionId).
com_ShutdownAll :- com_close_all.
com_Shutdown(ConnectionId) :- com_close(ConnectionId).
com_TcpShutdown(ConnectionId) :- com_close(ConnectionId).

com_Connected(ConnectionId, tcp, Type, Info) :-
    connection(ConnectionId, Kind, _, _),
    compat_connection_type(Kind, Type),
    com_GetAllInfo(ConnectionId, Info).

compat_connection_type(listener, server) :- !.
compat_connection_type(client, client) :- !.
compat_connection_type(peer, peer).

com_ReportConnections(Connections) :-
    findall(connection(Id, tcp, Type, Info),
            com_Connected(Id, tcp, Type, Info), Connections).

com_ListenAt(ConnectionId, Params, RequestedAddress) :-
    com_ListenAt(ConnectionId, Params, RequestedAddress, _).

com_ListenAt(ConnectionId, Params, RequestedAddress, ActualAddress) :-
    com_listen_at(ConnectionId, [address(RequestedAddress)|Params],
                  addr(ActualAddress)).

com_SendData(ConnectionId, Term) :- com_send(ConnectionId, Term).

com_SelectEvent(Timeout, Event) :-
    (   retract(compat_wakeup(Event))
    ->  true
    ;   com_connections(Connections),
        com_poll(Connections, Timeout, Ready),
        (   Ready = [ConnectionId|_]
        ->  (   com_is_listener(ConnectionId)
            ->  com_accept(ConnectionId, NewId), Event = connected(NewId)
            ;   catch(com_read(ConnectionId, Term), com_eof(ConnectionId),
                      Term = end_of_file(ConnectionId)),
                Event = term(ConnectionId, Term)
            )
        ;   Event = timeout
        )
    ).

com_AddInfo(ConnectionId, Info) :-
    (   is_list(Info)
    ->  forall(member(I, Info), com_AddInfo(ConnectionId, I))
    ;   assertz(compat_info(ConnectionId, Info))
    ).

com_UpdateInfo(ConnectionId, Info) :-
    (   is_list(Info)
    ->  forall(member(I, Info), com_UpdateInfo(ConnectionId, I))
    ;   functor(Info, Name, Arity),
        functor(Probe, Name, Arity),
        retractall(compat_info(ConnectionId, Probe)),
        assertz(compat_info(ConnectionId, Info))
    ).

com_GetInfo(ConnectionId, Info) :- compat_info(ConnectionId, Info).

com_GetAllInfo(ConnectionId, Info) :-
    findall(I, compat_info(ConnectionId, I), Info).

:- dynamic compat_wakeup/1.

com_ScheduleWakeup(Time, Event) :-
    get_time(Now),
    ( number(Time), Time > Now -> Delay is Time - Now ; Delay = 0 ),
    alarm(Delay, assertz(compat_wakeup(wakeup(Event))), AlarmId,
          [remove(true)]),
    assertz(compat_alarm(Time, Event, AlarmId)).

com_CancelWakeup(Time, Event) :-
    retract(compat_alarm(Time, Event, AlarmId)),
    remove_alarm(AlarmId).

com_RecordAddressForId(ConnectionId, Address) :-
    retractall(conn_address(ConnectionId, _)),
    assertz(conn_address(ConnectionId, Address)),
    com_UpdateInfo(ConnectionId, other_address(Address)).

com_AddressForId(ConnectionId, Address) :- com_address(ConnectionId, Address).

com_write_term(Term) :- icl_write(Term).
