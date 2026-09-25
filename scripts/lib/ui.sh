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

# Every menu line starts with this blue bar, so each screen has a left border
ui_line() {
    printf '%s┃%s  %s\n' "${BLUE}" "${RESET}" "${1:-}"
}

# Clear the screen, draw the banner and an optional section title.
# Every screen starts with it, so menus and actions look the same.
ui_header() {
    local title="${1:-}" line
    clear
    # The banner has no bar: it starts at the description. Same 3-column indent to stay aligned.
    printf '\n'
    while IFS= read -r line; do
        printf '   %s%s%s\n' "${BOLD}${BRIGHT_BLUE}" "${line}" "${RESET}"
    done <<<"${RUNNER_BANNER}"
    printf '\n'
    ui_line "${RED}Self-hosted GitHub runner on Azure, from zero to benchmark.${RESET}"
    ui_line
    if [[ -n "${title}" ]]; then
        ui_line "${BOLD}${BRIGHT_CYAN}${title}${RESET}"
        ui_line
    fi
}

# One menu entry: ui_item <key> <label> [ready|soon]
ui_item() {
    local key="$1" label="$2" state="${3:-}" badge=""
    case "${state}" in
        ready) badge="${GREEN}ready${RESET}" ;;
        soon) badge="${DIM}soon${RESET}" ;;
    esac
    ui_line "$(printf '%s[%s]%s  %-14s %s' "${BRIGHT_BLUE}" "${key}" "${RESET}" "${label}" "${badge}")"
}

# Asks for a choice and stores it in REPLY.
# read -e uses readline: Backspace and arrows edit the input instead of printing ^? or ^[[D.
# \001 and \002 wrap the color codes so readline knows they take no space on screen.
ui_ask() {
    local prompt
    prompt="${BLUE:+$'\001'${BLUE}$'\002'}┃${RESET:+$'\001'${RESET}$'\002'}  "
    prompt+="${BOLD:+$'\001'${BOLD}${BRIGHT_BLUE}$'\002'}▪ $1 : ${RESET:+$'\001'${RESET}$'\002'}"
    ui_line
    read -e -r -p "${prompt}" || REPLY=""
}

ui_invalid_choice() {
    ui_line
    ui_line "${RED}Invalid choice!${RESET}"
    sleep 1
}

show_main_menu() {
    ui_header
    ui_line "${DIM}Pick a phase:${RESET}"
    ui_line
    ui_item 1 "Bootstrap" ready
    ui_item 2 "Infra" soon
    ui_item 3 "Ansible" soon
    ui_item 4 "Benchmark" soon
    ui_line
    ui_item 9 "Lint" ready
    ui_item 0 "Exit"
}

show_bootstrap_menu() {
    ui_header "BOOTSTRAP  (run once from the workstation)"
    ui_item 1 "Init"
    ui_item 2 "Plan"
    ui_item 3 "Apply"
    ui_item 4 "Output"
    ui_item 5 "SSH key"
    ui_line
    ui_item 0 "Back"
}
