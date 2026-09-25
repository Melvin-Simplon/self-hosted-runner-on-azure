#!/usr/bin/env bash
# Shared helpers, sourced by the other scripts. Defines functions only, no side effect.
# Console: ==> step, OK, WARN, FAIL. Optional file log in append mode when LOG_FILE is set.

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\033[0m' C_RED=$'\033[31m' C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m' C_BLUE=$'\033[34m' C_BOLD=$'\033[1m'
else
    C_RESET='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_BOLD=''
fi

# Timestamped, colorless copy of each line; the terminal output stays untouched
log_to_file() {
    [[ -n "${LOG_FILE:-}" ]] || return 0
    mkdir -p "$(dirname "${LOG_FILE}")"
    (umask 077 && printf '%s %-4s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" >>"${LOG_FILE}")
}

log_step() { printf '\n%s==> %s%s\n' "${C_BOLD}${C_BLUE}" "$*" "${C_RESET}"; log_to_file "==>" "$*"; }
log_info() { printf '    %s\n' "$*"; log_to_file "" "$*"; }
log_ok()   { printf '  %sOK%s  %s\n' "${C_GREEN}" "${C_RESET}" "$*"; log_to_file "OK" "$*"; }
log_warn() { printf '  %sWARN%s %s\n' "${C_YELLOW}" "${C_RESET}" "$*" >&2; log_to_file "WARN" "$*"; }
log_err()  { printf '  %sFAIL%s %s\n' "${C_RED}" "${C_RESET}" "$*" >&2; log_to_file "FAIL" "$*"; }
