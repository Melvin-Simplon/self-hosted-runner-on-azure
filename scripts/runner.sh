#!/usr/bin/env bash
# Runner on Azure: toolkit entry point.
# No argument opens the interactive menu, a subcommand runs one action and exits.
# -e deliberately omitted: a failing action must bring the menu back, not kill it.
set -uo pipefail

RUNNER_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly RUNNER_ROOT
readonly RUNNER_VERSION="0.1.0"

: "${LOG_FILE:=${RUNNER_ROOT}/.logs/runner.log}"
export LOG_FILE
# Settings of this runner (Azure, HCP Terraform, GitHub target, PAT), ignored by git, see .env.example
: "${ENV_FILE:=${RUNNER_ROOT}/.env}"
# Key of the ansible sudo account, shared by the bootstrap and infra modules
: "${ANSIBLE_SSH_KEY_FILE:=${HOME}/.ssh/runner-azure-ansible}"

# shellcheck source=scripts/lib/core.sh
source "${RUNNER_ROOT}/scripts/lib/core.sh"
# terraform reads it for every command on the HCP backend (init, plan, output...), not a secret
TF_CLOUD_ORGANIZATION="${TF_CLOUD_ORGANIZATION:-$(env_value TF_CLOUD_ORGANIZATION)}"
export TF_CLOUD_ORGANIZATION

# shellcheck source=scripts/lib/ui.sh
source "${RUNNER_ROOT}/scripts/lib/ui.sh"
# shellcheck source=scripts/lib/bootstrap.sh
source "${RUNNER_ROOT}/scripts/lib/bootstrap.sh"
# shellcheck source=scripts/lib/infra.sh
source "${RUNNER_ROOT}/scripts/lib/infra.sh"
# shellcheck source=scripts/lib/ansible.sh
source "${RUNNER_ROOT}/scripts/lib/ansible.sh"
# shellcheck source=scripts/lib/benchmark.sh
source "${RUNNER_ROOT}/scripts/lib/benchmark.sh"
# shellcheck source=scripts/lib/setup.sh
source "${RUNNER_ROOT}/scripts/lib/setup.sh"
# shellcheck source=scripts/lib/lint.sh
source "${RUNNER_ROOT}/scripts/lib/lint.sh"

usage() {
    cat <<EOF
Usage: scripts/runner.sh [command]

  menu                       Interactive menu (default)
  setup                      Guided setup: asks the .env values, then runs every phase
  bootstrap <action>         One-time setup: init, plan, apply, output, ssh-key
  infra <action>             Dev environment: init, plan, apply, check, output, destroy
  ansible <action>           Configure the VM: ping, check, apply
  benchmark <action> [id]    runs, then logs or metrics of run <id> (default: last completed)
  lint                       shellcheck and terraform fmt check
  help                       Show this help
  version                    Show the version
EOF
}

main_loop() {
    while true; do
        show_main_menu
        ui_ask "Pick your move"
        case "${REPLY}" in
            1)
                run_setup
                press_enter_to_continue
                ;;
            2) handle_bootstrap_menu ;;
            3) handle_infra_menu ;;
            4) handle_ansible_menu ;;
            5) handle_benchmark_menu ;;
            9)
                run_lint
                press_enter_to_continue
                ;;
            0)
                ui_line
                ui_line "${DIM}Bye.${RESET}"
                return 0
                ;;
            *) ui_invalid_choice ;;
        esac
    done
}

main() {
    local cmd="${1:-menu}"
    shift || true
    case "${cmd}" in
        menu) main_loop ;;
        setup) run_setup ;;
        bootstrap) bootstrap_cli "$@" ;;
        infra) infra_cli "$@" ;;
        ansible) ansible_cli "$@" ;;
        benchmark) benchmark_cli "$@" ;;
        lint) run_lint ;;
        help | -h | --help) usage ;;
        version | -v | --version) printf 'runner.sh %s\n' "${RUNNER_VERSION}" ;;
        *)
            log_err "unknown command: ${cmd}"
            usage >&2
            return 2
            ;;
    esac
}

# exit on the same line: bash reads a script as it runs, so a script edited while the menu
# is open would otherwise be read again from a shifted offset after main returns
main "$@"; exit
