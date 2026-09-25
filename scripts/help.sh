#!/usr/bin/env bash
# Prints the make targets, grouped by `##@` section, from the Makefile and its fragments.
# Usage: scripts/help.sh Makefile makefiles/*.mk
set -euo pipefail

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_BOLD=$'\033[1m' C_CYAN=$'\033[36m' C_RESET=$'\033[0m'
else
    C_BOLD='' C_CYAN='' C_RESET=''
fi

# Collect first, print after: a section can be declared in several fragments
print_help() {
    awk -v bold="${C_BOLD}" -v cyan="${C_CYAN}" -v reset="${C_RESET}" '
        /^##@ / {
            section = substr($0, 5)
            if (!(section in seen)) { seen[section] = 1; order[++count] = section }
            next
        }
        /^[a-zA-Z0-9_-]+:.*## / {
            target = $0; sub(/:.*/, "", target)
            desc = $0; sub(/^[^#]*## /, "", desc)
            lines[section] = lines[section] sprintf("  %s%-20s%s %s\n", cyan, target, reset, desc)
        }
        END {
            printf "Usage: make <target>\n"
            for (i = 1; i <= count; i++) printf "\n%s%s%s\n%s", bold, order[i], reset, lines[order[i]]
        }
    ' "$@"
}

main() {
    print_help "$@"
}

main "$@"
