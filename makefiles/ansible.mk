##@ Ansible (configure the runner VM, SSH opens for your IP only)

.PHONY: ansible-ping

ansible-ping: ## Check Ansible can reach the VM
	@$(RUNNER) ansible ping
