#!/usr/bin/env bash
# lib/ansible.sh: run Ansible on the runner VM from the workstation.
# SSH is closed by the NSG: each run opens port 22 for the workstation IP only, then closes it.
# Functions return a status instead of exiting, so a failure never kills the menu.

if [[ -n "${RUNNER_ANSIBLE_LOADED:-}" ]]; then
    return 0
fi
RUNNER_ANSIBLE_LOADED=1

ANSIBLE_DIR="${RUNNER_ROOT}/ansible"
# Distinct from the CI rule name, so the two never delete each other's rule
SSH_RULE_NAME="allow-ssh-workstation"

# Prints one Terraform output of the dev environment on stdout (logs go to stderr)
infra_output() {
    terraform -chdir="${INFRA_TF_DIR}" output -raw "$1" 2>/dev/null
}

ssh_open() {
    local rg="$1" nsg="$2" my_ip
    if ! my_ip="$(curl -fsS --max-time 10 https://api.ipify.org)"; then
        log_err "could not read the workstation public IP"
        return 1
    fi
    log_step "Open SSH for ${my_ip} only"
    az network nsg rule create -g "${rg}" --nsg-name "${nsg}" -n "${SSH_RULE_NAME}" \
        --priority 100 --direction Inbound --access Allow --protocol Tcp \
        --source-address-prefixes "${my_ip}/32" --destination-port-ranges 22 \
        --output none || return 1
    log_ok "rule ${SSH_RULE_NAME} added to ${nsg}"
}

ssh_close() {
    local rg="$1" nsg="$2"
    log_step "Close SSH"
    if az network nsg rule delete -g "${rg}" --nsg-name "${nsg}" -n "${SSH_RULE_NAME}" --output none; then
        log_ok "rule ${SSH_RULE_NAME} removed from ${nsg}"
    else
        log_err "could not remove ${SSH_RULE_NAME}, delete it by hand in the portal"
        return 1
    fi
}

# Wraps any ansible command: open SSH, run it, and always close SSH (even on failure or Ctrl+C)
with_ssh_open() {
    require_cmd az curl terraform ansible || return 1
    (
        local rg nsg ip
        rg="$(infra_output resource_group_name)"
        nsg="$(infra_output nsg_name)"
        ip="$(infra_output public_ip)"
        if [[ -z "${ip}" || -z "${nsg}" ]]; then
            log_err "no runner VM in the Terraform outputs, run: make infra-apply"
            exit 1
        fi
        export RUNNER_IP="${ip}" ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg"

        ssh_open "${rg}" "${nsg}" || exit 1
        # shellcheck disable=SC2064 # expand rg and nsg now, the trap runs after they are gone
        trap "ssh_close '${rg}' '${nsg}'" EXIT

        log_step "Ansible on vm-runner (${ip})"
        cd "${ANSIBLE_DIR}" && "$@"
    )
}

ansible_ping() {
    with_ssh_open ansible runners -m ansible.builtin.ping
}

# CLI entry: scripts/runner.sh ansible <ping>
ansible_cli() {
    local action="${1:-}"
    case "${action}" in
        ping) ansible_ping ;;
        *)
            log_err "usage: scripts/runner.sh ansible <ping>"
            return 2
            ;;
    esac
}

handle_ansible_menu() {
    while true; do
        show_ansible_menu
        ui_ask "Pick an action"
        case "${REPLY}" in
            1) ansible_ping ;;
            0) return 0 ;;
            *)
                ui_invalid_choice
                continue
                ;;
        esac
        press_enter_to_continue
    done
}
