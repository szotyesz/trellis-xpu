#!/usr/bin/env bash
# Frees the GPU for one command, then restores the LLM service.
set -euo pipefail
docker stop llama-sycl
trap 'docker start llama-sycl' EXIT
"$@"
