/*  oaa-next -- test runner
 *
 *  Usage:  swipl -q -g run -t 'halt(1)' tests/run.pl
 *      or: make test
 */

:- initialization(main, main).

suite('tests/icl/test_icl.pl').
suite('tests/agents/test_solvable.pl').
suite('tests/runtime/test_com.pl').
suite('tests/runtime/test_event.pl').
suite('tests/facilitator/test_delegate.pl').
suite('tests/integration/test_community.pl').

main(_Argv) :-
    forall(suite(F), ensure_loaded(F)),
    (   run_tests
    ->  halt(0)
    ;   halt(1)
    ).
