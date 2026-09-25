##@ Bootstrap (run once from the workstation, after az login)

.PHONY: bootstrap-init bootstrap-plan bootstrap-apply bootstrap-output

bootstrap-init: ## Initialize terraform/bootstrap (HCP backend, providers)
	@scripts/bootstrap/terraform.sh init

bootstrap-plan: ## Preview the GitHub identity changes
	@scripts/bootstrap/terraform.sh plan

bootstrap-apply: ## Create the GitHub identity (asks for confirmation)
	@scripts/bootstrap/terraform.sh apply

bootstrap-output: ## Show the values to store as GitHub secrets
	@scripts/bootstrap/terraform.sh output
