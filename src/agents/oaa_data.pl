/*  oaa-next -- data solvable store
 *
 *  Provenance: RECONSTRUCTED.
 *  Developer's Guide v2.3.2 section 7.
 */

:- module(oaa_data,
          [ oaa_data_add/4,             % +Owner, +Clause, +Params, -Ok
            oaa_data_remove/4,          % +Owner, +Clause, +Params, -Count
            oaa_data_replace/5,         % +Owner, +Clause1, +Clause2, +Params, -Ok
            oaa_data_query/1,           % ?Clause
            oaa_data_query/2,           % ?Clause, ?Owner
            oaa_data_all/1,             % -Clauses
            oaa_data_remove_owner/1,    % +Owner
            oaa_data_clear/0,
            oaa_data_key/2              % +Clause, -Key
          ]).

:- use_module('../icl/icl_params').

/** <module> The local store behind data solvables

A data solvable is essentially a relation: the Developer's Guide describes it
as the same thing as a relational database table, queried through oaa_Solve
like any other solvable and maintained through oaa_AddData, oaa_RemoveData and
oaa_ReplaceData.

Ownership: the library records which agent created each fact, and uses that
record to remove an agent's facts when it goes offline.  Agents do not have to
model this themselves, and the owner/1 parameter of oaa_Solve can query it.

Order: new facts are appended, so a subsequent query returns them last, unless
at_beginning(true) is given.  Removal takes only the first unifying fact
unless do_all(true) is given.

Replacement is atomic: nothing may read or write between the removal and the
addition.  Here that follows from both operations happening inside one
predicate; a threaded implementation would have to arrange it.
*/

:- dynamic fact_seq/1.
:- dynamic ordered_fact/4.      % Key, Seq, Owner, Clause

fact_seq(0).

%!  oaa_data_key(+Clause, -Key) is semidet.
%
%   Facts are grouped by the functor and arity of the solvable they belong to.

oaa_data_key(Clause, Name/Arity) :-
    (   atom(Clause)
    ->  Name = Clause, Arity = 0
    ;   compound(Clause),
        functor(Clause, Name, Arity)
    ).

next_seq(N) :-
    retract(fact_seq(N0)),
    N is N0 + 1,
    assertz(fact_seq(N)).

%!  oaa_data_add(+Owner, +Clause, +Params, -Ok) is det.
%
%   Record Clause in the form given.  Params may carry:
%
%     * at_beginning(true)   -- prepend rather than append
%     * single_value(true)   -- at most one fact for this solvable; a new one
%                               displaces the old
%     * unique_values(true)  -- refuse an exact duplicate

oaa_data_add(Owner, Clause, Params, Ok) :-
    oaa_data_key(Clause, Key),
    icl_get_param_value(single_value(Single), Params, false),
    icl_get_param_value(unique_values(Unique), Params, false),
    icl_get_param_value(at_beginning(AtStart), Params, false),
    (   Single == true
    ->  retractall(ordered_fact(Key, _, _, _))
    ;   true
    ),
    (   Unique == true,
        ordered_fact(Key, _, _, Existing),
        Existing =@= Clause
    ->  Ok = false
    ;   next_seq(N),
        (   AtStart == true
        ->  Seq is -N
        ;   Seq = N
        ),
        assertz(ordered_fact(Key, Seq, Owner, Clause)),
        Ok = true
    ).

%!  oaa_data_remove(+Owner, +Clause, +Params, -Count) is det.
%
%   Remove facts unifying with Clause.  By default only the first; with
%   do_all(true), all of them.  Owner is the agent making the request and is
%   not itself a filter -- any agent with write permission may remove -- but
%   an owner/1 parameter narrows to facts created by a particular agent.

oaa_data_remove(_Owner, Clause, Params, Count) :-
    oaa_data_key(Clause, Key),
    icl_get_param_value(do_all(All), Params, false),
    (   icl_get_param_value(owner(Restrict), Params)
    ->  true
    ;   Restrict = '$any'
    ),
    findall(Seq-O-C,
            ( ordered_fact(Key, Seq, O, C),
              owner_ok(Restrict, O),
              \+ \+ C = Clause ),
            Matches0),
    sort(Matches0, Matches),
    (   All == true
    ->  Chosen = Matches
    ;   ( Matches = [First|_] -> Chosen = [First] ; Chosen = [] )
    ),
    forall(member(S-O2-C2, Chosen),
           retract(ordered_fact(Key, S, O2, C2))),
    length(Chosen, Count).

owner_ok('$any', _) :- !.
owner_ok(Owner, Owner).

%!  oaa_data_replace(+Owner, +Clause1, +Clause2, +Params, -Ok) is det.
%
%   Remove a fact unifying with Clause1 and record Clause2, atomically.
%
%   The two clauses need not belong to the same solvable: the Developer's
%   Guide requires only that the agent provide a data solvable appropriate for
%   each.

oaa_data_replace(Owner, Clause1, Clause2, Params, Ok) :-
    oaa_data_remove(Owner, Clause1, Params, Count),
    (   Count > 0
    ->  oaa_data_add(Owner, Clause2, Params, Ok)
    ;   %  Nothing matched, so nothing is replaced.  The historical libraries
        %  treat this as an unsuccessful completion, which
        %  get_satisfiers reports on.
        Ok = false
    ).

%!  oaa_data_query(?Clause) is nondet.
%!  oaa_data_query(?Clause, ?Owner) is nondet.
%
%   Solutions in storage order: prepended facts first, then the rest in the
%   order they were added.

oaa_data_query(Clause) :-
    oaa_data_query(Clause, _).

oaa_data_query(Clause, Owner) :-
    %  A bound clause narrows the search to its own solvable; an unbound one
    %  ranges over every stored fact.
    (   nonvar(Clause)
    ->  oaa_data_key(Clause, Key)
    ;   true
    ),
    findall(Seq-O-C, ordered_fact(Key, Seq, O, C), Facts0),
    sort(Facts0, Facts),
    member(_-Owner-Clause, Facts).

oaa_data_all(Clauses) :-
    findall(Seq-C, ordered_fact(_, Seq, _, C), Facts0),
    sort(Facts0, Facts),
    findall(C, member(_-C, Facts), Clauses).

%!  oaa_data_remove_owner(+Owner) is det.
%
%   Drop every fact created by Owner.  This is what runs when an agent goes
%   offline, so that a scheduling agent's view of a departed tasking agent's
%   requests disappears with it.

oaa_data_remove_owner(Owner) :-
    retractall(ordered_fact(_, _, Owner, _)).

oaa_data_clear :-
    retractall(ordered_fact(_, _, _, _)),
    retractall(fact_seq(_)),
    assertz(fact_seq(0)).
