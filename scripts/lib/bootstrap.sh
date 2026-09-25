#!/usr/bin/env bash
# lib/bootstrap.sh: one-time setup from the workstation (GitHub identity, SSH key).
# Functions return a status instead of exiting, so a failure never kills the menu.

if [[ -n "${RUNNER_BOOTSTRAP_LOADED:-}" ]]; then
    return 0
fi
RUNNER_BOOTSTRAP_LOADED=1

BOOTSTRAP_TF_DIR="${RUNNER_ROOT}/terraform/bootstrap"
ANSIBLE_SSH_KEY_FILE="${ANSIBLE_SSH_KEY_FILE:-${HOME}/.ssh/runner-azure-ansible}"

# Runs in a subshell: env.sh exports TF_VAR_subscription_id without leaking into the menu
bootstrap_terraform() {
    local action="$1"
    case "${action}" in
        init | plan | apply | output) ;;
        *)
            log_err "unknown bootstrap action: ${action}"
            return 2
            ;;
    esac
    (
        # Not followed here (checked on its own): it re-sources core.sh, which confuses shellcheck
        # shellcheck source=/dev/null
        source "${RUNNER_ROOT}/scripts/bootstrap/env.sh" || exit 1
        log_step "Bootstrap: terraform ${action}"
        if terraform -chdir="${BOOTSTRAP_TF_DIR}" "${action}"; then
            log_ok "terraform ${action} succeeded"
        else
            log_err "terraform ${action} failed"
            exit 1
        fi
    )
}

# Key of the `ansible` sudo account. Idempotent: an existing key is reused, never overwritten.
bootstrap_ssh_key() {
    require_cmd gh ssh-keygen || return 1
    if ! gh auth status >/dev/null 2>&1; then
        log_err "no GitHub session, run: gh auth login"
        return 1
    fi

    log_step "SSH key of the ansible account"
    log_info "key file: ${ANSIBLE_SSH_KEY_FILE}"
    if [[ -f "${ANSIBLE_SSH_KEY_FILE}" ]]; then
        log_ok "key already exists, reused"
    else
        mkdir -p "$(dirname "${ANSIBLE_SSH_KEY_FILE}")"
        # No passphrase: the CI must use it unattended. The GitHub secret protects it.
        ssh-keygen -q -t ed25519 -N '' -C "ansible@runner-azure" -f "${ANSIBLE_SSH_KEY_FILE}" || return 1
        chmod 600 "${ANSIBLE_SSH_KEY_FILE}"
        log_ok "key created"
    fi

    log_step "Store the key in GitHub"
    # Read from a file on stdin: the private key never appears in the command line or the logs
    gh secret set ANSIBLE_SSH_PRIVATE_KEY <"${ANSIBLE_SSH_KEY_FILE}" || return 1
    log_ok "secret ANSIBLE_SSH_PRIVATE_KEY set"
    gh variable set ANSIBLE_SSH_PUBLIC_KEY <"${ANSIBLE_SSH_KEY_FILE}.pub" || return 1
    log_ok "variable ANSIBLE_SSH_PUBLIC_KEY set"
}

# CLI entry: scripts/runner.sh bootstrap <init|plan|apply|output|ssh-key>
bootstrap_cli() {
    local action="${1:-}"
    case "${action}" in
        ssh-key) bootstrap_ssh_key ;;
        init | plan | apply | output) bootstrap_terraform "${action}" ;;
        *)
            log_err "usage: scripts/runner.sh bootstrap <init|plan|apply|output|ssh-key>"
            return 2
            ;;
    esac
}

handle_bootstrap_menu() {
    while true; do
        show_bootstrap_menu
        ui_ask "Pick an action"
        case "${REPLY}" in
            1) bootstrap_terraform init ;;
            2) bootstrap_terraform plan ;;
            3) bootstrap_terraform apply ;;
            4) bootstrap_terraform output ;;
            5) bootstrap_ssh_key ;;
            0) return 0 ;;
            *)
                ui_invalid_choice
                continue
                ;;
        esac
        press_enter_to_continue
    done
}
