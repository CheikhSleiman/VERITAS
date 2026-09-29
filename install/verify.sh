#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

log "End-to-end verification"
resolve_source_locks
activate_veritas

python - <<'PY_MECH'
import importlib.metadata as md
import jax, jaxlib
import dolfinx
import mgis.behaviour
from mpi4py import MPI
from dolfinx_materials.mfront import MFrontMaterial
from dolfinx_materials.quadrature_map import QuadratureMap

print("DOLFINx:", dolfinx.__version__)
print("dolfinx_materials:", md.version("dolfinx-materials"))
print("MPI vendor:", MPI.get_vendor())
print("JAX:", jax.__version__)
print("jaxlib:", jaxlib.__version__)
print("MGIS import: OK")
print("MFrontMaterial import: OK")
print("QuadratureMap import: OK")
PY_MECH

mpiexec -n 2 python -c \
  "from mpi4py import MPI; print('rank',MPI.COMM_WORLD.rank,'of',MPI.COMM_WORLD.size)"

[[ "$(tfel-config --include-path)" == "$CONDA_PREFIX/include" ]] || \
  die "TFEL include path is wrong"

# Compile and load a real MFront behaviour. This verifies the entire
# FEniCSx <-> dolfinx_materials <-> MGIS <-> MFront chain, not only imports.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/Plasticity.mfront" <<'EOF_MFRONT'
@DSL IsotropicPlasticMisesFlow;
@Behaviour Plasticity;
@Parameter H  = 22e9;
@Parameter s0 = 200e6;
@FlowRule{
  f       = seq-H*p-s0;
  df_dseq = 1;
  df_dp   = -H;
}
EOF_MFRONT

(
  cd "$TMP"
  mfront --obuild --interface=generic Plasticity.mfront
  [[ -f src/libBehaviour.so ]]
  python - <<'PY_LOAD'
from pathlib import Path
from dolfinx_materials.mfront import MFrontMaterial
lib = Path("src/libBehaviour.so").resolve()
MFrontMaterial(str(lib), "Plasticity", hypothesis="3d")
print("FEniCSx <-> dolfinx_materials <-> MGIS <-> MFront: OK")
PY_LOAD
)

conda deactivate || true
export PATH="$HOME/.juliaup/bin:$PATH"

julia --project="$VERITAS_ROOT" --startup-file=no - <<'JL_VERIFY'
using Comodo
using GeometryBasics
using FileIO
using MeshIO
using GLMakie
using TiffImages
using ImageCore
using NearestNeighbors
using Geogram

@assert isdefined(Comodo, :mesh2bool)
println("Julia: ", VERSION)
println("Comodo load + mesh2bool: OK")
println("GLMakie import: OK")

root = dirname(dirname(pathof(Geogram)))
vorpalite = joinpath(root, "ext", "geogram", "lin64", "bin", "vorpalite")
@assert isfile(vorpalite)
@assert Sys.isexecutable(vorpalite)
println("Native Vorpalite: ", vorpalite)
JL_VERIFY

# Provenance report for the validated machine.
REPORT="$LOCK_DIR/installed-versions.txt"
{
  echo "Generated: $(date -Is)"
  echo '[system]'
  uname -a
  /usr/bin/gcc --version | head -1
  /usr/bin/g++ --version | head -1
  /usr/bin/gfortran --version | head -1
  /usr/bin/cmake --version | head -1
  /usr/bin/ninja --version

  echo '[conda]'
  source_conda
  conda activate "$CONDA_ENV_NAME"
  python --version
  python - <<'PY_REPORT'
import importlib.metadata as md
import jax, jaxlib, dolfinx
from mpi4py import MPI
print('dolfinx', dolfinx.__version__)
print('dolfinx_materials', md.version('dolfinx-materials'))
print('jax', jax.__version__)
print('jaxlib', jaxlib.__version__)
print('mpi', MPI.get_vendor())
PY_REPORT
  mfront --version
  echo "TFELHOME=$TFELHOME"

  echo '[julia]'
  julia --version
  julia --project="$VERITAS_ROOT" --startup-file=no -e 'using Pkg; Pkg.status()'

  echo '[source revisions]'
  cat "$SOURCE_LOCK"
} > "$REPORT"

ok "All VERITAS dependency checks passed; provenance: $REPORT"
