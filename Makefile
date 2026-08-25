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

# ---------------------------------------------------------------------------
# Office demo — launches the full community (facilitator + 4 agents) and
# opens the browser UI.  Ctrl-C in this terminal tears everything down.
# ---------------------------------------------------------------------------

.PHONY: demo

demo:
	@echo "Starting the Office Assistant demo..."
	@$(SWIPL) bin/facilitator.pl -- -write_setup_file setup.pl &
	@sleep 1
	@$(SWIPL) examples/multi-agent/office_mail_agent.pl &
	@$(SWIPL) examples/multi-agent/office_telephone_agent.pl &
	@$(SWIPL) examples/llm/office_assistant.pl -- -oaa_mode OAA_LLM &
	@sleep 1
	@$(SWIPL) examples/multi-agent/office_ui_agent.pl
	@# When the UI agent exits (Ctrl-C), clean up background jobs:
	@kill %4 %3 %2 %1 2>/dev/null || true
	@rm -f setup.pl

# ---------------------------------------------------------------------------
# LLM examples — run a complete temporary community and clean it up when the
# client finishes. Set LLM_MODEL to override the provider's default model.
# ---------------------------------------------------------------------------

.PHONY: llm-openai llm-anthropic _llm-community

llm-openai:
	@if [ -z "$$OPENAI_API_KEY" ] && [ -z "$$LLM_BASE_URL" ]; then \
		echo "Set OPENAI_API_KEY (or LLM_BASE_URL for a local endpoint)."; exit 1; \
	fi
	@$(MAKE) --no-print-directory _llm-community LLM_PROVIDER=openai \
		LLM_MODEL="$${LLM_MODEL:-gpt-4o-mini}"

llm-anthropic:
	@if [ -z "$$ANTHROPIC_API_KEY" ]; then \
		echo "Set ANTHROPIC_API_KEY."; exit 1; \
	fi
	@$(MAKE) --no-print-directory _llm-community LLM_PROVIDER=anthropic \
		LLM_MODEL="$${LLM_MODEL:-claude-opus-5}"

_llm-community:
	@set -eu; \
	pids=""; \
	cleanup() { \
		if [ -n "$$pids" ]; then kill $$pids 2>/dev/null || true; fi; \
		rm -f setup.pl; \
	}; \
	trap cleanup EXIT INT TERM; \
	rm -f setup.pl; \
	$(SWIPL) bin/facilitator.pl -- -write_setup_file setup.pl & pids="$$pids $$!"; \
	sleep 1; \
	$(SWIPL) examples/basic/square_agent.pl & pids="$$pids $$!"; \
	$(SWIPL) examples/basic/greet_agent.pl & pids="$$pids $$!"; \
	echo "Starting $(LLM_PROVIDER) LLM agent with model $(LLM_MODEL)"; \
	OAA_MODE=OAA_LLM $(SWIPL) bin/oaa-llm-agent.pl -- \
		-llm_provider "$(LLM_PROVIDER)" -llm_model "$(LLM_MODEL)" \
		& pids="$$pids $$!"; \
	sleep 1; \
	$(SWIPL) examples/llm/llm_client.pl
