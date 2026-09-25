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

# shellcheck source=scripts/lib/core.sh
source "${RUNNER_ROOT}/scripts/lib/core.sh"
# shellcheck source=scripts/lib/ui.sh
source "${RUNNER_ROOT}/scripts/lib/ui.sh"
# shellcheck source=scripts/lib/bootstrap.sh
source "${RUNNER_ROOT}/scripts/lib/bootstrap.sh"
# shellcheck source=scripts/lib/lint.sh
source "${RUNNER_ROOT}/scripts/lib/lint.sh"

usage() {
    cat <<EOF
Usage: scripts/runner.sh [command]

  menu                       Interactive menu (default)
  bootstrap <action>         One-time setup: init, plan, apply, output, ssh-key
  lint                       shellcheck and terraform fmt check
  help                       Show this help
  version                    Show the version
EOF
}

# Phase not built yet: say so instead of showing a broken screen
handle_coming_soon() {
    ui_header "${1^^}"
    ui_line "${DIM}$1 is coming soon, it follows Bootstrap in the roadmap.${RESET}"
    press_enter_to_continue
}

main_loop() {
    local choice
    while true; do
        show_main_menu
        ui_prompt "Pick your move"
        read -r choice
        case "${choice}" in
            1) handle_bootstrap_menu ;;
            2) handle_coming_soon "Infra" ;;
            3) handle_coming_soon "Ansible" ;;
            4) handle_coming_soon "Benchmark" ;;
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
        bootstrap) bootstrap_cli "$@" ;;
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

main "$@"
