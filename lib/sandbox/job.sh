# Jobs headless dentro de um Sandbox.
# Problema: precisávamos de stdout/stderr/exit/duração/artefatos sem
# destruir o sandbox ao terminar o comando.

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=backend-container.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backend-container.sh"

workvm_sandbox_job_new_id() {
    date +%Y%m%dT%H%M%S-$$
}

workvm_sandbox_job_dir() {
    local sandbox_id="$1"
    local job_id="$2"
    printf '%s/%s\n' "$(workvm_sandbox_jobs_dir "$sandbox_id")" "$job_id"
}

workvm_sandbox_job_run() {
    local sandbox_id="" service="app" detach=0
    local -a cmd=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --sandbox) sandbox_id="$2"; shift 2 ;;
            --service) service="$2"; shift 2 ;;
            --) shift; cmd=("$@"); break ;;
            -*)
                workvm_sandbox_log "flag desconhecida em job run: $1"
                return 2
                ;;
            *)
                sandbox_id="$1"
                shift
                cmd=("$@")
                break
                ;;
        esac
    done

    if [ -z "$sandbox_id" ] || [ "${#cmd[@]}" -eq 0 ]; then
        workvm_sandbox_log "uso: job run <sandbox> [--service app] -- <comando…>"
        workvm_sandbox_log "  ou: job run --sandbox <id> --service app -- <comando…>"
        return 2
    fi
    if ! workvm_sandbox_meta_exists "$sandbox_id"; then
        workvm_sandbox_log "sandbox ausente: $sandbox_id"
        return 1
    fi

    local state
    state="$(workvm_sandbox_meta_get "$sandbox_id" state)"
    case "$state" in
        ready|idle|running_job) ;;
        *)
            workvm_sandbox_log "sandbox $sandbox_id em estado $state; não aceita job"
            return 1
            ;;
    esac

    local job_id job_dir
    job_id="$(workvm_sandbox_job_new_id)"
    job_dir="$(workvm_sandbox_job_dir "$sandbox_id" "$job_id")"
    mkdir -p "$job_dir/artifacts"

    local started
    started="$(workvm_sandbox_now_iso)"
    printf '%s\n' "${cmd[@]}" >"$job_dir/command.txt"
    WORKVM_SB_JOB_DIR="$job_dir" WORKVM_SB_SANDBOX="$sandbox_id" \
        WORKVM_SB_JOB="$job_id" WORKVM_SB_SERVICE="$service" \
        WORKVM_SB_STARTED="$started" python3 - <<'PY'
import json, os
cmd = open(os.path.join(os.environ["WORKVM_SB_JOB_DIR"], "command.txt")).read().splitlines()
meta = {
    "job_id": os.environ["WORKVM_SB_JOB"],
    "sandbox_id": os.environ["WORKVM_SB_SANDBOX"],
    "service": os.environ["WORKVM_SB_SERVICE"],
    "command": cmd,
    "started_at": os.environ["WORKVM_SB_STARTED"],
    "finished_at": None,
    "duration_seconds": None,
    "exit_code": None,
    "state": "running",
}
open(os.path.join(os.environ["WORKVM_SB_JOB_DIR"], "meta.json"), "w").write(
    json.dumps(meta, indent=2) + "\n"
)
PY

    workvm_sandbox_meta_set "$sandbox_id" state "running_job"
    workvm_sandbox_meta_set "$sandbox_id" updated_at "$(workvm_sandbox_now_iso)"

    local start_epoch end_epoch rc=0
    start_epoch=$(date +%s)
    export WORKVM_SANDBOX_SERVICE="$service"

    set +e
    workvm_sandbox_container_exec "$sandbox_id" "${cmd[@]}" \
        >"$job_dir/stdout.log" 2>"$job_dir/stderr.log"
    rc=$?
    set -e

    end_epoch=$(date +%s)
    local finished duration
    finished="$(workvm_sandbox_now_iso)"
    duration=$((end_epoch - start_epoch))

    WORKVM_SB_JOB_DIR="$job_dir" WORKVM_SB_RC="$rc" \
        WORKVM_SB_FINISHED="$finished" WORKVM_SB_DUR="$duration" python3 - <<'PY'
import json, os
path = os.path.join(os.environ["WORKVM_SB_JOB_DIR"], "meta.json")
meta = json.load(open(path))
meta["finished_at"] = os.environ["WORKVM_SB_FINISHED"]
meta["duration_seconds"] = int(os.environ["WORKVM_SB_DUR"])
meta["exit_code"] = int(os.environ["WORKVM_SB_RC"])
meta["state"] = "finished"
json.dump(meta, open(path, "w"), indent=2)
PY

    # Copy common report dirs from worktree if present.
    local wt
    wt="$(workvm_sandbox_meta_get "$sandbox_id" worktrees 2>/dev/null || true)"
    if [ -n "$wt" ]; then
        local cand
        for cand in \
            "$wt/televisao-api/storage/logs" \
            "$wt/api-main/storage/logs" \
            "$wt/../televisao-front-e2e/test-results" \
            "$wt/e2e/test-results" \
            "$wt/e2e/playwright-report"
        do
            if [ -d "$cand" ]; then
                cp -a "$cand" "$job_dir/artifacts/" 2>/dev/null || true
            fi
        done
    fi
    # Compose-mounted artifact dirs next to compose file.
    local compose_dir
    compose_dir="$(workvm_sandbox_meta_get "$sandbox_id" compose_dir 2>/dev/null || true)"
    if [ -n "$compose_dir" ]; then
        for cand in "$compose_dir/artifacts" "$compose_dir/test-results" "$compose_dir/playwright-report"; do
            if [ -d "$cand" ] && [ "$(find "$cand" -mindepth 1 -maxdepth 1 2>/dev/null | head -1)" ]; then
                cp -a "$cand" "$job_dir/artifacts/" 2>/dev/null || true
            fi
        done
    fi

    workvm_sandbox_meta_set "$sandbox_id" state "idle"
    workvm_sandbox_meta_set "$sandbox_id" updated_at "$(workvm_sandbox_now_iso)"

    workvm_sandbox_log "job $job_id exit=$rc duration=${duration}s"
    printf '%s\n' "$job_id"
    return "$rc"
}

workvm_sandbox_job_status() {
    local sandbox_id="$1"
    local job_id="$2"
    local path
    path="$(workvm_sandbox_job_dir "$sandbox_id" "$job_id")/meta.json"
    if [ ! -f "$path" ]; then
        workvm_sandbox_log "job ausente: $sandbox_id/$job_id"
        return 1
    fi
    cat "$path"
}

workvm_sandbox_job_logs() {
    local sandbox_id="$1"
    local job_id="$2"
    local which="${3:-both}"
    local dir
    dir="$(workvm_sandbox_job_dir "$sandbox_id" "$job_id")"
    if [ ! -d "$dir" ]; then
        workvm_sandbox_log "job ausente: $sandbox_id/$job_id"
        return 1
    fi
    case "$which" in
        stdout) cat "$dir/stdout.log" ;;
        stderr) cat "$dir/stderr.log" ;;
        both|*)
            # printf treats leading - as flags — use --
            printf -- '--- stdout ---\n'
            cat "$dir/stdout.log" 2>/dev/null || true
            printf -- '--- stderr ---\n'
            cat "$dir/stderr.log" 2>/dev/null || true
            ;;
    esac
}

workvm_sandbox_job_artifacts() {
    local sandbox_id="$1"
    local job_id="$2"
    local dir
    dir="$(workvm_sandbox_job_dir "$sandbox_id" "$job_id")/artifacts"
    if [ ! -d "$dir" ]; then
        workvm_sandbox_log "artefatos ausentes: $sandbox_id/$job_id"
        return 1
    fi
    printf '%s\n' "$dir"
    find "$dir" -mindepth 1 -maxdepth 3 -print 2>/dev/null | head -100
}
