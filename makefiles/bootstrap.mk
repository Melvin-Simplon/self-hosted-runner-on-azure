##@ Bootstrap (run once from the workstation)

.PHONY: bootstrap-ssh-key

bootstrap-ssh-key: ## Create the ansible SSH key, kept on this machine
	@$(RUNNER) bootstrap ssh-key
