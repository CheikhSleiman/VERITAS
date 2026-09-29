#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

log "Installing dolfinx_materials"
resolve_source_locks
activate_veritas

SRC_ROOT="${VERITAS_SRC_ROOT:-$HOME/src}"
SRC="$SRC_ROOT/dolfinx_materials"
mkdir -p "$SRC_ROOT"

[[ -d "$SRC/.git" ]] || git clone "$DOLFINX_MATERIALS_REPO" "$SRC"
[[ -z "$(git -C "$SRC" status --porcelain --untracked-files=no)" ]] || \
  die "$SRC has uncommitted tracked changes"

git -C "$SRC" fetch origin
git -C "$SRC" checkout --detach "$DOLFINX_MATERIALS_COMMIT"

# Editable install is intentional: this is how the validated VERITAS distro is
# configured. Dependencies come from environment.yml and are not re-resolved by pip.
python -m pip install --no-deps -e "$SRC"

python - <<'PY'
import importlib.metadata as md
import jax
import dolfinx_materials
from dolfinx_materials.mfront import MFrontMaterial
from dolfinx_materials.quadrature_map import QuadratureMap

print("dolfinx_materials:", md.version("dolfinx-materials"))
print("dolfinx_materials path:", dolfinx_materials.__file__)
print("JAX array type:", jax.Array)
print("MFrontMaterial import: OK")
print("QuadratureMap import: OK")
PY

ok "dolfinx_materials installed at $DOLFINX_MATERIALS_COMMIT"
