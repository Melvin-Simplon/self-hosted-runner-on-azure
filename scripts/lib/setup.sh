#!/usr/bin/env bash
# lib/setup.sh: guided first setup. Asks the four values of .env, picked from lists
# when az, terraform and gh can list them, then offers to run every phase in order.

if [[ -n "${RUNNER_SETUP_LOADED:-}" ]]; then
    return 0
fi
RUNNER_SETUP_LOADED=1

readonly SETUP_OTHER="__other__"
readonly SETUP_PAT_URL="https://github.com/settings/personal-access-tokens/new"
# How many of the person's repositories the runner target list shows
readonly SETUP_REPO_COUNT=15

setup_check_tools() {
    local cmd
    for cmd in az gh terraform ansible-playbook jq curl unzip git; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            ui_status fail "missing command: ${cmd}"
            return 1
        fi
    done
    if ! az account show --output none 2>/dev/null; then
        ui_status fail "no Azure session, run: az login"
        return 1
    fi
    if ! gh auth status >/dev/null 2>&1; then
        ui_status fail "no GitHub session, run: gh auth login"
        return 1
    fi
    ui_status ok "tools found, Azure and GitHub sessions open"
}

# Writes <key>=<value> in .env: replaces the line of the key, appends it if missing.
# A new .env starts from .env.example to keep its explanations. Written in 0600: it holds the PAT.
setup_env_set() {
    local key="$1" value="$2" tmp line found=0
    if [[ ! -f "${ENV_FILE}" ]]; then
        (umask 077 && cp "${RUNNER_ROOT}/.env.example" "${ENV_FILE}") || return 1
    fi
    tmp="$(umask 077 && mktemp "${ENV_FILE}.XXXXXX")" || return 1
    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ "${line}" == "${key}="* ]]; then
            ((found)) || printf '%s=%s\n' "${key}" "${value}"
            found=1
        else
            printf '%s\n' "${line}"
        fi
    done <"${ENV_FILE}" >"${tmp}"
    ((found)) || printf '%s=%s\n' "${key}" "${value}" >>"${tmp}"
    mv "${tmp}" "${ENV_FILE}"
}

# Picks the value of <key>: the current one first, then the candidates, then "type another one".
# Sets REPLY to the value. Usage: setup_pick_value <key> <title> <hint> [candidate...]
setup_pick_value() {
    local key="$1" title="$2" hint="$3" current candidate
    local -a values=() labels=()
    shift 3
    current="$(env_value "${key}")"
    if [[ -n "${current}" ]]; then
        values+=("${current}")
        labels+=("${current}  ${DIM}current${RESET}")
    fi
    for candidate in "$@"; do
        [[ "${candidate}" == "${current}" ]] && continue
        values+=("${candidate}")
        labels+=("${candidate}")
    done
    values+=("${SETUP_OTHER}")
    labels+=("other, type it")
    ui_pick "${title}" "${hint}" values labels open || return 1
    while [[ "${REPLY}" == "${SETUP_OTHER}" || -z "${REPLY}" ]]; do
        [[ "${REPLY}" == "${SETUP_OTHER}" ]] || ui_status fail "${key} cannot be empty"
        ui_ask "${key}" open || return 1
    done
}

# Prints the HCP Terraform organizations of the `terraform login` session, one per line, or nothing
setup_hcp_organizations() {
    local response
    [[ -n "$(hcp_token)" ]] || return 0
    response="$(hcp_api GET /organizations 2>/dev/null)" || return 0
    [[ "${response##*$'\n'}" == "200" ]] || return 0
    jq -r '.data[].id' <<<"${response%$'\n'*}"
}

setup_ask_values() {
    local hint
    local -a candidates=()

    # ${a[@]+...} keeps an empty list from failing under set -u in the bash 3.2 of macOS
    read_lines candidates < <(az group list --query "[].name" -o tsv | sort -f)
    setup_pick_value AZURE_RESOURCE_GROUP "RESOURCE GROUP" "existing, the runner VM goes there" ${candidates[@]+"${candidates[@]}"} || return 1
    setup_env_set AZURE_RESOURCE_GROUP "${REPLY}" || return 1

    read_lines candidates < <(setup_hcp_organizations)
    hint="holds the Terraform state"
    ((${#candidates[@]} > 0)) || hint="no terraform login session, type it or run terraform login first"
    setup_pick_value TF_CLOUD_ORGANIZATION "HCP TERRAFORM ORGANIZATION" "${hint}" ${candidates[@]+"${candidates[@]}"} || return 1
    setup_env_set TF_CLOUD_ORGANIZATION "${REPLY}" || return 1
    TF_CLOUD_ORGANIZATION="${REPLY}"

    # Organizations first (one runner for all their repositories), then the repositories the person
    # administers, latest pushed first: the project that should use the runner is usually among them
    read_lines candidates < <(
        gh api user/orgs --jq '"https://github.com/" + .[].login'
        gh api "user/repos?affiliation=owner,organization_member&sort=pushed&per_page=${SETUP_REPO_COUNT}" \
            --jq '.[] | select(.permissions.admin) | "https://github.com/" + .full_name'
    )
    while true; do
        setup_pick_value GITHUB_RUNNER_URL "RUNNER TARGET" "an org serves all its repositories, a repository only itself (your project)" ${candidates[@]+"${candidates[@]}"} || return 1
        GITHUB_RUNNER_URL="${REPLY}"
        runner_scope >/dev/null 2>&1 && break
        ui_status fail "must be https://github.com/<org> or https://github.com/<owner>/<repo>"
    done
    setup_env_set GITHUB_RUNNER_URL "${GITHUB_RUNNER_URL}" || return 1
}

# Prints the token creation page prefilled for <scope>. Parameters: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
setup_pat_url() {
    local scope="$1" owner permission
    if [[ "${scope}" == orgs/* ]]; then
        owner="${scope#orgs/}"
        permission="organization_self_hosted_runners=write"
    else
        owner="${scope#repos/}"
        owner="${owner%%/*}"
        permission="administration=write"
    fi
    # The name must be unique per account, the timestamp keeps a second run from colliding
    printf '%s?name=Azure+runner+%s&description=Registers+the+self-hosted+runner+on+Azure&target_name=%s&expires_in=30&%s\n' \
        "${SETUP_PAT_URL}" "$(date -u +%Y%m%d-%H%M)" "${owner}" "${permission}"
}

# Checks a PAT by requesting a registration token (it registers nothing, expires in 1 hour).
# On refusal, prints GitHub's reason on stdout.
setup_check_token() {
    local pat="$1" scope="$2" err
    err="$(GH_TOKEN="${pat}" gh api -X POST "${scope}/actions/runners/registration-token" --silent 2>&1)" && return 0
    err="$(head -n 1 <<<"${err}")"
    err="${err#gh: }"
    case "${err}" in
        *"HTTP 401"*) printf 'GitHub says Bad credentials: this token is expired or revoked, create a new one\n' ;;
        *"HTTP 403"* | *"HTTP 404"*) printf 'refused for %s, GitHub says: %s\n' "${scope}" "${err}" ;;
        *) printf 'GitHub refused the token: %s\n' "${err}" ;;
    esac
    return 1
}

setup_ask_token() {
    local scope pat current reason url
    scope="$(runner_scope)" || return 1
    current="$(env_value GITHUB_RUNNER_ADMIN_TOKEN)"
    ui_section "GITHUB TOKEN" "checked with GitHub before it is saved"
    if [[ -n "${current}" ]] && setup_check_token "${current}" "${scope}" >/dev/null; then
        ui_note "the current token still works for ${scope}, Enter keeps it"
    else
        current=""
        url="$(setup_pat_url "${scope}")"
        if open_url "${url}"; then
            ui_note "a prefilled token page is open in your browser, sign in if asked, then Generate token"
        fi
        ui_note "link: ${url}"
        if [[ "${scope}" == orgs/* ]]; then
            ui_note "it sets: owner ${scope#orgs/}, organization permission Self-hosted runners read and write"
        else
            ui_note "it sets: owner $(cut -d/ -f2 <<<"${scope}"), permission Administration read and write"
            ui_note "under Repository access, pick only ${scope#repos/}"
        fi
    fi
    ui_note "paste with Ctrl+Shift+V or a right click, one * shows per character"
    ui_section_end
    while true; do
        if [[ -n "${current}" ]]; then
            ui_ask_secret "Paste the token (Enter keeps the current one)" open || return 1
        else
            ui_ask_secret "Paste the token" open || return 1
        fi
        pat="${REPLY:-${current}}"
        if [[ -z "${pat}" ]]; then
            ui_status fail "a token is needed to register the runner"
            continue
        fi
        reason="$(setup_check_token "${pat}" "${scope}")" && break
        ui_status fail "${reason}"
        [[ "${pat}" == "${current}" ]] && current=""
    done
    ui_status ok "token accepted for ${scope}"
    setup_env_set GITHUB_RUNNER_ADMIN_TOKEN "${pat}"
}

# The default runner group of an organization refuses public repositories: their jobs would wait
# forever. Allowing them lets a fork pull request reach the VM, so the person decides.
setup_public_repositories() {
    local scope pat group
    scope="$(runner_scope)" || return 1
    [[ "${scope}" == orgs/* ]] || return 0
    pat="$(env_value GITHUB_RUNNER_ADMIN_TOKEN)"
    group="$(GH_TOKEN="${pat}" gh api "${scope}/actions/runner-groups" \
        --jq '.runner_groups[] | select(.default) | "\(.id) \(.allows_public_repositories)"' 2>/dev/null)"
    if [[ "${group#* }" == "true" ]]; then
        ui_status ok "the default runner group of ${scope#orgs/} accepts public repositories"
        return 0
    fi
    ui_section "PUBLIC REPOSITORIES" "refused by the default runner group of ${scope#orgs/}"
    ui_note "jobs of public repositories wait in the queue until this is allowed"
    ui_note "risk: a pull request from a fork could run code on the VM, guard each job with:"
    ui_note "if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository"
    ui_section_end
    ui_ask "Allow public repositories? [y/N]" open || return 1
    [[ "${REPLY}" =~ ^[yY]$ ]] || return 0
    if GH_TOKEN="${pat}" gh api -X PATCH "${scope}/actions/runner-groups/${group%% *}" \
        -F allows_public_repositories=true --silent 2>/dev/null; then
        ui_status ok "public repositories allowed in the default runner group"
    else
        ui_status fail "GitHub refused the change, allow it in the org settings: Actions, Runner groups, Default"
    fi
}

# Each phase runs only if the previous one succeeded. terraform apply asks for its own confirmation.
setup_run_phases() {
    bootstrap_ssh_key &&
        infra_terraform init &&
        infra_terraform apply &&
        ansible_apply
}

run_setup() {
    ui_header
    ui_title "SETUP" "answers go to .env, nothing is created on Azure before the last question"
    setup_check_tools || return 1
    setup_ask_values || return 1
    setup_ask_token || return 1
    setup_public_repositories || return 1
    export TF_CLOUD_ORGANIZATION GITHUB_RUNNER_URL

    ui_section "SUMMARY" "written to ${ENV_FILE}"
    ui_note "resource group    $(env_value AZURE_RESOURCE_GROUP)"
    ui_note "HCP organization  $(env_value TF_CLOUD_ORGANIZATION)"
    ui_note "runner target     $(env_value GITHUB_RUNNER_URL)"
    ui_note "GitHub token      set"
    ui_note "the phases can run now, or later from the menu in the same order"
    ui_section_end

    ui_ask "Run every phase now: SSH key, infra, ansible? [y/N]" || return 1
    if [[ "${REPLY}" =~ ^[yY]$ ]]; then
        setup_run_phases
    fi
}
