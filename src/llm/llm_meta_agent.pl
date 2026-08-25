/*  oaa-next -- LLM extension: a meta-agent that advises the Facilitator
 *
 *  Provenance: NEW / LLM EXTENSION.
 */

:- module(llm_meta_agent,
          [ llm_meta_main/0,
            llm_meta_solvables/1        % -Solvables
          ]).

:- use_module('../icl/icl_term').
:- use_module('../agents/oaa_run').
:- use_module('../agents/oaa_agent').
:- use_module(llm_config).
:- use_module(llm_provider).

/** <module> An LLM as a Facilitator meta-agent

OAA already had a place for judgement the Facilitator does not itself possess.
A meta-agent declares `meta(Type, +Goal, +Params, +FacInfo, -Result)` and is
consulted when the Facilitator is choosing between providers, or when nothing
it knows of can answer a goal.  The Developer's Guide describes such agents as
possibly incorporating learning algorithms, neural networks, expert systems,
rulebases or user preferences.  A language model is one more of those.

Two properties of the historical design make this safe, and both predate any
thought of an LLM:

  * The hook is *optional*.  A community with no meta-agent works.
  * The hook is *fallible*.  A meta-agent that returns nothing usable leaves
    the Facilitator's own deterministic ordering standing.

So an LLM here can only improve a choice the Facilitator was already prepared
to make on its own.  It cannot become load-bearing, and it cannot be the only
route to an answer.
*/

llm_meta_solvables([ solvable(meta(prioritize, _Goal, _Params, _FacInfo, _Result),
                              [callback(llm_meta_agent:prioritize)], []) ]).

llm_meta_main :-
    llm_require_enabled,
    llm_meta_solvables(S),
    oaa_agent_run(llm_meta_agent, S, []).

%   Given the Facilitator's own ordering, ask the model for a better one.  A
%   reply that is not a permutation of the candidates is discarded rather than
%   repaired: the Facilitator's ordering is a perfectly good answer, and a
%   fabricated agent id is not.

prioritize(meta(prioritize, Goal, _Params, FacInfo, Result), _EvParams) :-
    is_list(FacInfo),
    FacInfo \== [],
    icl_term_string(Goal, GoalStr),
    format(atom(CandidateStr), "~w", [FacInfo]),
    format(atom(Prompt),
"A request has arrived that several agents can answer.

Goal: ~w
Candidate agent ids, in the order the facilitator would try them: ~w

Reply with the ids in the order you would try them, as a comma-separated \c
list and nothing else. Use only the ids listed. If you have no reason to \c
prefer a different order, reply with the list unchanged.",
           [GoalStr, CandidateStr]),
    Messages = [ message(system, "You advise an agent facilitator on which \c
provider to try first. Answer with ids only."),
                 message(user, Prompt) ],
    llm_complete(Messages, [max_tokens(256)], Response),
    llm_response_text(Response, Text),
    parse_order(Text, FacInfo, Result).

parse_order(Text, Candidates, Order) :-
    text_to_string(Text, S),
    split_string(S, ",", " \t\n[]", Parts),
    findall(Id,
            ( member(P, Parts),
              P \== "",
              catch(number_string(Id, P), _, fail),
              memberchk(Id, Candidates) ),
            Order0),
    Order0 \== [],
    %  Every candidate has to survive, or a provider would be silently
    %  dropped by an advisory hook.
    subtract(Candidates, Order0, Missing),
    append(Order0, Missing, Order).
