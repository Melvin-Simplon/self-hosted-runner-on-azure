#!/usr/bin/env bash
# lib/lint.sh: shellcheck on every script, terraform fmt on every module.

if [[ -n "${RUNNER_LINT_LOADED:-}" ]]; then
    return 0
fi
RUNNER_LINT_LOADED=1

lint_shell() {
    log_step "Lint: shell scripts"
    require_cmd shellcheck || return 1
    local -a scripts
    mapfile -t scripts < <(find "${RUNNER_ROOT}/scripts" "${RUNNER_ROOT}/runner.sh" -name '*.sh' | sort)
    # Run from the root: the `# shellcheck source=scripts/...` paths are relative to it
    if (cd "${RUNNER_ROOT}" && shellcheck -x "${scripts[@]}"); then
        log_ok "shellcheck passed on ${#scripts[@]} scripts"
    else
        log_err "shellcheck found issues"
        return 1
    fi
}

lint_terraform() {
    log_step "Lint: Terraform formatting"
    require_cmd terraform || return 1
    if terraform fmt -check -recursive "${RUNNER_ROOT}/terraform"; then
        log_ok "terraform fmt passed"
    else
        log_err "files above are not formatted, run: terraform fmt -recursive terraform"
        return 1
    fi
}

# Runs every check even if one fails, to report everything in one pass
run_lint() {
    local failed=0
    lint_shell || failed=1
    lint_terraform || failed=1
    return "${failed}"
}
