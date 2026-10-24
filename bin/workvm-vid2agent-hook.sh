#!/usr/bin/env bash
# vid2agent-code up does not publish its API, and the host VLM stays down.
# Other guests call 10.0.2.2:18080 and 10.0.2.2:11434. Both fail when this
# VM booted without the hostfwd and without Ollama.
# On started, restore and reconnect: forward 127.0.0.1:18080 to guest :80,
# then ollama serve on 127.0.0.1:11434 (RX 580 when the RADV ICD exists).
# On stopped and release: stop only the Ollama process this script started.
# Does not install Ollama or vulkan-radeon. A missing binary is logged.
# Libvirt calls this via bin/workvm-libvirt-qemu-hook.sh, which exits 0.
set -euo pipefail

domain=${1:-}
operation=${2:-}
phase=${3:-}

host_port=18080
guest_port=80
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/workvm-hooks
log_file=$state_dir/qemu.log
pid_file=$state_dir/ollama.pid
lock_file=$state_dir/vid2agent.lock

log() {
    printf '%s vid2agent-hook: %s\n' "$(date -Iseconds)" "$*"
}

ollama_bin() {
    local candidate

    for candidate in /usr/local/bin/ollama /usr/bin/ollama; do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    command -v ollama 2>/dev/null || true
}

radeon_icd() {
    local candidate

    for candidate in \
        /usr/share/vulkan/icd.d/radeon_icd.x86_64.json \
        /usr/share/vulkan/icd.d/radeon_icd.json
    do
        if [ -f "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
}

ollama_listening() {
    local listeners

    listeners=$(ss -ltnH 2>/dev/null || true)
    [[ "$listeners" == *127.0.0.1:11434* ]]
}

virsh_bin() {
    if [ -x /usr/bin/virsh ]; then
        printf '%s\n' /usr/bin/virsh
        return 0
    fi

    command -v virsh 2>/dev/null || true
}

pick_uri() {
    local virsh=$1
    local uri

    for uri in qemu:///session qemu:///system; do
        if "$virsh" -c "$uri" domstate "$domain" >/dev/null 2>&1; then
            printf '%s\n' "$uri"
            return 0
        fi
    done

    return 1
}

domain_running() {
    local virsh=$1
    local uri=$2
    local state

    state=$("$virsh" -c "$uri" domstate "$domain" 2>/dev/null || true)
    [ "$state" = "running" ]
}

hostfwd_present() {
    local virsh=$1
    local uri=$2
    local info

    info=$("$virsh" -c "$uri" qemu-monitor-command "$domain" --hmp 'info usernet' 2>/dev/null || true)
    [[ "$info" =~ (^|[[:space:]])${host_port}([[:space:]]|$) ]]
}

# Retries: restore/begin runs before QEMU accepts monitor commands.
ensure_forward_and_ollama() {
    local virsh uri icd bin forwarded

    virsh=$(virsh_bin)
    forwarded=0

    if [ -z "$virsh" ]; then
        log "virsh ausente; forward ${host_port} não aplicado"
        return 0
    fi

    for _ in $(seq 1 30); do
        if ! uri=$(pick_uri "$virsh"); then
            sleep 2
            continue
        fi

        if ! domain_running "$virsh" "$uri"; then
            log "domain ${domain} não está running; Ollama não sobe"
            return 0
        fi

        if hostfwd_present "$virsh" "$uri"; then
            log "hostfwd 127.0.0.1:${host_port} já presente"
            forwarded=1
            break
        fi

        if "$virsh" -c "$uri" qemu-monitor-command "$domain" --hmp \
            "hostfwd_add hostnet0 tcp:127.0.0.1:${host_port}-:${guest_port}" >/dev/null 2>&1; then
            log "hostfwd 127.0.0.1:${host_port} -> guest :${guest_port}"
            forwarded=1
            break
        fi

        sleep 2
    done

    if [ "$forwarded" -ne 1 ]; then
        log "hostfwd ${host_port} não entrou em ${domain}"
    fi

    if ! uri=$(pick_uri "$virsh") || ! domain_running "$virsh" "$uri"; then
        log "domain ${domain} saiu antes do Ollama"
        return 0
    fi

    if ollama_listening; then
        log "Ollama já escuta em 127.0.0.1:11434"
        return 0
    fi

    bin=$(ollama_bin)

    if [ -z "$bin" ]; then
        log "binário ollama ausente; 10.0.2.2:11434 continua fechada"
        return 0
    fi

    icd=$(radeon_icd || true)

    if [ -n "$icd" ]; then
        export VK_ICD_FILENAMES=$icd
        export VK_DRIVER_FILES=$icd
        log "Ollama na RX 580 via ${icd}"
    else
        log "ICD RADV ausente; Ollama não fica preso na RX 580"
    fi

    export OLLAMA_HOST=127.0.0.1:11434
    export CUDA_VISIBLE_DEVICES=

    # fd 9 is the hook lock. ollama must not inherit it, or the next
    # start blocks on flock until this process exits.
    "$bin" serve 9>&- &
    printf '%s\n' "$!" >"$pid_file"

    for _ in $(seq 1 20); do
        if ollama_listening; then
            log "Ollama escutando pid=$(cat "$pid_file")"
            return 0
        fi

        sleep 0.5
    done

    log "Ollama não abriu 127.0.0.1:11434"
}

stop_ollama() {
    local pid

    if [ ! -f "$pid_file" ]; then
        log "nenhum Ollama deste hook para parar"
        return 0
    fi

    pid=$(tr -d '[:space:]' <"$pid_file")
    rm -f "$pid_file"

    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        log "pid do Ollama já tinha saído"
        return 0
    fi

    kill "$pid" 2>/dev/null || true

    for _ in $(seq 1 10); do
        if ! kill -0 "$pid" 2>/dev/null; then
            log "Ollama parado pid=${pid}"
            return 0
        fi

        sleep 0.5
    done

    kill -9 "$pid" 2>/dev/null || true
    log "Ollama morto pid=${pid}"
}

run_locked() {
    mkdir -p "$state_dir"

    (
        exec 9>>"$lock_file"
        flock -w 120 9 || exit 0
        "$@"
    )
}

if [ "$domain" != "vid2agent-code" ]; then
    exit 0
fi

mkdir -p "$state_dir"
printf '%s vid2agent-hook: chamado %s:%s\n' "$(date -Iseconds)" "$operation" "$phase" >>"$log_file"

case "${operation}:${phase}" in
    started:begin | restore:begin | reconnect:begin)
        # libvirt execs this script as session leader, so setsid fails and the
        # child never runs. nohup keeps the retry alive after the hook exits.
        # restore/begin is before QEMU accepts monitor commands.
        nohup "$0" "$domain" __ensure >>"$log_file" 2>&1 </dev/null &
        ;;
    __ensure:)
        run_locked ensure_forward_and_ollama
        ;;
    stopped:end | release:end)
        run_locked stop_ollama >>"$log_file" 2>&1
        ;;
    *)
        exit 0
        ;;
esac
