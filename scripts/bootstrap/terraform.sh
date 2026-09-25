#!/usr/bin/env bash
# Runs one Terraform action on terraform/bootstrap, with the Azure environment loaded.
# Usage: scripts/bootstrap/terraform.sh <init|plan|apply|output>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly TF_DIR="${SCRIPT_DIR}/../../terraform/bootstrap"

# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/../lib.sh"

usage() {
    printf 'Usage: %s <init|plan|apply|output>\n' "$(basename "$0")" >&2
}

validate_action() {
    case "$1" in
        init | plan | apply | output) ;;
        *)
            log_err "unknown action: $1"
            usage
            exit 2
            ;;
    esac
}

run_terraform() {
    local action="$1"
    log_step "Bootstrap: terraform ${action}"
    if terraform -chdir="${TF_DIR}" "${action}"; then
        log_ok "terraform ${action} succeeded"
    else
        log_err "terraform ${action} failed"
        exit 1
    fi
}

main() {
    if (($# != 1)); then
        usage
        exit 2
    fi
    validate_action "$1"
    # shellcheck source=scripts/bootstrap/env.sh
    source "${SCRIPT_DIR}/env.sh"
    run_terraform "$1"
}

main "$@"
