# The Agent Development Toolkit

The historical ADT (Martin, Cheyer & Lee, PAAM'96) is the set of tools built
around the agent library rather than into it: something to generate a new
agent's boilerplate, watch a community's traffic, poke it interactively, and
launch it as a unit. `oaa-next` reconstructs each role from the Developer's
Guide and FAQ description of what it did, since the PAAM'96 paper itself has
not yet been retrieved (tracked as `partial` provenance in
[`../../research/compatibility-matrix.md`](../../research/compatibility-matrix.md)).

| Tool | Runs as | Role |
|---|---|---|
| Generator | `bin/oaa-new-agent.pl` | Scaffolds a new agent's boilerplate from a name and a solvable list |
| Shell | `bin/oaa-shell.pl` | Command-line access to a community: type a goal, get its solutions |
| Debug | `bin/oaa-debug.pl` | Sends ICL to the community or to one named agent |
| Start-It | `bin/oaa-startit.pl` | Launches a community from a description file, ensures every agent connects, restarts failures |
| Monitor | `bin/oaa-monitor.pl` | Displays a community and its traffic |

## Generator

```sh
swipl bin/oaa-new-agent.pl -- my_agent path/to/my_agent.pl
```

Writes a runnable agent skeleton — `use_module` lines, an `oaa_agent_start`
call with a solvable list, and a stub handler per declared goal — so that
starting a new agent means filling in behaviour, not copying boilerplate by
hand. `new_agent/3` in `src/adt/oaa_new_agent.pl` is the underlying
predicate.

## Shell

An interactive REPL that connects as an ordinary client and turns each line
typed at it into an `oaa_Solve`, printing whatever solutions come back —
`shell_solve/2` in `src/adt/oaa_shell.pl`. This is command-line access to
the community in the sense the FAQ describes; it is not a Prolog top-level,
so it accepts ICL, not arbitrary Prolog.

## Debug

Sends a single ICL goal or event, either to the community at large (through
the Facilitator) or to one named agent, and reports what it gets back.
Historically shipped in both Java and C builds; here it is one Prolog REPL
(`debug_main/0` / `debug_loop/0` in `src/adt/oaa_debug.pl`). The historical
tool could also send natural-language messages for an NL-capable community
to interpret; that capability is left to whatever NL or LLM agent is present
in the community, exactly as it was historically — Debug itself does no
language processing.

## Start-It

Reads a community description (a Prolog file listing the Facilitator and
its agents, in the same shape `tests/integration/community.pl` uses to drive
the test suite) and launches each as its own process, waiting for the
Facilitator's setup file to appear before starting clients so every agent
finds it (`startit_run/1` in `src/adt/oaa_startit.pl`). This is the
programmatic form of what the shell examples in [`facilitator.md`](facilitator.md)
do by hand with `&`.

## Monitor

Displays a running community and records its communications. There is no
graphical framework carried over from the historical Java/C builds, so
Monitor here is a terminal display; the substance — learning the community
by querying `agent_data/6` and watching traffic — is preserved by installing
a `comm` trigger on the Facilitator and printing what passes
(`monitor_main/0` in `src/adt/oaa_monitor.pl`). See [`triggers.md`](triggers.md)
for what a comm trigger sees and doesn't.

## What's left

The PAAM'96 paper describing the ADT in SRI's own words would sharpen a few
details (whether the historical generator did anything beyond scaffolding,
for instance) but nothing here waits on it — the four roles above are well
enough attested by the Developer's Guide and FAQ to reconstruct
independently.
