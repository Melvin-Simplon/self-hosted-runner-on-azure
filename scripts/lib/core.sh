#!/usr/bin/env bash
# lib/core.sh: colors, logs and small helpers shared by every module.
# Console: ==> step, OK, WARN, FAIL. File copy in append mode when LOG_FILE is set.

if [[ -n "${RUNNER_CORE_LOADED:-}" ]]; then
    return 0
fi
RUNNER_CORE_LOADED=1

# Used by the modules that source this file, not here
# shellcheck disable=SC2034
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    RESET=$'\033[0m' BOLD=$'\033[1m' DIM=$'\033[2m'
    RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' BLUE=$'\033[34m' CYAN=$'\033[36m'
    BRIGHT_BLUE=$'\033[94m' BRIGHT_CYAN=$'\033[96m'
else
    RESET='' BOLD='' DIM='' RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BRIGHT_BLUE='' BRIGHT_CYAN=''
fi

# Timestamped, colorless copy of each line; the terminal output stays untouched
log_to_file() {
    [[ -n "${LOG_FILE:-}" ]] || return 0
    mkdir -p "$(dirname "${LOG_FILE}")"
    (umask 077 && printf '%s %-4s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" >>"${LOG_FILE}")
}

log_step() { printf '\n%s==> %s%s\n' "${BOLD}${BLUE}" "$*" "${RESET}"; log_to_file "==>" "$*"; }
log_info() { printf '    %s\n' "$*"; log_to_file "" "$*"; }
log_ok()   { printf '  %sOK%s  %s\n' "${GREEN}" "${RESET}" "$*"; log_to_file "OK" "$*"; }
log_warn() { printf '  %sWARN%s %s\n' "${YELLOW}" "${RESET}" "$*" >&2; log_to_file "WARN" "$*"; }
log_err()  { printf '  %sFAIL%s %s\n' "${RED}" "${RESET}" "$*" >&2; log_to_file "FAIL" "$*"; }

require_cmd() {
    local cmd
    for cmd in "$@"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            log_err "missing command: ${cmd}"
            return 1
        fi
    done
}

press_enter_to_continue() {
    printf '\n   %sPress Enter to go back to the menu...%s' "${DIM}" "${RESET}"
    read -r _
}
