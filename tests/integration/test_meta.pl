/*  oaa-next -- meta-agent tests
 *
 *  Meta-agents supply domain knowledge the Facilitator does not have.  These
 *  tests run the same question against two communities that differ only in
 *  whether a prioritize meta-agent is present, which is the cleanest way to
 *  show that the Facilitator's own ordering is a default rather than a rule.
 */

:- module(test_meta, []).

:- use_module(community).

oracles([ '/examples/multi-agent/oracle_a.pl',
          '/examples/multi-agent/oracle_b.pl' ]).

:- begin_tests(meta_agents).

%   With no meta-agent, the Facilitator orders providers by declared utility,
%   so oracle_b -- utility 9 against oracle_a's 5 -- answers.
test(utility_ordering_without_meta,
     [setup(( oracles(A), start_community(A, C) )),
      cleanup(stop_community(C))]) :-
    run_program(C, '/examples/multi-agent/oracle_client.pl', Lines),
    memberchk("answered by: from_b(q)", Lines).

%   Add a prioritize meta-agent that reverses the ordering and the other
%   agent answers instead.  Nothing about the Facilitator changed.
test(meta_agent_overrides_utility_ordering,
     [setup(( oracles(A),
              append(A, ['/examples/multi-agent/preference_agent.pl'], All),
              start_community(All, C) )),
      cleanup(stop_community(C))]) :-
    run_program(C, '/examples/multi-agent/oracle_client.pl', Lines),
    memberchk("answered by: from_a(q)", Lines).

:- end_tests(meta_agents).
