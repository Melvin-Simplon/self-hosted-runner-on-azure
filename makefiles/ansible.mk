##@ Ansible (configure the runner VM, SSH opens for your IP only)

.PHONY: ansible-ping ansible-check ansible-apply

ansible-ping: ## Check Ansible can reach the VM
	@$(RUNNER) ansible ping

ansible-check: ## Dry run of site.yml: show what would change, change nothing
	@$(RUNNER) ansible check

ansible-apply: ## Apply site.yml to the VM
	@$(RUNNER) ansible apply
