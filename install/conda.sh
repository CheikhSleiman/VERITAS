#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

log "Creating/updating Conda mechanics environment"
source_conda

# Mamba/libmamba is intentionally used here: this environment contains a
# constrained FEniCSx/PETSc/MFront/MPI stack and the classic conda solver can
# spend a very long time resolving it.
if conda env list | awk '{print $1}' | grep -Fxq "$CONDA_ENV_NAME"; then
  mamba env update -n "$CONDA_ENV_NAME" -f "$VERITAS_ROOT/environment.yml" --prune -y
else
  mamba env create -f "$VERITAS_ROOT/environment.yml" -y
fi

conda activate "$CONDA_ENV_NAME"

# Required workaround: conda-forge MFront 5.1.0 tfel-config may retain its
# feedstock build prefix. Persisting TFELHOME fixes include/library discovery.
conda env config vars set TFELHOME="$CONDA_PREFIX" >/dev/null
conda deactivate
conda activate "$CONDA_ENV_NAME"

expected="$CONDA_PREFIX/include"
actual="$(tfel-config --include-path)"
[[ "$actual" == "$expected" ]] || die "TFEL include path '$actual' != '$expected'"

python - <<'PY'
import jax, jaxlib
import dolfinx
from mpi4py import MPI
import mgis.behaviour

print("Python:", __import__("sys").version.split()[0])
print("DOLFINx:", dolfinx.__version__)
print("MPI vendor:", MPI.get_vendor())
print("JAX:", jax.__version__)
print("jaxlib:", jaxlib.__version__)
print("MGIS Python bindings: OK")
PY

mfront --version

# Exact package/build lock for Linux x86_64. This is the authoritative Conda
# provenance file to commit after validating a fresh install.
conda list --explicit > "$LOCK_DIR/conda-linux-64.lock"

ok "Conda mechanics environment ready; TFELHOME=$TFELHOME"
