##@ Tooling

.PHONY: help lint

help: ## Show this help
	@scripts/help.sh $(MAKEFILE_LIST)

lint: ## Run shellcheck and terraform fmt check
	@scripts/lint.sh
