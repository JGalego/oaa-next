/*  oaa-next -- test runner
 *
 *  Usage:  swipl -q -g run -t 'halt(1)' tests/run.pl
 *      or: make test
 */

:- initialization(main, main).

suite('tests/icl/test_icl.pl').
suite('tests/agents/test_solvable.pl').
suite('tests/agents/test_trigger.pl').
suite('tests/agents/test_data.pl').
suite('tests/runtime/test_com.pl').
suite('tests/runtime/test_event.pl').
suite('tests/runtime/test_config.pl').
suite('tests/facilitator/test_delegate.pl').
suite('tests/integration/test_community.pl').
suite('tests/integration/test_meta.pl').
suite('tests/integration/test_timing.pl').
suite('tests/integration/test_hierarchy.pl').
suite('tests/integration/test_direct.pl').
suite('tests/integration/test_adt.pl').
suite('tests/llm/test_isolation.pl').
suite('tests/llm/test_llm_agent.pl').
suite('tests/llm/test_llm_community.pl').
suite('tests/llm/test_office_demo.pl').
suite('tests/interop/test_interop.pl').
suite('tests/interop/test_mcp_live.pl').
suite('tests/compatibility/test_conformance.pl').

main(_Argv) :-
    forall(suite(F), ensure_loaded(F)),
    (   run_tests
    ->  halt(0)
    ;   halt(1)
    ).
