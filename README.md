## Self Hosted Runner On Azure

A GitHub Actions runner on your own Azure VM: Terraform creates the VM, Ansible registers it with your organization or repository, and the toolkit measures how long your pipelines take on it.

### Set up your own runner

Prerequisites: `az`, `terraform`, `ansible`, `gh` and `jq`, an Azure resource group you can deploy into, and an [HCP Terraform](https://app.terraform.io) organization for the state.

1. Fork or clone this repository, then `az login`, `gh auth login` and `terraform login`.
2. `make setup`: asks the four values of `.env` (resource group, HCP organization, runner target, PAT), picked from lists, checks the PAT, then offers to run every phase below.

The phases, also in the `make` menu:

1. `make bootstrap-init bootstrap-apply`: the Azure identity used by the CI of your copy.
2. `make bootstrap-ssh-key`: the SSH key Ansible uses to reach the VM.
3. `make infra-init infra-apply`: the network and the VM.
4. `make ansible-apply`: installs the runner and registers it with `GITHUB_RUNNER_URL`.

To fill `.env` by hand instead, copy `.env.example`: each value is explained there.

### Use it in a workflow

The runner does not serve this toolkit's repository, it serves the target picked in `make setup`: your project repository (personal or in an organization) or a whole organization. You need admin rights on that target. Then any repository covered by `GITHUB_RUNNER_URL` can send jobs to the runner:

```yaml
jobs:
  build:
    runs-on: [self-hosted, Linux, X64]
```

With an organization target, the default runner group refuses public repositories: their jobs wait in the queue forever. `make setup` offers to allow them (or the organization settings: Actions, Runner groups, Default, "Allow public repositories"). A pull request from a fork could then run on the VM, so guard each job:

```yaml
    if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository
```

### Change the target

Change `GITHUB_RUNNER_URL` (or run `make setup` again), then `make ansible-apply`: Ansible sees the runner is registered elsewhere, drops that registration and registers it with the new target. The old entry stays offline on its previous organization or repository, delete it in Settings, Actions, Runners, or GitHub removes it after 14 days.

### Benchmark

`make` then Benchmark: pick a repository, then one of its last runs.

- **Logs**: every job log of the run.
- **Metrics**: total CI duration to the millisecond, from the moment GitHub queues the job to the last line written by the runner. The GitHub API only has seconds, so the figure comes from the log archive of the run.

From the command line: `make bench-runs`, then `make bench-metrics RUN=<id>` or `make bench-logs RUN=<id>`, with `REPO=<owner/name>` for another repository.
