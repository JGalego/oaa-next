# OAA 2.3.2 classic compatibility

`OAA_CLASSIC` targets the observable Prolog/TCP behavior of SRI OAA 2.3.2
build 02. Compatibility covers the historical Prolog public API, the ASCII
ICL wire protocol, connection lifecycle, full OAA addresses, registration,
delegation, data and trigger updates, and the Facilitator behavior exercised
by the recovered sources and tests.

## Historical Prolog API

`src/agents/oaa.pl` is the source-compatibility facade. It exports the
historical mixed-case predicates and arities, including `oaa_Connect/4`,
`oaa_Register/4`, `oaa_Declare/5`, `oaa_Solve/1,2`, data persistence,
triggers, delayed solutions, cache operations, event access, identity,
version, ping, tracing, and sequence-number queries. Existing code may use:

```prolog
:- use_module('src/agents/oaa').
:- use_module('src/runtime/com_tcp').

start :-
    com_Connect(parent, [], _Address, _Actual),
    oaa_Register(parent, my_agent, [hello(_)], []),
    oaa_RegisterCallback(app_do_event, user:oaa_AppDoEvent),
    oaa_MainLoop(true).
```

The lower-case API remains available for new code. The two surfaces share one
implementation; classic mode is not a separate emulator.

Procedure solvables without a `callback/1` declaration use the historical
`app_do_event` callback. This is important for unchanged OAA 2.x agents,
which normally declared a goal shape and implemented that goal in
`oaa_AppDoEvent/2`.

`src/runtime/com_tcp.pl` likewise exports both the modern transport predicates
and the historical `com_` surface: `com_Connect`, `com_ListenAt`,
`com_SendData`, `com_SelectEvent`, connection-info access, shutdown, address,
and wakeup operations.

## Wire protocol

Every conversational message is encoded on TCP as:

```text
event(Content, EventParams).
```

The first exchange is the OAA 2.3.2 handshake:

```text
client -> facilitator: event(ev_connect(ClientInfo), []).
client <- facilitator: event(ev_connected(FacilitatorInfo), []).
```

`FacilitatorInfo` contains the client's assigned `oaa_address`, the
Facilitator's `other_address`, identity, language, dialect, version, and
format. Registration then uses
`ev_register_solvables(Mode, Solvables, Name, Params)`, and `ev_ready(Name)`
changes the registry status from `open` to `ready`.

Externally visible identities are full addresses:
`addr(tcp(Host, Port), LocalId)` for clients and `addr(tcp(Host, Port))` for a
Facilitator. Integer local IDs remain internal to the reconstructed
Facilitator.

The data-update reply has the historical argument order:

```text
ev_data_updated(GoalId, Mode, Clause, Params, Requestees, Updaters)
```

Trigger-update replies similarly place `Params` before `Requestees` and
`Updaters`. Password and unique-name rejection are handled during
`ev_connect`.

## Verification

The compatibility suite contains two complementary live tests:

1. A raw TCP client writes the historical `event/2` envelope directly,
   handshakes, registers, becomes ready, and solves a Facilitator goal.
2. A separate SWI-Prolog process uses the historical predicate names and
   startup order (`com_Connect` followed by `oaa_Register`) without using the
   lower-case convenience API.

These run alongside the live multi-process community, hierarchy,
direct-connect, data, trigger, timing, ADT, LLM-isolation, MCP, and A2A tests
under `make test`.

## Compatibility boundary

Classic parity is behavioral and source-level for the OAA 2.3.2 Prolog/TCP
surface. It does not mean:

- binary ABI compatibility with the historical C shared library;
- a replacement Java, C, .NET, or WebL language binding;
- SICStus or Quintus bytecode compatibility (the implementation runs on
  SWI-Prolog 9+);
- pixel-identical Java Swing Monitor or Start-It applications; or
- OAA 1.x event translation through the historical `translations.pl` layer.

Those distribution artifacts are separate from the classic architecture and
protocol. A non-Prolog client can interoperate by implementing the documented
OAA 2.3.2 ICL/TCP protocol, but language-specific API bindings are not shipped.

The recovered 2.3.2 library contains heartbeat and sequence code gated on a
peer version of at least `[2,3,3]`, while `oaa_LibraryVersion/1` reports
`[2,3,2]`. Consequently two 2.3.2 peers do not negotiate sequencing;
`oaa_SupportsSequenceNumbers/1` correctly fails for this compatibility target.
The heartbeat request and reply events are nevertheless accepted.

Only the `lookup` and `prioritize` meta-agent types are executable in the
recovered 2.3.2 Facilitator source. `plan_query` and `execute_plan` are design
concepts described in documentation, not missing executable 2.3.2 behavior.
