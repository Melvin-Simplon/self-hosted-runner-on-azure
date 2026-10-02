#!/usr/bin/env bash
# lib/benchmark.sh: read a finished GitHub Actions run, its logs and its timings.
# Everything comes from the GitHub API through gh, nothing runs on the VM.

if [[ -n "${RUNNER_BENCHMARK_LOADED:-}" ]]; then
    return 0
fi
RUNNER_BENCHMARK_LOADED=1

# How many runs and repositories the lists show
readonly BENCHMARK_RUN_COUNT=10
readonly BENCHMARK_REPO_COUNT=30
# Repository (owner/name) whose runs are read: picked in the menu, REPO=<owner/name> on the CLI
BENCHMARK_REPO=""

# Prints the repository the CLI reads on stdout: REPO if set, else the GITHUB_RUNNER_URL repository,
# else this project. With an organization target, REPO picks one of its repositories.
benchmark_default_repo() {
    local scope
    if [[ -n "${REPO:-}" ]]; then
        printf '%s\n' "${REPO}"
    elif scope="$(runner_scope 2>/dev/null)" && [[ "${scope}" == repos/* ]]; then
        printf '%s\n' "${scope#repos/}"
    else
        github_repo_slug
    fi
}

# Menu: an organization target lists its repositories, a repository target is used as is
benchmark_pick_repo() {
    local scope
    # shellcheck disable=SC2034 # filled by read_lines and read by ui_pick through its name
    local -a repos=()
    scope="$(runner_scope)" || return 1
    if [[ "${scope}" == repos/* ]]; then
        BENCHMARK_REPO="${scope#repos/}"
        return 0
    fi
    read_lines repos < <(gh repo list "${scope#orgs/}" -L "${BENCHMARK_REPO_COUNT}" --json nameWithOwner --jq '.[].nameWithOwner')
    ui_pick "REPOSITORIES" "of ${scope#orgs/}, the runner serves them all" repos repos open || return 1
    BENCHMARK_REPO="${REPLY}"
}

# 75 -> "1m 15s", 8 -> "8s"
format_duration() {
    local s="$1"
    if ((s >= 60)); then
        printf '%dm %02ds' $((s / 60)) $((s % 60))
    else
        printf '%ds' "${s}"
    fi
}

# Prints the run id on stdout: the one given, or the last completed run of the repository
benchmark_run_id() {
    local repo="$1" run_id="${2:-}"
    if [[ -z "${run_id}" ]]; then
        run_id="$(gh run list -R "${repo}" --status completed -L 1 --json databaseId --jq '.[0].databaseId')" || return 1
        if [[ -z "${run_id}" ]]; then
            log_err "no completed run in ${repo}"
            return 1
        fi
    fi
    if [[ ! "${run_id}" =~ ^[0-9]+$ ]]; then
        log_err "run id must be a number, got: ${run_id}"
        return 1
    fi
    printf '%s\n' "${run_id}"
}

# Prints the last completed runs, one TSV line each: id, workflow, branch, event, conclusion, date (UTC)
benchmark_recent_runs() {
    gh run list -R "$1" --status completed -L "${BENCHMARK_RUN_COUNT}" \
        --json databaseId,workflowName,headBranch,event,conclusion,createdAt \
        --jq '.[] | [.databaseId, .workflowName, .headBranch, .event, .conclusion, (.createdAt | sub("T"; " ") | .[0:16])] | @tsv'
}

# CLI: lists the last runs with their id, to pass to logs or metrics
benchmark_runs() {
    require_cmd gh git || return 1
    local repo="${BENCHMARK_REPO}" id workflow branch event conclusion date
    log_step "Last ${BENCHMARK_RUN_COUNT} completed runs of ${repo} (dates in UTC)"
    while IFS=$'\t' read -r id workflow branch event conclusion date; do
        log_info "$(printf '%-12s %-17s %-24s %-24s %-18s %s' "${id}" "${date}" "${workflow}" "${branch}" "${event}" "${conclusion}")"
    done < <(benchmark_recent_runs "${repo}")
}

# Menu: shows the last runs of BENCHMARK_REPO numbered and sets REPLY to the id of the one picked
benchmark_pick_run() {
    local id workflow branch event conclusion date
    local -a ids=() labels=()
    while IFS=$'\t' read -r id workflow branch event conclusion date; do
        ids+=("${id}")
        labels+=("$(printf '%s  %-24s %-24s %-18s %s' "${date}" "${workflow}" "${branch}" "${event}" "${conclusion}")")
    done < <(benchmark_recent_runs "${BENCHMARK_REPO}")
    ui_pick "RUNS" "${BENCHMARK_REPO}, last ${BENCHMARK_RUN_COUNT} completed, dates in UTC" ids labels
}

# 3326 -> "3.326s", 65004 -> "1m 05.004s"
format_ms() {
    local ms="$1" s
    s=$((ms / 1000))
    if ((s >= 60)); then
        printf '%dm %02d.%03ds' $((s / 60)) $((s % 60)) $((ms % 1000))
    else
        printf '%d.%03ds' "${s}" $((ms % 1000))
    fi
}

# 1790850093285 -> "10:21:33.285"
format_epoch_ms() {
    date -u -d "@$(($1 / 1000)).$(printf '%03d' $(($1 % 1000)))" +%H:%M:%S.%3N
}

# Downloads the log archive of a run and extracts it into <dir>/logs.
# gh run view --log prints nothing for a job without per-step files, the archive always has the job log.
benchmark_fetch_logs() {
    local repo="$1" run_id="$2" dir="$3"
    gh api "repos/${repo}/actions/runs/${run_id}/logs" >"${dir}/logs.zip" || return 1
    unzip -q "${dir}/logs.zip" -d "${dir}/logs"
}

# Prints the first and the last timestamp of the run logs in epoch ms, one per line.
# Only timestamps opening a line count, a step can print dates of its own.
# The first one comes from system.txt, written by GitHub when it queues the job.
benchmark_log_bounds() (
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp}"' EXIT
    benchmark_fetch_logs "$1" "$2" "${tmp}" || exit 1
    find "${tmp}/logs" -name '*.txt' -exec sed 's/^\xEF\xBB\xBF//' {} + |
        grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z' |
        date -u -f - +%s%3N | sort -n | sed -n '1p;$p'
)

# One block per job, from the archive: one file per job at its root, named <n>_<job>.txt
benchmark_logs() (
    require_cmd gh git unzip || exit 1
    local repo="${BENCHMARK_REPO}" run_id tmp file job
    run_id="$(benchmark_run_id "${repo}" "${1:-}")" || exit 1
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp}"' EXIT
    benchmark_fetch_logs "${repo}" "${run_id}" "${tmp}" || exit 1
    for file in "${tmp}"/logs/*.txt; do
        job="${file##*/}"
        job="${job%.txt}"
        log_step "Logs of run ${run_id}, job ${job#*_}"
        sed 's/^\xEF\xBB\xBF//' "${file}"
    done
)

# Total CI duration to the millisecond (log archive), with the API figure to the second beside it
benchmark_metrics() {
    require_cmd gh git jq unzip || return 1
    local repo="${BENCHMARK_REPO}" run_id run jobs total bounds first last
    run_id="$(benchmark_run_id "${repo}" "${1:-}")" || return 1
    run="$(gh api "repos/${repo}/actions/runs/${run_id}")" || return 1
    jobs="$(gh api --paginate "repos/${repo}/actions/runs/${run_id}/jobs" --jq '.jobs[]' | jq -s .)" || return 1

    if [[ "$(jq -r .status <<<"${run}")" != "completed" ]]; then
        log_err "run ${run_id} is not finished yet, timings would be incomplete"
        return 1
    fi

    log_step "Run ${run_id}: $(jq -r '"\(.name) (\(.event) on \(.head_branch), \(.conclusion))"' <<<"${run}")"
    log_info "$(jq -r .html_url <<<"${run}")"

    # The API has seconds only, run_duration_ms included: the ms total comes from the logs.
    # It runs from GitHub queueing the first job (system.txt) to the last line written by the runner.
    bounds="$(benchmark_log_bounds "${repo}" "${run_id}")" || return 1
    first="$(sed -n 1p <<<"${bounds}")"
    last="$(sed -n 2p <<<"${bounds}")"
    if [[ -z "${first}" || -z "${last}" ]]; then
        log_err "no timestamp in the logs of run ${run_id}"
        return 1
    fi
    log_step "Total CI duration"
    log_ok "$(format_ms $((last - first))), job queued at $(format_epoch_ms "${first}"), last runner line at $(format_epoch_ms "${last}") UTC"

    total="$(jq -r --argjson run "${run}" '
        [.[].completed_at | select(.) | fromdate] | max as $end
        | if $end then $end - ($run.created_at | fromdate) else 0 end' <<<"${jobs}")"
    log_info "GitHub API, to the second: $(format_duration "${total}") from trigger to job end, log upload included"
}

# CLI entry: [REPO=<owner/name>] scripts/runner.sh benchmark <runs|logs|metrics> [run-id]
benchmark_cli() {
    local action="${1:-}"
    [[ -n "${BENCHMARK_REPO}" ]] || BENCHMARK_REPO="$(benchmark_default_repo)" || return 1
    if ! is_repo_slug "${BENCHMARK_REPO}"; then
        log_err "REPO must be <owner>/<name>, got: ${BENCHMARK_REPO}"
        return 2
    fi
    case "${action}" in
        runs) benchmark_runs ;;
        logs) benchmark_logs "${2:-}" ;;
        metrics) benchmark_metrics "${2:-}" ;;
        *)
            log_err "usage: [REPO=<owner/name>] scripts/runner.sh benchmark <runs|logs|metrics> [run-id]"
            return 2
            ;;
    esac
}

handle_benchmark_menu() {
    while true; do
        show_benchmark_menu
        ui_ask "Pick an action"
        case "${REPLY}" in
            1 | 2)
                local action=logs
                [[ "${REPLY}" == 2 ]] && action=metrics
                require_cmd gh git &&
                    benchmark_pick_repo &&
                    benchmark_pick_run &&
                    benchmark_cli "${action}" "${REPLY}"
                ;;
            0) return 0 ;;
            *)
                ui_invalid_choice
                continue
                ;;
        esac
        press_enter_to_continue
    done
}
