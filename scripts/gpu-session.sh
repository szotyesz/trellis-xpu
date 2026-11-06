#!/usr/bin/env bash
# Frees the GPU for one command, then restores the LLM service.
#
# A detached guardian in its own session restores the service even if this
# script is killed outright, for example when the terminal session that
# started it ends. Leftover project containers are stopped too, so a job can
# never keep the GPU alongside the service.
set -euo pipefail
SERVICE=${GPU_SESSION_SERVICE:-llama-sycl}
LOG=${TMPDIR:-/tmp}/gpu-session-guardian.log

restore() {
    local left
    left=$(docker ps -q --filter label=com.docker.compose.project=trellis-xpu)
    # shellcheck disable=SC2086
    [[ -n "$left" ]] && docker stop -t 10 $left >/dev/null || true
    docker start "$SERVICE" >/dev/null
}

docker stop "$SERVICE"

setsid bash -c "
    $(declare -f restore)
    SERVICE=\$2
    while kill -0 \"\$1\" 2>/dev/null; do sleep 10; done
    echo \"\$(date '+%F %T') session \$1 gone, restoring \$SERVICE\"
    restore
" _ "$$" "$SERVICE" >>"$LOG" 2>&1 </dev/null &
guardian=$!

cleanup() {
    trap - EXIT INT TERM HUP
    [[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null || true
    kill "$guardian" 2>/dev/null || true
    restore
}
trap cleanup EXIT
trap 'exit 143' INT TERM HUP
# Run in the background: bash defers traps until a foreground child exits.
"$@" &
pid=$!
wait "$pid"
