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

# Prints the value of <key> in .env on stdout, empty if missing.
# .env is parsed, never sourced: it holds data, not code to run. ENV_FILE is set by the caller.
env_value() {
    [[ -r "${ENV_FILE:-}" ]] || return 0
    sed -nE "s/^$1=[\"']?([^\"']*)[\"']?[[:space:]]*$/\1/p" "${ENV_FILE}" | tail -n 1
}

# Prints this project's repository as owner/name on stdout, taken from the origin remote
github_repo_slug() {
    git -C "${RUNNER_ROOT}" remote get-url origin |
        sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##'
}

# True for owner/name as GitHub allows it. The names end up in API paths, so "." and ".." are refused.
is_repo_slug() {
    [[ "$1" =~ ^[A-Za-z0-9-]+/[A-Za-z0-9_.-]+$ && ! "${1#*/}" =~ ^\.+$ ]]
}

# Prints where the runner registers, from GITHUB_RUNNER_URL in .env, as an API path on stdout:
# orgs/<org> for an organization, repos/<owner>/<repo> for a single repository
runner_scope() {
    local url path
    url="${GITHUB_RUNNER_URL:-$(env_value GITHUB_RUNNER_URL)}"
    path="${url#https://github.com/}"
    path="${path%/}"
    if [[ "${url}" == https://github.com/* && "${path}" =~ ^[A-Za-z0-9-]+$ ]]; then
        printf 'orgs/%s\n' "${path}"
    elif [[ "${url}" == https://github.com/* ]] && is_repo_slug "${path}"; then
        printf 'repos/%s\n' "${path}"
    else
        log_err "GITHUB_RUNNER_URL in .env must be https://github.com/<org> or https://github.com/<owner>/<repo>, got: '${url}'"
        return 1
    fi
}

# Opens <url> in the browser of the workstation, returns 1 if no opener is found.
# Under WSL, explorer.exe cuts the URL at the first &, PowerShell passes it whole.
open_url() {
    if command -v wslview >/dev/null 2>&1; then
        wslview "$1" >/dev/null 2>&1 &
    elif command -v powershell.exe >/dev/null 2>&1; then
        # The URL goes through an environment variable: no quoting issue inside the PowerShell command.
        # shellcheck disable=SC2016 # $env:OPEN_URL is PowerShell syntax, expanded by PowerShell
        OPEN_URL="$1" WSLENV=OPEN_URL powershell.exe -NoProfile -Command 'Start-Process $env:OPEN_URL' >/dev/null 2>&1 &
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$1" >/dev/null 2>&1 &
    elif command -v open >/dev/null 2>&1; then
        open "$1" >/dev/null 2>&1 &
    else
        return 1
    fi
}

press_enter_to_continue() {
    printf '\n   %sPress Enter to go back to the menu...%s' "${DIM}" "${RESET}"
    read -r _
}

# Reads stdin into the array named <name>, one element per line: read_lines <name> < <(cmd)
# Stands in for mapfile -t, missing from the bash 3.2 that macOS ships.
read_lines() {
    local _line
    eval "$1=()"
    while IFS= read -r _line || [[ -n "${_line}" ]]; do
        eval "$1+=(\"\${_line}\")"
    done
}
