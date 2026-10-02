#!/usr/bin/env bash
# lib/bootstrap.sh: one-time setup from the workstation, the SSH key of the ansible account.
# The key stays on this machine: Infra puts the public half on the VM, Ansible connects with it.
# Functions return a status instead of exiting, so a failure never kills the menu.

if [[ -n "${RUNNER_BOOTSTRAP_LOADED:-}" ]]; then
    return 0
fi
RUNNER_BOOTSTRAP_LOADED=1

# Key of the `ansible` sudo account. Idempotent: an existing key is reused, never overwritten.
bootstrap_ssh_key() {
    require_cmd ssh-keygen || return 1

    log_step "SSH key of the ansible account"
    log_info "key file: ${ANSIBLE_SSH_KEY_FILE}"
    if [[ -f "${ANSIBLE_SSH_KEY_FILE}" ]]; then
        log_ok "key already exists, reused"
        return 0
    fi
    mkdir -p "$(dirname "${ANSIBLE_SSH_KEY_FILE}")"
    # No passphrase: Ansible uses it unattended
    ssh-keygen -q -t ed25519 -N '' -C "ansible@runner-azure" -f "${ANSIBLE_SSH_KEY_FILE}" || return 1
    chmod 600 "${ANSIBLE_SSH_KEY_FILE}"
    log_ok "key created"
}

# CLI entry: scripts/runner.sh bootstrap ssh-key
bootstrap_cli() {
    case "${1:-}" in
        ssh-key) bootstrap_ssh_key ;;
        *)
            log_err "usage: scripts/runner.sh bootstrap ssh-key"
            return 2
            ;;
    esac
}
