##@ Infra (dev environment, from the workstation while tuning)

.PHONY: infra-init infra-plan infra-apply infra-check infra-output infra-destroy

infra-init: ## Initialize terraform/environments/dev (HCP backend, providers)
	@$(RUNNER) infra init

infra-plan: ## Preview the network and VM changes
	@$(RUNNER) infra plan

infra-apply: ## Create the network and the runner VM (asks for confirmation)
	@$(RUNNER) infra apply

infra-check: ## Check the VM runs with its ephemeral NVMe disk
	@$(RUNNER) infra check

infra-output: ## Show the IP, the ansible user and the NSG name
	@$(RUNNER) infra output

infra-destroy: ## Destroy the network and the VM (asks for confirmation)
	@$(RUNNER) infra destroy
