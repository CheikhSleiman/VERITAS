#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for step in preflight system miniforge conda dolfinx_materials julia geogram verify; do
  printf '\n============================================================\n VERITAS install step: %s\n============================================================\n' "$step"
  bash "$ROOT/install/$step.sh"
done

printf '\nVERITAS dependency installation completed successfully.\n'
printf 'Open a new shell before normal use so shell initialization is refreshed.\n'
printf 'For accelerated GLMakie under this WSLg setup, run Julia with GALLIUM_DRIVER=d3d12.\n'
