/*  oaa-next -- direct connections between agents  */

:- module(test_direct, []).

:- use_module(community).

:- begin_tests(direct_connect,
               [ setup(( start_community(['/examples/multi-agent/direct_agent.pl'], C),
                         nb_setval(dc, C) )),
                 cleanup(( nb_getval(dc, C), stop_community(C) )) ]).

lines(Lines) :-
    nb_getval(dc, C),
    run_program(C, '/examples/multi-agent/direct_client.pl', Lines).

%   direct_connect routes the message traffic straight to the provider while
%   leaving the choice of provider to the Facilitator.  Developer's Guide 10.1.
test(direct_connection_answers) :-
    lines(Lines),
    memberchk("direct: echoed(hello)", Lines).

%   The same call without it goes through the Facilitator, and the agent
%   cannot tell the difference.
test(relayed_still_works) :-
    lines(Lines),
    memberchk("relayed: echoed(again)", Lines).

:- end_tests(direct_connect).
