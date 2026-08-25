# Tutorial: a two-agent community from nothing

This tutorial builds `examples/basic/` by hand and explains each step. It
requires SWI-Prolog 9.x on the path and a clone of this repository as the
working directory.

## 1. A Facilitator

`bin/facilitator.pl` is generic, so no new code is needed. Start one and
write its address to a file so the next agents can find it without
hardcoding a port:

```sh
swipl bin/facilitator.pl -- -write_setup_file /tmp/oaa-tutorial/setup.pl &
```

## 2. An agent that offers a capability

```prolog
% square_agent.pl
:- use_module('src/agents/oaa_run').

run :-
    oaa_agent_start(square_agent,
                    [solvable(square(In, Out), [], [])],
                    []),
    oaa_agent_loop.

:- initialization(run, main).
```

`oaa_agent_start/3` connects to the facilitator named in `setup.pl` (found
via `oaa_config.pl`'s command-line → environment → setup-file precedence;
see [`communication.md`](communication.md)), registers the one solvable
declared, and returns. `oaa_agent_loop/0` then runs the library's event
loop indefinitely, dispatching incoming goals.

This agent declares `square(In, Out)` but never implements it. Running it
as-is and asking for `square(7, X)` fails because nothing answers the
callback. A solvable declaration is a promise the goal *shape* is handled;
the handling itself is a separate predicate, named by a `callback/1`
parameter on the solvable:

```prolog
:- use_module('src/agents/oaa_run').

solvables([ solvable(square(_X, _Y), [callback(square_of)], []) ]).

%   A callback receives the goal and its parameter list, and produces
%   solutions the way Prolog code always does: by binding and by
%   backtracking.  The library collects whatever the callback proves.
square_of(square(X, Y), _Params) :-
    number(X),
    Y is X * X.

run :-
    solvables(S),
    oaa_agent_run(square_agent, S, []).

:- initialization(run, main).
```

`oaa_agent_run/3` connects, registers and runs the loop in one call. These
are the same steps as in the two-file version above, without needing to name
`oaa_agent_loop` separately. This is `examples/basic/square_agent.pl`
exactly; nothing about it is simplified for the tutorial.

## 3. A requester

```prolog
% client.pl
:- use_module('src/agents/oaa_run').
:- use_module('src/agents/oaa_agent').

run :-
    oaa_agent_start(client, [], []),
    ( oaa_solve(square(7, X), [])
    -> format("square(7) = ~w~n", [X])
    ;  format("no answer~n", [])
    ),
    halt.

:- initialization(run, main).
```

Declaring no solvables is valid. The Developer's Guide explicitly
allows a pure requester. The client never names `square_agent`, its host, or
its port; it asks the Facilitator for a goal shape and gets an answer from
whichever agent(s) matched.

If the client can start before `square_agent` has finished registering, the
request above fails immediately. `oaa_Solve` asks who can answer *right now*;
it does not wait for an agent to become able to answer.
`examples/basic/client.pl` handles this by polling
`can_solve(square(1, _), _)` against the Facilitator
(`address(parent)`) before sending the request. The probe uses representative
bound arguments rather than a wholly unbound goal, since a solvable
declaring required argspecs won't match an unbound probe either (see
[`capability-registration.md`](capability-registration.md)).

## 4. Run it

```sh
swipl square_agent.pl -- &
swipl client.pl --
```

prints `square(7) = 49`.

## 5. Add a second provider of the same capability

Start a second agent declaring `square(In, Out)` too, with a different
`utility(N)`. Ask again: the higher-utility agent answers first, and if the
client backtracks (`findall(X, oaa_solve(square(7, X), []), Xs)` instead of
the single-solution form above) it collects an answer from both. This is the
default fan-out described in [`capability-registration.md`](capability-registration.md).

## 6. Where to go next

- Add a data solvable and watch a `data` trigger fire on it:
  [`data.md`](data.md), [`triggers.md`](triggers.md).
- Try a compound goal, `(square(7, X), square(X, Y))`; see [`delegation.md`](delegation.md).
- Add a `prioritize` meta-agent from `examples/multi-agent/preference_agent.pl`.
- Run the same client against a community with an LLM agent providing
    `interpret/2`; see [`llm-agents.md`](llm-agents.md).
