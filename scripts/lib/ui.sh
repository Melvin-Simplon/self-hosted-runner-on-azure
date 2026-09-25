#!/usr/bin/env bash
# lib/ui.sh: banner, menus and prompt of the interactive mode.

if [[ -n "${RUNNER_UI_LOADED:-}" ]]; then
    return 0
fi
RUNNER_UI_LOADED=1

RUNNER_BANNER=$(cat <<'ASCII'
  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣤⣤⣤⣤⡼⠀⢀⡀⣀⢱⡄⡀⠀⠀⠀⢲⣤⣤⣤⣤⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⣾⣿⣿⣿⣿⣿⡿⠛⠋⠁⣤⣿⣿⣿⣧⣷⠀⠀⠘⠉⠛⢻⣷⣿⣽⣿⣿⣷⣦⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀
  ⠀⠀⠀⠀⠀⠀⢀⣴⣞⣽⣿⣿⣿⣿⣿⣿⣿⠁⠀⠀⠠⣿⣿⡟⢻⣿⣿⣇⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣟⢦⡀⠀⠀⠀⠀⠀⠀
  ⠀⠀⠀⠀⠀⣠⣿⡾⣿⣿⣿⣿⣿⠿⣻⣿⣿⡀⠀⠀⠀⢻⣿⣷⡀⠻⣧⣿⠆⠀⠀⠀⠀⣿⣿⣿⡻⣿⣿⣿⣿⣿⠿⣽⣦⡀⠀⠀⠀⠀
  ⠀⠀⠀⠀⣼⠟⣩⣾⣿⣿⣿⢟⣵⣾⣿⣿⣿⣧⠀⠀⠀⠈⠿⣿⣿⣷⣈⠁⠀⠀⠀⠀⣰⣿⣿⣿⣿⣮⣟⢯⣿⣿⣷⣬⡻⣷⡄⠀⠀⠀
  ⠀⠀⢀⡜⣡⣾⣿⢿⣿⣿⣿⣿⣿⢟⣵⣿⣿⣿⣷⣄⠀⣰⣿⣿⣿⣿⣿⣷⣄⠀⢀⣼⣿⣿⣿⣷⡹⣿⣿⣿⣿⣿⣿⢿⣿⣮⡳⡄⠀⠀
  ⠀⢠⢟⣿⡿⠋⣠⣾⢿⣿⣿⠟⢃⣾⢟⣿⢿⣿⣿⣿⣾⡿⠟⠻⣿⣻⣿⣏⠻⣿⣾⣿⣿⣿⣿⡛⣿⡌⠻⣿⣿⡿⣿⣦⡙⢿⣿⡝⣆⠀
  ⠀⢯⣿⠏⣠⠞⠋⠀⣠⡿⠋⢀⣿⠁⢸⡏⣿⠿⣿⣿⠃⢠⣴⣾⣿⣿⣿⡟⠀⠘⢹⣿⠟⣿⣾⣷⠈⣿⡄⠘⢿⣦⠀⠈⠻⣆⠙⣿⣜⠆
  ⢀⣿⠃⡴⠃⢀⡠⠞⠋⠀⠀⠼⠋⠀⠸⡇⠻⠀⠈⠃⠀⣧⢋⣼⣿⣿⣿⣷⣆⠀⠈⠁⠀⠟⠁⡟⠀⠈⠻⠀⠀⠉⠳⢦⡀⠈⢣⠈⢿⡄
ASCII
)

readonly RUNNER_TAGLINE="Self-hosted GitHub runner on Azure, from zero to benchmark."

# Repeats a box-drawing char: tr works on bytes, so it cannot handle multibyte chars
ui_repeat() {
    local out
    printf -v out '%*s' "$2" ''
    printf '%s' "${out// /$1}"
}

# Every menu line hangs on this blue trunk, so each screen has a left border
# Text is optional: runner.sh passes it, this file only draws empty trunk lines
# shellcheck disable=SC2120
ui_line() {
    printf '%s│%s  %s\n' "${BLUE}" "${RESET}" "${1:-}"
}

# Box under the banner, closed on the right and open on the trunk at the bottom
ui_tagline_box() {
    local width=$(( ${#RUNNER_TAGLINE} + 4 )) rule blank
    rule=$(ui_repeat '─' "${width}")
    printf -v blank '%*s' "${width}" ''
    printf '%s╭%s╮%s\n' "${BLUE}" "${rule}" "${RESET}"
    printf '%s│%s│%s\n' "${BLUE}" "${blank}" "${RESET}"
    printf '%s│%s  %s%s%s  %s│%s\n' "${BLUE}" "${RESET}" "${RED}" "${RUNNER_TAGLINE}" "${RESET}" "${BLUE}" "${RESET}"
    printf '%s│%s│%s\n' "${BLUE}" "${blank}" "${RESET}"
    printf '%s╞%s╯%s\n' "${BLUE}" "${rule}" "${RESET}"
}

# Clear the screen, draw the banner, the tagline box and an optional title.
# Every screen starts with it, so menus and actions look the same.
# Title is optional: runner.sh passes it for the coming-soon screen
# shellcheck disable=SC2120
ui_header() {
    local title="${1:-}" line
    clear
    printf '\n'
    while IFS= read -r line; do
        printf '   %s%s%s\n' "${BOLD}${RED}" "${line}" "${RESET}"
    done <<<"${RUNNER_BANNER}"
    ui_tagline_box
    if [[ -n "${title}" ]]; then
        ui_line
        printf '%s╞─>%s %s%s%s\n' "${BLUE}" "${RESET}" "${BOLD}${BRIGHT_CYAN}" "${title}" "${RESET}"
        ui_line
    fi
}

# Opens a branch of items: ui_section <title> [hint]
ui_section() {
    local hint=""
    [[ -n "${2:-}" ]] && hint="  ${DIM}$2${RESET}"
    ui_line
    printf '%s╞─>%s %s%s%s%s\n' "${BLUE}" "${RESET}" "${BOLD}${BRIGHT_CYAN}" "$1" "${RESET}" "${hint}"
    printf '%s╰─╮%s\n' "${BLUE}" "${RESET}"
}

ui_section_end() {
    printf '%s╭─╯%s\n' "${BLUE}" "${RESET}"
}

# One menu entry inside a section: ui_item <key> <label> [ready|soon]
ui_item() {
    local key="$1" label="$2" state="${3:-}" badge=""
    case "${state}" in
        ready) badge="${GREEN}ready${RESET}" ;;
        soon) badge="${DIM}soon${RESET}" ;;
    esac
    printf '  %s╞─>%s %s%s%s  %-14s %s\n' "${BLUE}" "${RESET}" "${BRIGHT_BLUE}" "${key}" "${RESET}" "${label}" "${badge}"
}

# Small box for the navigation keys: ui_footer <key> <label> [<key> <label> ...]
ui_footer() {
    local plain="" colored="" rule
    while (($# >= 2)); do
        plain+=" $1  $2  "
        colored+=" ${BRIGHT_BLUE}$1${RESET}  $2  "
        shift 2
    done
    rule=$(ui_repeat '─' "$(( ${#plain} - 1 ))")
    ui_line
    printf '%s╞%s╮%s\n' "${BLUE}" "${rule}" "${RESET}"
    printf '%s│%s%s%s│%s\n' "${BLUE}" "${RESET}" "${colored% }" "${BLUE}" "${RESET}"
    printf '%s╞%s╯%s\n' "${BLUE}" "${rule}" "${RESET}"
}

# Asks for a choice and stores it in REPLY. The prompt closes the trunk.
# read -e uses readline: Backspace and arrows edit the input instead of printing ^? or ^[[D.
# \001 and \002 wrap the color codes so readline knows they take no space on screen.
ui_ask() {
    local prompt
    prompt="${BLUE:+$'\001'${BLUE}$'\002'}╰─◉${RESET:+$'\001'${RESET}$'\002'} "
    prompt+="${BOLD:+$'\001'${BOLD}${BRIGHT_BLUE}$'\002'}$1 : ${RESET:+$'\001'${RESET}$'\002'}"
    ui_line
    read -e -r -p "${prompt}" || REPLY=""
}

ui_invalid_choice() {
    printf '\n   %sInvalid choice!%s\n' "${RED}" "${RESET}"
    sleep 1
}

show_main_menu() {
    ui_header
    ui_section "PHASES" "pick one, in order"
    ui_item 1 "Bootstrap" ready
    ui_item 2 "Infra" ready
    ui_item 3 "Ansible" ready
    ui_item 4 "Benchmark" soon
    ui_section_end
    ui_footer 9 "Lint" 0 "Exit"
}

show_bootstrap_menu() {
    ui_header
    ui_section "BOOTSTRAP" "run once from the workstation"
    ui_item 1 "Init"
    ui_item 2 "Plan"
    ui_item 3 "Apply"
    ui_item 4 "Output"
    ui_item 5 "SSH key"
    ui_section_end
    ui_footer 0 "Back"
}

show_infra_menu() {
    ui_header
    ui_section "INFRA" "dev environment, the VM costs money while it exists"
    ui_item 1 "Init"
    ui_item 2 "Plan"
    ui_item 3 "Apply"
    ui_item 4 "Check"
    ui_item 5 "Output"
    ui_item 6 "Destroy"
    ui_section_end
    ui_footer 0 "Back"
}

show_ansible_menu() {
    ui_header
    ui_section "ANSIBLE" "SSH opens for your IP only, then closes"
    ui_item 1 "Ping"
    ui_item 2 "Check (dry run)"
    ui_item 3 "Apply"
    ui_section_end
    ui_footer 0 "Back"
}
