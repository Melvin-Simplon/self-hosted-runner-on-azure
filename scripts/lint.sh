#!/usr/bin/env bash
# Lints the shell scripts and checks the Terraform formatting.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

# shellcheck source=scripts/lib.sh
source "${ROOT_DIR}/scripts/lib.sh"

lint_shell() {
    log_step "Lint: shell scripts"
    local scripts
    mapfile -t scripts < <(find "${ROOT_DIR}/scripts" -name '*.sh' | sort)
    if shellcheck -x "${scripts[@]}"; then
        log_ok "shellcheck passed on ${#scripts[@]} scripts"
    else
        log_err "shellcheck found issues"
        return 1
    fi
}

lint_terraform() {
    log_step "Lint: Terraform formatting"
    if terraform fmt -check -recursive "${ROOT_DIR}/terraform"; then
        log_ok "terraform fmt passed"
    else
        log_err "files above are not formatted, run: terraform fmt -recursive terraform"
        return 1
    fi
}

main() {
    local failed=0
    lint_shell || failed=1
    lint_terraform || failed=1
    return "${failed}"
}

main "$@"
