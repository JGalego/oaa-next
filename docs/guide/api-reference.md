# API reference

Every exported predicate, by module. Signatures are the module's own
declared modes (`+` input, `-` output, `?` either). Prose explanation of
*why* lives on the topic pages this reference links back to; this page is
for looking up a name.

## `src/agents/oaa.pl` — OAA 2.3.2 compatibility facade

This module preserves the historical public names and arities. See
[`classic-compatibility.md`](classic-compatibility.md).

| Area | Predicates |
|---|---|
| ICL | `icl_GetParamValue/2`, `icl_GetNestedParamValue/3`, `icl_GetPermValue/2`, `icl_BasicGoal/1`, `icl_GoalComponents/4`, `icl_ConsistentParams/2`, `icl_BuiltIn/1`, `icl_ConvertSolvables/2` |
| Lifecycle | `oaa_LibraryVersion/1`, `oaa_Connect/4`, `oaa_SetupCommunication/1`, `oaa_Register/4`, `oaa_Disconnect/2`, `oaa_Ready/1`, `oaa_MainLoop/1`, `oaa_SetTimeout/1` |
| Callbacks/events | `oaa_RegisterCallback/2`, `oaa_ResolveVariables/1`, `oaa_GetEvent/4`, `oaa_ProcessEvent/2`, `oaa_Interpret/2`, `oaa_PostEvent/2` |
| Solving | `oaa_Solve/1,2`, `oaa_CanSolve/2`, `oaa_Version/3`, `oaa_Ping/3` |
| Declarations | `oaa_Declare/5`, `oaa_Undeclare/3`, `oaa_Redeclare/3` |
| Data | `oaa_AddData/2`, `oaa_RemoveData/2`, `oaa_ReplaceData/3`, `oaa_LoadData/2`, `oaa_SaveData/2` |
| Triggers | `oaa_CheckTriggers/3`, `oaa_AddTrigger/4`, `oaa_RemoveTrigger/4` |
| Delayed solutions | `oaa_DelaySolution/1`, `oaa_ReturnDelayedSolutions/2`, `oaa_AddDelayedContextParams/3` |
| Cache | `oaa_InCache/2`, `oaa_AddToCache/2`, `oaa_ClearCache/0` |
| Diagnostics | `oaa_TraceMsg/2`, `oaa_ComTraceMsg/3`, `oaa_Inform/3` |
| Identity/sequencing | `oaa_Address/3`, `oaa_PrimaryAddress/1`, `oaa_Name/1`, `oaa_LastSeqNum/2`, `oaa_SupportsSequenceNumbers/1`, `oaa_SeqNumLessThan/2` |

## `src/icl/icl_term.pl` — terms

| Predicate | Signature | Notes |
|---|---|---|
| `icl_parse_term/2,3` | `+Text, -Term[, +Options]` | Parse one ICL term |
| `icl_parse_terms/2` | `+Text, -Terms` | Parse a sequence |
| `icl_write/1,2` | `+Term[, +Options]` | Write a term, operator-aware |
| `icl_write_event/2` | `+Term, +Stream` | Write and terminate with the wire's framing period |
| `icl_term_string/2,3` | `+Term, -String[, +Options]` | Round-trip through a string |
| `icl_term_equal/2` | `+A, +B` | Structural equality |
| `icl_term_variant/2` | `+A, +B` | Equal up to variable renaming |
| `icl_term_hash/2` | `+Term, -Hash` | Stable hash for indexing |
| `icl_matches/2` | `+Goal, +Template` | Unification-based solvable matching |
| `icl_match/3` | `+Goal, +Template, -Bound` | As above, returning the bound term |
| `icl_functor/3` | `+Term, -Name, -Arity` | Safe functor extraction (handles `[]`) |
| `icl_is_var/1`, `icl_is_ground/1` | `+Term` | Variable / groundness tests |
| `icl_disassemble_goal/4` | `+Full, ?Address, ?Goal, ?Params` | Split `Address:Goal::Params` |
| `icl_assemble_goal/4` | `?Address, ?Goal, ?Params, -Full` | Build `Address:Goal::Params` |

See [`icl.md`](icl.md).

## `src/icl/icl_params.pl` — parameter lists

| Predicate | Signature | Notes |
|---|---|---|
| `icl_get_param_value/2` | `+Pattern, +Params` | Look up, failing if absent |
| `icl_get_param_value/3` | `+Pattern, +Params, +Default` | As above, with a default |
| `icl_param_expand/2` | `+Params, -Expanded` | Expand boolean shorthand |
| `icl_param_set/3` | `+Param, +Params, -NewParams` | Set one parameter |
| `icl_param_merge/3` | `+Overrides, +Params, -Merged` | Merge, overrides winning |
| `icl_param_strip_defaults/3` | `+Defaults, +Params, -Stripped` | Elide defaults for the wire |
| `icl_param_apply_defaults/3` | `+Defaults, +Params, -Complete` | Reapply on receipt |

## `src/icl/icl_type.pl` — the type lattice

| Predicate | Signature | Notes |
|---|---|---|
| `icl_type_of/2` | `+Value, -TypeKey` | The most specific type of a value |
| `icl_subtype/2` | `?SubKey, ?SuperKey` | Lattice edges, incl. transitive |
| `icl_type_key/2` | `?TypeSpec, ?TypeKey` | Normalize a type spec to its key |
| `icl_conforms/2` | `+Value, +TypeSpec` | Does a value satisfy a type |
| `icl_conforms_argspec/2` | `+Value, +ArgSpec` | As above, against an `in/out/inout` spec |
| `icl_type_add/2`, `icl_type_remove/2` | `+SubKey, +SuperKey` | Extend the lattice |
| `icl_type_edges/1` | `-Edges` | The whole lattice, for inspection |

## `src/agents/oaa_solvable.pl` — solvables

| Predicate | Signature | Notes |
|---|---|---|
| `solvable_normalize/2` | `+Spec, -Solvable` | Any shorthand → canonical 3-arg form |
| `solvable_list/2` | `+SpecOrList, -Solvables` | Normalize a whole declaration list |
| `solvable_goal/2` | `+Solvable, -GoalTemplate` | |
| `solvable_type/2` | `+Solvable, -Type` | `procedure` / `data` / `trigger` |
| `solvable_utility/2` | `+Solvable, -Utility` | |
| `solvable_callback/2` | `+Solvable, -Callback` | |
| `solvable_param/2` | `+Solvable, ?Param` | |
| `solvable_permission/2` | `+Solvable, ?Permission` | |
| `solvable_is_private/1` | `+Solvable` | |
| `solvable_matches/2` | `+Goal, +Solvable` | |
| `solvable_match/3` | `+Goal, +Solvable, -Event` | |
| `solvable_default_params/1`, `solvable_default_perms/1` | `-Defaults` | |

See [`capability-registration.md`](capability-registration.md).

## `src/agents/oaa_agent.pl` — the agent library surface

| Predicate | Signature | Notes |
|---|---|---|
| `oaa_connect/2` | `+Params, -Address` | |
| `oaa_connect/4` | `+ConnId, +Address, +Name, +Params` | Connect and perform the OAA 2.3.2 handshake |
| `oaa_handshake/3` | `+ConnId, +Name, +Params` | Handshake an existing transport connection |
| `oaa_register/4` | `+ConnId, +Name, +Solvables, +Params` | |
| `oaa_ready/1` | `+ShouldPrint` | Send the historical ready transition |
| `oaa_disconnect/2` | `+ConnId, +Params` | Close and clear connection metadata |
| `oaa_declare/2`, `oaa_undeclare/2` | `+Solvables, +Params` | |
| `oaa_redeclare/3` | `+Solvable, +NewSolvable, +Params` | Atomic swap |
| `oaa_solvables/1` | `-Solvables` | This agent's own declarations |
| `oaa_solve/1,2` | `+Goal[, +Params]` | The one request entry point |
| `oaa_solve_local/2` | `+Goal, +Params` | Solve only against this agent's own solvables |
| `oaa_add_data/2`, `oaa_remove_data/2` | `+Clause, +Params` | |
| `oaa_replace_data/3` | `+Clause1, +Clause2, +Params` | Atomic |
| `oaa_name/1`, `oaa_local_id/1` | `-Name` / `-LocalId` | |
| `oaa_primary_address/1` | `-Address` | This agent's parent-facing address |
| `oaa_address/3` | `?ConnId, ?Kind, ?Address` | |
| `oaa_handle_event/2` | `+ConnId, +Event` | The library's dispatcher |
| `oaa_agent_reset/0` | | Test support: clear per-agent state |
| `oaa_next_goal_id/1` | `-GoalId` | |
| `oaa_delay_solution/1` | `+Id` | |
| `oaa_return_delayed_solutions/2` | `+Id, +Solutions` | |
| `oaa_add_delayed_context_params/3` | `+Id, +Params, -NewParams` | |
| `oaa_current_context/1` | `-Contexts` | |
| `oaa_setup_communication/1` | `+Params` | |
| `oaa_listener_address/1` | `-Address` | For direct connect |

See [`agents.md`](agents.md), [`tasking.md`](tasking.md).

## `src/agents/oaa_data.pl` — the data store

| Predicate | Signature | Notes |
|---|---|---|
| `oaa_data_add/4` | `+Owner, +Clause, +Params, -Ok` | |
| `oaa_data_remove/4` | `+Owner, +Clause, +Params, -Count` | |
| `oaa_data_replace/5` | `+Owner, +Clause1, +Clause2, +Params, -Ok` | |
| `oaa_data_query/1,2` | `?Clause[, ?Owner]` | |
| `oaa_data_all/1` | `-Clauses` | |
| `oaa_data_remove_owner/1` | `+Owner` | Ownership-based cleanup on disconnect |
| `oaa_data_clear/0` | | Test support |
| `oaa_data_key/2` | `+Clause, -Key` | Indexing key |

See [`data.md`](data.md).

## `src/agents/oaa_trigger.pl` — triggers

| Predicate | Signature | Notes |
|---|---|---|
| `oaa_add_trigger/4` | `+Type, +Condition, +Action, +Params` | |
| `oaa_remove_trigger/4` | `+Type, +Condition, +Action, +Params` | |
| `oaa_check_triggers/3` | `+Type, +Condition, +Params` | Application code fires a task trigger |
| `oaa_triggers/1` | `-Triggers` | |
| `oaa_trigger_clear/0` | | Test support |
| `oaa_note_data_change/2` | `+Operation, +Clause` | Data triggers hook here |
| `oaa_note_event/3` | `+Direction, +From, +Event` | Comm triggers hook here |
| `oaa_install_trigger/4` | `+Type, +Condition, +Action, +Params` | Local installation |
| `trigger_is_local/2` | `+Type, +Params` | |
| `oaa_fire_trigger/1` | `+Trigger` | |
| `oaa_replace_trigger_condition/2` | `+Trigger, +NewCondition` | |

See [`triggers.md`](triggers.md).

## `src/agents/oaa_time.pl` — ICL date/time

| Predicate | Signature | Notes |
|---|---|---|
| `icl_date_stamp/2` | `+IclDate, -UnixSeconds` | `date/6`, 1900/0-based, to Unix time |
| `icl_date_now/1` | `-IclDate` | |
| `icl_time_expr_due/3` | `+TimeExpr, +Now, -Due` | |
| `icl_recurrence_seconds/2` | `+Recurrence, -Seconds` | |
| `icl_time_expr_next/3` | `+TimeExpr, +Now, -NextExpr` | |

## `src/agents/oaa_run.pl` — starting an agent

| Predicate | Signature | Notes |
|---|---|---|
| `oaa_agent_start/3` | `+Name, +Solvables, +Options` | Connect and register, don't loop |
| `oaa_agent_run/3` | `+Name, +Solvables, +Options` | Start, then loop until disconnect |
| `oaa_agent_loop/0` | | Run with the agent library's handler installed |
| `oaa_agent_loop_once/0` | | One turn, agent's own handler — not `oaa_main_loop/1`'s default |

See [`tutorials.md`](tutorials.md).

## `src/facilitator/fac.pl` — the Facilitator process

| Predicate | Signature | Notes |
|---|---|---|
| `fac_start/1` | `+Options` | |
| `fac_stop/0` | | |
| `fac_main/0` | | |
| `fac_registry/1` | `-Registry` | |
| `fac_address/1` | `-Address` | |
| `fac_is_node/0` | | True if connected upward to a parent facilitator |

## `src/facilitator/fac_delegate.pl` — pure selection logic

| Predicate | Signature | Notes |
|---|---|---|
| `fac_candidates/3` | `+Goal, +Registry, -Candidates` | |
| `fac_order/2` | `+Candidates, -Ordered` | By descending utility, stable |
| `fac_select/5` | `+Goal, +Registry, +Params, +Requester, -Selected` | |
| `fac_meta_agents/3` | `+Registry, +Type, -Providers` | |
| `fac_dispatch_plan/4` | `+Selected, +Params, -Mode, -Batch` | |

## `src/facilitator/fac_compound.pl` — compound-goal walking

| Predicate | Signature | Notes |
|---|---|---|
| `is_compound_goal/1` | `+Goal` | |
| `goal_conjuncts/2` | `+Goal, -Conjuncts` | |
| `initial_branch/2` | `+Goal, -Branch` | |
| `branch_step/2` | `+Branch, -Action` | `solution` / `expand` / `dispatch` |
| `branch_advance/3` | `+Branch, +Solutions, -Branches` | Copies per solution |

See [`delegation.md`](delegation.md), [`facilitator.md`](facilitator.md).

## `src/runtime/com_tcp.pl` — transport

| Predicate | Signature | Notes |
|---|---|---|
| `com_connect/3` | `+ConnId, +Params, -Address` | |
| `com_listen_at/3` | `+ConnId, +Params, -Address` | |
| `com_accept/2` | `+ListenerId, -ConnId` | |
| `com_send/2` | `+ConnId, +Term` | |
| `com_read/2` | `+ConnId, -Term` | |
| `com_read_pending/2` | `+ConnId, -Terms` | |
| `com_poll/3` | `+ConnIds, +Timeout, -Ready` | |
| `com_close/1`, `com_close_all/0` | `+ConnId` | |
| `com_connection/2` | `?ConnId, ?Kind` | |
| `com_connections/1` | `-ConnIds` | |
| `com_address/2` | `?ConnId, ?Address` | |
| `com_is_listener/1` | `?ConnId` | |
| `com_frame/3` | `+Codes, -TermCodes, -Rest` | Period-framing with quote-state tracking |

The same module exports the historical aliases:

| Area | Predicates |
|---|---|
| Address/connect | `com_StandardizeAddress/2`, `com_Connect/3,4`, `com_Connected/4`, `com_ListenAt/3,4` |
| Send/select | `com_SendData/2`, `com_SelectEvent/2`, `com_write_term/1` |
| Connection metadata | `com_AddInfo/2`, `com_UpdateInfo/2`, `com_GetInfo/2`, `com_GetAllInfo/2`, `com_RecordAddressForId/2`, `com_AddressForId/2`, `com_ReportConnections/1` |
| Shutdown | `com_Disconnect/1`, `com_DisconnectWithFailure/1`, `com_ShutdownAll/0`, `com_Shutdown/1`, `com_TcpShutdown/1` |
| Wakeups | `com_ScheduleWakeup/2`, `com_CancelWakeup/2` |

## `src/runtime/oaa_event.pl` — the event loop

| Predicate | Signature | Notes |
|---|---|---|
| `oaa_enqueue/2,3` | `+ConnId, +Term[, +Priority]` | |
| `oaa_dequeue/3` | `-ConnId, -Term, -Priority` | |
| `oaa_dequeue_above/4` | `+MinPriority, -ConnId, -Term, -Priority` | Nested-wait interrupt admission |
| `oaa_queue_empty/0`, `oaa_queue_clear/0` | | |
| `oaa_flush_below/1` | `+Priority` | Backs `flush_events` — discards, doesn't run |
| `oaa_pump/1` | `+Timeout` | One turn: poll, accept, enqueue |
| `oaa_wait_for/3` | `+Pattern, +Timeout, -Term` | Nested blocking wait, priority-floor aware |
| `oaa_main_loop/1` | `+Options` | The library's own loop, given a handler |
| `oaa_register_callback/2` | `+Name, :Closure` | Module-qualified; see [`agents.md`](agents.md) |
| `oaa_unregister_callback/1` | `+Name` | |
| `oaa_callback/2` | `?Name, ?Closure` | |
| `oaa_set_timeout/1`, `oaa_get_timeout/1` | `+Seconds` / `-Seconds` | |

See [`communication.md`](communication.md), [`tasking.md`](tasking.md).

## `src/runtime/oaa_config.pl` — configuration

| Predicate | Signature | Notes |
|---|---|---|
| `oaa_resolve/2,3` | `+Name, -Value[, +Default]` | Command line → env → setup file |
| `oaa_load_setup_file/1` | `+File` | |
| `oaa_setup_fact/1` | `?Fact` | |
| `oaa_facilitator_address/1` | `-tcp(Host, Port)` | |
| `oaa_mode/1` | `-Mode` | `oaa_classic` / `oaa_llm` |
| `oaa_config_reset/0` | | Test support |

## `src/llm/` — the optional LLM extension

| Module | Predicate | Signature |
|---|---|---|
| `llm_config.pl` | `llm_enabled/0` | Succeeds iff `OAA_LLM` is active |
| | `llm_require_enabled/0` | Throws if not |
| | `llm_provider_name/1`, `llm_model/1` | `-Name` / `-Model` |
| | `llm_setting/2,3` | `+Key, -Value[, +Default]` |
| `llm_provider.pl` | `llm_complete/3,4` | `[+Provider, ]+Messages, +Options, -Response` |
| | `llm_register_provider/2` | `+Name, +Module` |
| | `llm_known_provider/2` | `?Name, ?Module` |
| | `llm_response_text/2` | `+Response, -Text` |
| `llm_agent.pl` | `llm_agent_main/0` | |
| | `llm_agent_solvables/1` | `-Solvables` |
| | `llm_interpret/3` | `+Request, +Params, -Result` |
| | `community_capabilities/1` | `-Capabilities` |
| | `icl_from_reply/2` | `+Text, -Goal` |
| `llm_meta_agent.pl` | `llm_meta_main/0`, `llm_meta_solvables/1` | |

See [`llm-agents.md`](llm-agents.md).

## `src/interop/` — interoperability adapters

| Module | Predicate | Signature |
|---|---|---|
| `icl_json.pl` | `icl_to_json/2`, `json_to_icl/2` | Lossless, tagged round trip |
| | `icl_to_plain_json/2`, `plain_json_to_icl/2` | Lossy, natural JSON |
| | `solvable_to_schema/2` | `+Solvable, -Schema` (JSON Schema) |
| `mcp_server.pl` | `mcp_server_main/0` | |
| | `mcp_handle/2` | `+Request, -Response` |
| | `mcp_tools/1` | `-Tools` |
| `a2a_bridge.pl` | `a2a_agent_card/1` | `-Card` |
| | `a2a_handle/2` | `+Request, -Response` |
| | `a2a_skill/2` | `+Solvable, -Skill` |

See [`modern-interoperability.md`](modern-interoperability.md).

## `src/adt/` — the Agent Development Toolkit

| Module | Predicate | Signature |
|---|---|---|
| `oaa_new_agent.pl` | `new_agent_main/0`, `new_agent/3` | `+Name, +File, +Options` |
| `oaa_shell.pl` | `shell_main/0`, `shell_solve/2` | `+GoalText, +Options` |
| `oaa_debug.pl` | `debug_main/0`, `debug_loop/0` | |
| `oaa_startit.pl` | `startit_main/0`, `startit_run/1`, `startit_stop/0` | `+CommunityFile` |
| `oaa_monitor.pl` | `monitor_main/0` | |

See [`adt.md`](adt.md).
