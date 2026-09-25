#!/usr/bin/env bash

# Exports the variables needed by terraform/bootstrap.
# Must be sourced, not executed: `source scripts/bootstrap/env.sh`
# No `set -euo pipefail` here: it would leak into the caller's shell.

log_ok()   { printf '  OK   %s\n' "$*" >&2; }
log_fail() { printf '  FAIL %s\n' "$*" >&2; }

ensure_sourced() {
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        log_fail "this script must be sourced: source ${0}"
        exit 1
    fi
}

ensure_az_login() {
    if ! az account show --output none 2>/dev/null; then
        log_fail "no Azure session, run: az login"
        return 1
    fi
}

export_subscription_id() {
    TF_VAR_subscription_id="$(az account show --query id --output tsv)"
    export TF_VAR_subscription_id
    log_ok "TF_VAR_subscription_id exported"
}

main() {
    ensure_sourced
    ensure_az_login || return 1
    export_subscription_id
}

main "$@"
