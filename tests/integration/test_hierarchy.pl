/*  oaa-next -- facilitator hierarchies
 *
 *  A node facilitator is an ordinary agent of its parent that happens to
 *  advertise everything its own clients can solve.  That single fact gives
 *  both directions of reach, and is why there is no federation protocol.
 */

:- module(test_hierarchy, []).

:- use_module(community).

:- begin_tests(hierarchy,
               [ setup(( start_hierarchy(['/examples/basic/greet_agent.pl'],
                                         ['/examples/basic/square_agent.pl'],
                                         H),
                         nb_setval(hier, H) )),
                 cleanup(( nb_getval(hier, H), stop_community(H) )) ]).

from_node(Lines) :-
    nb_getval(hier, H),
    run_program_at(H, node, '/examples/multi-agent/hierarchy_client.pl', Lines).

%   A capability in the client's own community is reached as usual.
test(local_community_unaffected) :-
    from_node(Lines),
    memberchk("local community: square(4) = 16", Lines).

%   Developer's Guide 6.10: propagation defaults to false, so a capability
%   held only above is out of reach unless the requester asks for it.
test(no_propagation_by_default) :-
    from_node(Lines),
    memberchk("unpropagated: no solution, as expected", Lines).

%   With propagate([up(true)]) the node facilitator refers the goal to its
%   parent and the answer comes back down.
test(propagates_upward_when_asked) :-
    from_node(Lines),
    memberchk("propagated up: Hello, world", Lines).

%   Downward needs no propagation at all: the node registered its clients'
%   solvables with the root, so the root selects it by ordinary unification.
test(root_reaches_node_community_without_propagation) :-
    nb_getval(hier, H),
    run_program_at(H, root, '/examples/multi-agent/root_client.pl', Lines),
    memberchk("root asking downward: square(6) = 36", Lines).

:- end_tests(hierarchy).
