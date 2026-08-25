/*  oaa-next -- end-to-end community test
 *
 *  The Phase 1 acceptance test: start a Facilitator and two agents as
 *  separate operating-system processes, have a fourth process solve goals it
 *  cannot answer itself, and observe the Facilitator discover, delegate,
 *  collect and return.
 *
 *  Separate processes are not incidental.  An OAA agent is an ordinary
 *  software process, and each agent's declarations and data are its own; a
 *  test that ran them all in one Prolog image would share state between
 *  agents and prove nothing about delegation.
 *
 *  No LLM is present, no LLM package is installed, and no credentials are
 *  configured.  That is the OAA_CLASSIC guarantee.
 */

:- module(test_community, []).

:- use_module(community).

agents([ '/examples/basic/square_agent.pl',
         '/examples/basic/greet_agent.pl',
         '/examples/multi-agent/sensor_agent.pl' ]).

:- begin_tests(community,
               [ setup(( agents(A), start_community(A, C), nb_setval(comm, C) )),
                 cleanup(( nb_getval(comm, C), stop_community(C) )) ]).

client(Lines) :-
    nb_getval(comm, C),
    run_program(C, '/examples/basic/client.pl', Lines).

program(Relative, Lines) :-
    nb_getval(comm, C),
    run_program(C, Relative, Lines).

%   Given an agent advertises a capability, when another agent requests it,
%   then the Facilitator discovers and delegates, and the answer comes back.
test(delegates_and_returns) :-
    client(Lines),
    memberchk("square(7) = 49", Lines).

%   A callback that succeeds several times yields several solutions, and the
%   requester backtracks over them as it would over a local call.
test(multiple_solutions) :-
    client(Lines),
    memberchk("greet solutions: 3", Lines),
    memberchk("Hello, world", Lines),
    memberchk("Good day, world", Lines),
    memberchk("Greetings, world", Lines).

%   A goal no agent can solve fails, rather than hanging or erroring.
test(unsolvable_goal_fails) :-
    client(Lines),
    memberchk("unsolvable goal failed, as it should", Lines).

%   A compound goal is one request the Facilitator takes apart and delegates
%   piece by piece.  Variables shared between conjuncts join them, so a
%   conjunct depending on an earlier one goes out only after it returns.
test(compound_goal_chains_through_two_delegations) :-
    program('/examples/multi-agent/compound_client.pl', Lines),
    memberchk("chained: 3 -> 9 -> 81", Lines).

test(compound_goal_spans_agents) :-
    program('/examples/multi-agent/compound_client.pl', Lines),
    memberchk("cross-agent pairs: 3", Lines).

test(disjunction_takes_both_branches) :-
    program('/examples/multi-agent/compound_client.pl', Lines),
    memberchk("disjunction: [25,36]", Lines).

%   An unsolvable conjunct prunes everything after it, rather than hanging.
test(failing_conjunct_prunes) :-
    program('/examples/multi-agent/compound_client.pl', Lines),
    memberchk("failing conjunct pruned the request", Lines).

%   A data solvable declared on the facilitator with address(parent) is a
%   blackboard: one agent writes it, another reads it, and neither knows the
%   other exists.  Developer's Guide 5.2 and 7.7.
test(blackboard_is_shared) :-
    program('/examples/multi-agent/reporter.pl', Lines),
    memberchk("observations: 2", Lines),
    memberchk("temperature = 21", Lines),
    memberchk("humidity = 40", Lines).

:- end_tests(community).
