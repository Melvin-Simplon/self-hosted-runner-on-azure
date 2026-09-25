##@ Toolkit

.PHONY: help targets lint

help: ## Open the interactive menu (default)
	@$(RUNNER) menu

targets: ## List the make targets
	@scripts/help.sh $(MAKEFILE_LIST)

lint: ## Run shellcheck and terraform fmt check
	@$(RUNNER) lint
