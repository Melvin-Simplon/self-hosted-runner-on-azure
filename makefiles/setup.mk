##@ Setup (start here: asks the .env values, then runs every phase)

.PHONY: setup

setup: ## Guided setup, values picked from lists
	@$(RUNNER) setup
