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
            com_frame/3                 % +Codes, -TermCodes, -Rest
          ]).

:- use_module(library(socket)).
:- use_module('../icl/icl_term').

/** <module> The com_ transport API

All interagent communication passes through this boundary.  The Developer's
Guide is explicit that OAA was structured to allow other transports by
specifying an API for the transport layer, loaded as a distinct module, with
every procedure prefixed `com_`.  TCP is the only transport the historical
system ever shipped, but the *seam* is the architecture, so it is preserved
here: nothing above this module knows what a socket is.

Framing is a stream of period-terminated ICL terms, which is what the
historical grammars' multi-term entry point exists to read.
*/

:- dynamic connection/4.        % ConnId, Kind, InStream, OutStream
:- dynamic listener_socket/2.   % ConnId, Socket
:- dynamic conn_buffer/2.       % ConnId, Codes
:- dynamic conn_address/2.      % ConnId, Address
:- dynamic conn_counter/1.

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
    assertz(conn_address(ConnId, Address)).

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
    %  facilitator address may leave the port unspecified for exactly this.
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
    assertz(conn_address(ConnId, Address)).

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
    assertz(conn_address(ConnId, Address)).

peer_address(Host:Port, addr(tcp(Host, Port))) :- !.
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
    ->  catch(icl_write_event(Out, Term), E, throw(com_error(ConnId, E)))
    ;   throw(com_error(ConnId, no_such_connection))
    ).

% --------------------------------------------------------------------- read

%!  com_read(+ConnId, -Term) is semidet.
%
%   Block until one complete term is available.  Throws com_eof(ConnId) when
%   the peer closes.

com_read(ConnId, Term) :-
    (   take_buffered(ConnId, Term)
    ->  true
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
    take_buffered(ConnId, T), !,
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
%   following layout character is what makes the scan safe against a buffer
%   that ends exactly on the period: the term is simply not complete yet.
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
    retractall(conn_address(ConnId, _)).

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
