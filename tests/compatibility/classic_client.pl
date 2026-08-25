/* Source-compatibility fixture using the OAA 2.3.2 Prolog API unchanged. */

:- use_module('../../src/agents/oaa').
:- use_module('../../src/runtime/com_tcp').

:- initialization(main, main).

main(_) :-
    com_Connect(parent, [], _Address, _Actual),
    oaa_Register(parent, classic_fixture, [], []),
    oaa_Ready(false),
    oaa_PrimaryAddress(Self),
    oaa_Solve(agent_data(Self, client, ready, _, classic_fixture, _),
              [address(parent)]),
    format('classic API registered: ~q~n', [Self]),
    oaa_Disconnect(parent, []),
    halt(0).
