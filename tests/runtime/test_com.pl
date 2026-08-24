/*  oaa-next -- transport tests  */

:- module(test_com, []).

:- use_module('../../src/runtime/com_tcp').
:- use_module('../../src/icl/icl_term').

:- begin_tests(com_frame).

frame_str(Text, TermText, RestText) :-
    string_codes(Text, Codes),
    com_frame(Codes, T, R),
    string_codes(TermText, T),
    string_codes(RestText, R).

test(simple) :-
    frame_str("foo(a).\nbar", T, R),
    T == "foo(a)", R == "bar".

test(two_terms) :-
    frame_str("a. b.\n", T, R),
    T == "a", R == "b.\n".

%  A period inside quoted text must not end the term.
test(period_in_single_quotes) :-
    frame_str("send('Mr. Smith', x).\n", T, _),
    T == "send('Mr. Smith', x)".
test(period_in_double_quotes) :-
    frame_str("icldataq(\"one. two.\").\n", T, _),
    T == "icldataq(\"one. two.\")".
test(escaped_quote_in_atom) :-
    frame_str("p('it\\'s. here').\nrest", T, R),
    T == "p('it\\'s. here')", R == "rest".

%  Incomplete input must not frame: the term is simply not there yet.
test(incomplete_no_frame, [fail]) :-
    frame_str("foo(a", _, _).
test(period_without_layout_is_incomplete, [fail]) :-
    frame_str("foo(a).", _, _).
test(unterminated_quote, [fail]) :-
    frame_str("p('unclosed. ", _, _).

%  Framing composes with parsing: what is framed must parse back.
test(frame_then_parse) :-
    frame_str("solve(a,B).\n", T, _),
    icl_parse_term(T, Term),
    Term =@= solve(a, _).

:- end_tests(com_frame).


:- begin_tests(com_socket, [cleanup(com_close_all)]).

%  A full connect / accept / exchange cycle driven from one thread, which is
%  what oaa_MainLoop does: a listener and its peers multiplexed together.
test(round_trip) :-
    com_listen_at(srv, [address(tcp(localhost, _))], addr(tcp(_, Port))),
    com_connect(cli, [address(tcp(localhost, Port))], _),
    com_poll([srv], 2, Ready), memberchk(srv, Ready),
    com_accept(srv, Peer),

    com_send(cli, ev_solve(1, send(mail, adam, 'hi. there'), [])),
    com_poll([Peer], 2, R1), memberchk(Peer, R1),
    com_read(Peer, Got),
    Got == ev_solve(1, send(mail, adam, 'hi. there'), []),

    com_send(Peer, ev_solved(1, [7], [7], _Goal, [], [send(mail, adam, ok)])),
    com_poll([cli], 2, R2), memberchk(cli, R2),
    com_read(cli, Back),
    Back = ev_solved(1, [7], [7], G, [], [send(mail, adam, ok)]),
    var(G),

    com_close(cli), com_close(Peer), com_close(srv).

test(batched_terms, [cleanup(com_close_all)]) :-
    com_listen_at(srv2, [address(tcp(localhost, _))], addr(tcp(_, Port))),
    com_connect(cli2, [address(tcp(localhost, Port))], _),
    com_poll([srv2], 2, _), com_accept(srv2, Peer),
    com_send(cli2, a(1)), com_send(cli2, a(2)), com_send(cli2, a(3)),
    com_poll([Peer], 2, _),
    collect(Peer, 3, Terms),
    Terms == [a(1), a(2), a(3)],
    com_close(cli2), com_close(Peer), com_close(srv2).

collect(_, 0, []) :- !.
collect(Conn, N, [T|Ts]) :-
    com_read(Conn, T),
    N1 is N - 1,
    collect(Conn, N1, Ts).

test(eof_detected, [cleanup(com_close_all)]) :-
    com_listen_at(srv3, [address(tcp(localhost, _))], addr(tcp(_, Port))),
    com_connect(cli3, [address(tcp(localhost, Port))], _),
    com_poll([srv3], 2, _), com_accept(srv3, Peer),
    com_close(cli3),
    com_poll([Peer], 2, _),
    catch(com_read(Peer, _), E, true),
    nonvar(E), E = com_eof(Peer),
    com_close(Peer), com_close(srv3).

:- end_tests(com_socket).
