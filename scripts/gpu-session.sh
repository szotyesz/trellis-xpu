#!/usr/bin/env bash
# Frees the GPU for one command, then restores the LLM service.
# If this script is stopped, the project's containers stop too, so a job can
# never keep the GPU alongside llama-sycl. SIGKILL cannot be caught.
set -euo pipefail

cleanup() {
    trap - EXIT INT TERM HUP
    [[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null || true
    local left
    left=$(docker ps -q --filter label=com.docker.compose.project=trellis-xpu)
    if [[ -n "$left" ]]; then
        # shellcheck disable=SC2086
        docker stop -t 10 $left >/dev/null || true
    fi
    docker start llama-sycl
}

docker stop llama-sycl
trap cleanup EXIT
trap 'exit 143' INT TERM HUP
# Run in the background: bash defers traps until a foreground child exits.
"$@" &
pid=$!
wait "$pid"
