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

# Clear the screen, draw the banner and the tagline box.
# Every screen starts with it, so menus and actions look the same.
ui_header() {
    local line
    clear
    printf '\n'
    while IFS= read -r line; do
        printf '   %s%s%s\n' "${BOLD}${RED}" "${line}" "${RESET}"
    done <<<"${RUNNER_BANNER}"
    ui_tagline_box
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

# Prompt glyph: ╰─◉ closes the trunk (last question of a screen), ╞─◉ keeps it open for what follows
ui_prompt_glyph() {
    if [[ "${1:-close}" == "open" ]]; then
        printf '╞─◉'
    else
        printf '╰─◉'
    fi
}

# Asks a question and stores the answer in REPLY: ui_ask <question> [open|close]
# Returns 1 when stdin is closed, so a caller looping on a bad answer cannot spin forever.
# read -e uses readline: Backspace and arrows edit the input instead of printing ^? or ^[[D.
# \001 and \002 wrap the color codes so readline knows they take no space on screen.
ui_ask() {
    local prompt
    prompt="${BLUE:+$'\001'${BLUE}$'\002'}$(ui_prompt_glyph "${2:-close}")${RESET:+$'\001'${RESET}$'\002'} "
    prompt+="${BOLD:+$'\001'${BOLD}${BRIGHT_BLUE}$'\002'}$1 : ${RESET:+$'\001'${RESET}$'\002'}"
    ui_line
    read -e -r -p "${prompt}" || { REPLY=""; return 1; }
}

# Same as ui_ask for a token or a password: one * per character typed or pasted,
# so a paste shows up without revealing the secret. Spaces and line breaks are dropped.
ui_ask_secret() {
    local char secret=""
    ui_line
    printf '%s%s%s %s%s : %s' "${BLUE}" "$(ui_prompt_glyph "${2:-close}")" "${RESET}" "${BOLD}${BRIGHT_BLUE}" "$1" "${RESET}"
    while true; do
        if ! IFS= read -r -s -n 1 char; then
            printf '\n'
            REPLY=""
            return 1
        fi
        case "${char}" in
            "") break ;;
            $'\x7f' | $'\b')
                if [[ -n "${secret}" ]]; then
                    secret="${secret%?}"
                    printf '\b \b'
                fi
                ;;
            # Escape sequence (arrow key, bracketed paste markers \e[200~ \e[201~): skip it whole
            $'\e')
                while IFS= read -r -s -n 1 -t 0.05 char && [[ ! "${char}" =~ [A-Za-z~] ]]; do :; done
                ;;
            [[:space:]]) ;;
            *)
                secret+="${char}"
                printf '*'
                ;;
        esac
    done
    printf '\n'
    REPLY="${secret}"
}

# Section title on the trunk, without a block of items: ui_title <title> [hint]
ui_title() {
    local hint=""
    [[ -n "${2:-}" ]] && hint="  ${DIM}$2${RESET}"
    ui_line
    printf '%s╞─>%s %s%s%s%s\n' "${BLUE}" "${RESET}" "${BOLD}${BRIGHT_CYAN}" "$1" "${RESET}" "${hint}"
}

# A line of text inside a section block, between ui_section and ui_section_end
ui_note() {
    printf '  %s│%s  %s\n' "${BLUE}" "${RESET}" "$1"
}

# Result on the trunk, also copied to the log file: ui_status <ok|fail> <text>
ui_status() {
    case "$1" in
        ok)
            printf '%s│%s  %sOK%s   %s\n' "${BLUE}" "${RESET}" "${GREEN}" "${RESET}" "$2"
            log_to_file "OK" "$2"
            ;;
        *)
            printf '%s│%s  %sFAIL%s %s\n' "${BLUE}" "${RESET}" "${RED}" "${RESET}" "$2"
            log_to_file "FAIL" "$2"
            ;;
    esac
}

# Shows <labels> numbered in a section and sets REPLY to the matching value, Enter picks the first.
# A wrong number asks again. Usage: ui_pick <title> <hint> <values array> <labels array> [open|close]
ui_pick() {
    # Prefixed names: a nameref with the same name as the caller array would point to itself
    local -n _pick_values="$3" _pick_labels="$4"
    local i pick
    ui_section "$1" "$2"
    for i in "${!_pick_labels[@]}"; do
        printf '  %s╞─>%s %s%2d%s  %s\n' "${BLUE}" "${RESET}" "${BRIGHT_BLUE}" $((i + 1)) "${RESET}" "${_pick_labels[i]}"
    done
    ui_section_end
    if ((${#_pick_values[@]} == 0)); then
        ui_status fail "nothing to pick from"
        return 1
    fi
    while true; do
        ui_ask "Pick a number (Enter for 1)" "${5:-close}" || return 1
        pick="${REPLY:-1}"
        if [[ "${pick}" =~ ^[0-9]+$ ]] && ((pick >= 1 && pick <= ${#_pick_values[@]})); then
            break
        fi
        ui_status fail "pick a number between 1 and ${#_pick_values[@]}"
    done
    REPLY="${_pick_values[pick - 1]}"
}

ui_invalid_choice() {
    printf '\n   %sInvalid choice!%s\n' "${RED}" "${RESET}"
    sleep 1
}

show_main_menu() {
    ui_header
    ui_section "PHASES" "pick one, in order"
    ui_item 1 "Setup" ready
    ui_item 2 "Bootstrap" ready
    ui_item 3 "Infra" ready
    ui_item 4 "Ansible" ready
    ui_item 5 "Benchmark" ready
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

show_benchmark_menu() {
    ui_header
    ui_section "BENCHMARK" "read a finished GitHub Actions run"
    ui_item 1 "Logs"
    ui_item 2 "Metrics"
    ui_section_end
    ui_footer 0 "Back"
}
