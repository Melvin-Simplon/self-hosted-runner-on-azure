    #!/usr/bin/env bash
# lib/hcp.sh: HCP Terraform API with the `terraform login` token.
# Keeps the workspaces in local execution: a remote run has no `az login`, so azurerm fails.

if [[ -n "${RUNNER_HCP_LOADED:-}" ]]; then
    return 0
fi
RUNNER_HCP_LOADED=1

readonly HCP_API="https://app.terraform.io/api/v2"

# Prints the token: TF_TOKEN_app_terraform_io first (read by terraform too), else the file
# written by `terraform login`. Prints nothing when there is none.
hcp_token() {
    if [[ -n "${TF_TOKEN_app_terraform_io:-}" ]]; then
        printf '%s\n' "${TF_TOKEN_app_terraform_io}"
        return 0
    fi
    jq -r '.credentials["app.terraform.io"].token // empty' "${HOME}/.terraform.d/credentials.tfrc.json" 2>/dev/null
}

# Calls the API: hcp_api <method> <path> [json body]. Prints the body, then the HTTP code on a
# last line. Returns 1 when the API cannot be reached.
hcp_api() {
    local method="$1" path="$2" token
    local -a data=()
    token="$(hcp_token)"
    [[ -n "${3:-}" ]] && data=(--data-binary "$3")
    # Token in a header read from stdin: never in the command line
    curl -sS -X "${method}" -H "Content-Type: application/vnd.api+json" -w '\n%{http_code}' \
        ${data[@]+"${data[@]}"} -H @- "${HCP_API}${path}" <<<"Authorization: Bearer ${token}"
}

# Prints the workspace name of the cloud block in <terraform dir>/cloud.tf
hcp_workspace_name() {
    sed -nE 's/^[[:space:]]*name[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$1/cloud.tf" 2>/dev/null | head -n 1
}

# Sends <method> <path> with the local execution settings of <workspace>, checks the answer
hcp_write_local() {
    local method="$1" path="$2" workspace="$3" body response code
    body="$(jq -nc --arg name "${workspace}" \
        '{data: {type: "workspaces", attributes: {name: $name, "execution-mode": "local",
          "setting-overwrites": {"execution-mode": true}}}}')"
    response="$(hcp_api "${method}" "${path}" "${body}")" || return 1
    code="${response##*$'\n'}"
    if [[ "${code}" != 2* ]]; then
        log_err "HCP Terraform answered ${code} to ${method} ${path}"
        return 1
    fi
}

# Makes sure the workspace of <terraform dir> runs locally. Creates it when missing, so that
# `terraform init` does not create it with the organization default (remote on a new one).
hcp_ensure_local_execution() {
    local org="${TF_CLOUD_ORGANIZATION:-}" workspace response code mode
    require_cmd curl jq || return 1
    workspace="$(hcp_workspace_name "$1")"
    if [[ -z "${org}" || -z "${workspace}" ]]; then
        log_err "unknown HCP workspace: TF_CLOUD_ORGANIZATION empty or no name in $1/cloud.tf"
        return 1
    fi
    if [[ -z "$(hcp_token)" ]]; then
        log_err "no HCP Terraform token, run: terraform login"
        return 1
    fi

    response="$(hcp_api GET "/organizations/${org}/workspaces/${workspace}")" || return 1
    code="${response##*$'\n'}"
    case "${code}" in
        200)
            mode="$(jq -r '.data.attributes["execution-mode"]' <<<"${response%$'\n'*}")"
            if [[ "${mode}" == "local" ]]; then
                log_ok "HCP workspace ${workspace} runs locally"
            else
                hcp_write_local PATCH "/organizations/${org}/workspaces/${workspace}" "${workspace}" || return 1
                log_ok "HCP workspace ${workspace} switched from ${mode} to local execution"
            fi
            ;;
        404)
            hcp_write_local POST "/organizations/${org}/workspaces" "${workspace}" || return 1
            log_ok "HCP workspace ${workspace} created with local execution"
            ;;
        *)
            log_err "HCP Terraform answered ${code} for workspace ${org}/${workspace}"
            return 1
            ;;
    esac
}
