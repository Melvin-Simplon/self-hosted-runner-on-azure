##@ Bootstrap (run once from the workstation, after az login)

.PHONY: bootstrap-init bootstrap-plan bootstrap-apply bootstrap-output bootstrap-ssh-key

bootstrap-init: ## Initialize terraform/bootstrap (HCP backend, providers)
	@$(RUNNER) bootstrap init

bootstrap-plan: ## Preview the GitHub identity changes
	@$(RUNNER) bootstrap plan

bootstrap-apply: ## Create the GitHub identity (asks for confirmation)
	@$(RUNNER) bootstrap apply

bootstrap-output: ## Show the values to store as GitHub secrets
	@$(RUNNER) bootstrap output

bootstrap-ssh-key: ## Create the ansible SSH key and store it in GitHub
	@$(RUNNER) bootstrap ssh-key
