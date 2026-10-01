# Project brief

## Assignment

> Provision an Azure VM with Terraform, configure it as a self-hosted GitHub Actions runner (and optionally a GitLab CI runner) with Ansible, then switch an existing pipeline to it to measure the real gain compared to a hosted runner.
>
> The whole lifecycle (provisioning, configuration, execution) must be driven from GitHub Actions/GitLab CI: no manual command from the candidate's workstation apart from the initial setup.

## Goals

1. **Provision** a Linux VM on Azure with **Terraform**.
2. **Configure** this VM as a **self-hosted GitHub Actions** runner with **Ansible**.
3. **Optional**: also register it as a **GitLab CI** runner.
4. **Switch** an existing pipeline to this runner.
5. **Measure** the real gain against a hosted runner (`ubuntu-latest` on GitHub, SaaS runners on GitLab).

## Main constraint: everything goes through CI

Provisioning, configuration and execution are **triggered by pipelines**, never from the local workstation.

The only allowed exception is the **initial setup**. For example:

- create the remote Terraform state storage;
- create the Azure identity used by the CI (OIDC preferred);
- declare the repository secrets.

Everything done by hand must be **documented** so it stays reproducible.

## Suggested breakdown

This breakdown is an organisation proposal, it is not part of the assignment.

1. **Bootstrap** (`terraform/bootstrap/`): remote state backend and CI identity. The only manual step.
2. **Infrastructure** (`terraform/modules/`, `terraform/environments/dev/`): network, NSG, runner VM. Plan on PR, apply on `main` through a workflow.
3. **Configuration** (`ansible/`): `common` role (hardening, packages), `github_runner` role, optional `gitlab_runner` role. Run by a workflow after the apply.
4. **Reference pipeline** (`app/`): a project whose pipeline first runs on a hosted runner, then on the self-hosted runner.
5. **Benchmark** (`benchmark/`, `docs/benchmark/`): same pipeline, several runs on each runner, comparison with figures.
6. **Teardown**: a dedicated workflow to destroy the infrastructure and keep Azure costs under control.

## What to measure

- **Total duration** of the pipeline.
- **Duration per step** (checkout, dependency install, build, tests).
- **Cache effect**: first cold run, then the following runs.
- **Queue time** before the job is picked up.
- **Cost**: price of the Azure VM compared to the billed minutes of the hosted runner.

There must be **enough runs** for the comparison to be credible (mean and median, not a single attempt).

## Points of attention

- **No secrets** in the repository: GitHub/GitLab secrets, Ansible Vault or Azure Key Vault.
- **Public repository**: a self-hosted runner on a public repository can run the code of an external PR. Restrict the workflows that target this runner.
- **SSH access** to the VM restricted (tight NSG, key only).
- **Idempotence**: running Terraform and Ansible again must not break anything.

## Expected deliverables

- Versioned Terraform and Ansible code.
- CI workflows covering provisioning, configuration, execution and teardown.
- Benchmark report with raw figures and analysis.
- Documentation of the initial setup.
