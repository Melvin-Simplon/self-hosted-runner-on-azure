#!/usr/bin/env bash

# Exports the variables needed by terraform/environments/dev.
# Must be sourced, not executed: `source scripts/bootstrap/env.sh`
# No `set -euo pipefail` here: it would leak into the caller's shell.
# No `main` either: it would overwrite the caller's `main` when sourced from another script.
# Works in bash and zsh: zsh has no BASH_SOURCE, but sets $0 to the sourced file.

: "${RUNNER_ROOT:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}"
: "${ENV_FILE:=${RUNNER_ROOT}/.env}"

# shellcheck source=scripts/lib/core.sh
source "${RUNNER_ROOT}/scripts/lib/core.sh"

ensure_sourced() {
    # Only bash can be caught executing it; in zsh BASH_SOURCE is empty, so this never matches
    if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" == "${0}" ]]; then
        log_err "this script must be sourced: source ${0}"
        exit 1
    fi
}

ensure_az_login() {
    if ! az account show --output none 2>/dev/null; then
        log_err "no Azure session, run: az login"
        return 1
    fi
}

export_subscription_id() {
    TF_VAR_subscription_id="$(az account show --query id --output tsv)"
    export TF_VAR_subscription_id
    log_ok "TF_VAR_subscription_id exported"
}

# A value already in the environment wins over .env: the CI sets its own
export_project_env() {
    TF_VAR_resource_group_name="${TF_VAR_resource_group_name:-$(env_value AZURE_RESOURCE_GROUP)}"
    TF_CLOUD_ORGANIZATION="${TF_CLOUD_ORGANIZATION:-$(env_value TF_CLOUD_ORGANIZATION)}"
    if [[ -z "${TF_VAR_resource_group_name}" || -z "${TF_CLOUD_ORGANIZATION}" ]]; then
        log_err "AZURE_RESOURCE_GROUP and TF_CLOUD_ORGANIZATION missing in ${ENV_FILE}, see .env.example"
        return 1
    fi
    export TF_VAR_resource_group_name TF_CLOUD_ORGANIZATION
    log_ok "resource group ${TF_VAR_resource_group_name}, HCP organization ${TF_CLOUD_ORGANIZATION}"
}

load_bootstrap_env() {
    ensure_sourced
    ensure_az_login || return 1
    export_subscription_id
    export_project_env
}

load_bootstrap_env || return 1
