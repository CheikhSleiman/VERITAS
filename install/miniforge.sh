#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
log "Installing/verifying Miniforge"
ROOT="$(miniforge_root)"
INS="$HOME/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh"
URL="https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh"
if [[ ! -x "$ROOT/bin/conda" ]]; then
  wget -O "$INS" "$URL"
  printf '%s  %s\n' "$MINIFORGE_SHA256" "$INS" | sha256sum -c -
  bash "$INS" -b -p "$ROOT"
else
  ok "Existing Miniforge found at $ROOT"
fi
source "$ROOT/etc/profile.d/conda.sh"
conda config --set auto_activate_base false
conda init bash >/dev/null
"$ROOT/bin/conda" --version
"$ROOT/bin/mamba" --version
ok "Miniforge ready"
