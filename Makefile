# oaa-next
#
# Phase 1 targets.  Everything here runs in OAA_CLASSIC mode; there is no LLM
# dependency anywhere in the core and no target that would introduce one.

SWIPL ?= swipl

.PHONY: test check clean

test:
	@$(SWIPL) -q -g "true" -t "halt" tests/run.pl

# Load every source module to catch syntax and dependency errors without
# running the suite.
check:
	@$(SWIPL) -q -g "forall(member(F,['src/icl/icl_lex','src/icl/icl_parse','src/icl/icl_write','src/icl/icl_type','src/icl/icl_term']), use_module(F)), writeln('all modules load')" -t halt

clean:
	@find . -name '*.qlf' -delete
