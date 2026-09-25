#!/usr/bin/env bash
# lib/infra.sh: dev environment (network + runner VM) from the workstation.
# For tuning only: in the TP, the CI workflows drive this same Terraform code.
# Functions return a status instead of exiting, so a failure never kills the menu.

if [[ -n "${RUNNER_INFRA_LOADED:-}" ]]; then
    return 0
fi
RUNNER_INFRA_LOADED=1

INFRA_TF_DIR="${RUNNER_ROOT}/terraform/environments/dev"

# Runs in a subshell: the TF_VAR_* exports never leak into the menu
infra_terraform() {
    local action="$1"
    case "${action}" in
        init | plan | apply | output | destroy) ;;
        *)
            log_err "unknown infra action: ${action}"
            return 2
            ;;
    esac
    (
        # Not followed here (checked on its own): it re-sources core.sh, which confuses shellcheck
        # shellcheck source=/dev/null
        source "${RUNNER_ROOT}/scripts/bootstrap/env.sh" || exit 1
        if [[ ! -f "${ANSIBLE_SSH_KEY_FILE}.pub" ]]; then
            log_err "no ansible public key, run: make bootstrap-ssh-key"
            exit 1
        fi
        TF_VAR_ssh_public_key="$(<"${ANSIBLE_SSH_KEY_FILE}.pub")"
        export TF_VAR_ssh_public_key

        log_step "Infra: terraform ${action}"
        # terraform apply and destroy ask for confirmation themselves
        if terraform -chdir="${INFRA_TF_DIR}" "${action}"; then
            log_ok "terraform ${action} succeeded"
        else
            log_err "terraform ${action} failed"
            exit 1
        fi
    )
}

# Proves what validate cannot: Azure accepted the VM and its ephemeral NVMe disk
infra_check() {
    require_cmd az || return 1
    log_step "Infra: check the runner VM"
    local rg="mpetitRG" vm="vm-runner" state placement
    if ! state="$(az vm show -g "${rg}" -n "${vm}" -d --query powerState -o tsv 2>/dev/null)"; then
        log_err "${vm} not found in ${rg}, run: make infra-apply"
        return 1
    fi
    placement="$(az vm show -g "${rg}" -n "${vm}" --query storageProfile.osDisk.diffDiskSettings.placement -o tsv)"
    log_info "power state : ${state}"
    log_info "OS disk     : ephemeral on ${placement:-none}"
    log_info "public IP   : $(az vm show -g "${rg}" -n "${vm}" -d --query publicIps -o tsv)"

    local failed=0
    if [[ "${state}" == "VM running" ]]; then
        log_ok "VM is running"
    else
        log_err "VM is not running"
        failed=1
    fi
    if [[ "${placement}" == "NvmeDisk" ]]; then
        log_ok "OS disk is ephemeral on the local NVMe"
    else
        log_err "OS disk is not ephemeral on NVMe"
        failed=1
    fi
    log_warn "the VM costs money while it exists, run: make infra-destroy"
    return "${failed}"
}

# CLI entry: scripts/runner.sh infra <init|plan|apply|check|output|destroy>
infra_cli() {
    local action="${1:-}"
    case "${action}" in
        check) infra_check ;;
        init | plan | apply | output | destroy) infra_terraform "${action}" ;;
        *)
            log_err "usage: scripts/runner.sh infra <init|plan|apply|check|output|destroy>"
            return 2
            ;;
    esac
}

handle_infra_menu() {
    while true; do
        show_infra_menu
        ui_ask "Pick an action"
        case "${REPLY}" in
            1) infra_terraform init ;;
            2) infra_terraform plan ;;
            3) infra_terraform apply ;;
            4) infra_check ;;
            5) infra_terraform output ;;
            6) infra_terraform destroy ;;
            0) return 0 ;;
            *)
                ui_invalid_choice
                continue
                ;;
        esac
        press_enter_to_continue
    done
}
