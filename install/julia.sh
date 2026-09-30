#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

log "Installing/verifying Julia + VERITAS Julia dependencies"
deactivate_conda
resolve_source_locks

export PATH="$HOME/.juliaup/bin:$PATH"

if ! command -v juliaup >/dev/null 2>&1; then
  curl -fsSL https://install.julialang.org | sh -s -- --yes --default-channel="$JULIA_VERSION"
  export PATH="$HOME/.juliaup/bin:$PATH"
fi

juliaup add "$JULIA_VERSION"
juliaup default "$JULIA_VERSION"

actual="$(julia -e 'print(VERSION)')"
[[ "$actual" == "$JULIA_VERSION" ]] || die "Expected Julia $JULIA_VERSION, got $actual"

# Comodo release 1.0.3 did not contain all functionality required by the
# translated VERITAS pipeline (notably the version we validated uses newer
# mesh/image functionality). Install the exact locked Git revision instead.
COMODO_REPO="$COMODO_REPO" COMODO_COMMIT="$COMODO_COMMIT" \
  julia --project="$VERITAS_ROOT" --startup-file=no - <<'JL'
# Download the existing manifest dependencies before changing package specs.
# On a fresh depot, Git-tracked packages such as Geogram are not present yet.
using Pkg
Pkg.instantiate(; allow_autoprecomp=false)
Pkg.add(url=ENV["COMODO_REPO"], rev=ENV["COMODO_COMMIT"])
for pkg in (
    "GeometryBasics",
    "FileIO",
    "MeshIO",
    "GLMakie",
    "TiffImages",
    "ImageCore",
    "NearestNeighbors",
)
    Pkg.add(pkg)
end
Pkg.instantiate()
Pkg.precompile()
using Comodo, GeometryBasics, FileIO, MeshIO, GLMakie, TiffImages, ImageCore, NearestNeighbors
@assert isdefined(Comodo, :mesh2bool)
println("Julia: ", VERSION)
println("Comodo: ", pathof(Comodo))
println("VERITAS Julia dependencies: OK")
JL

ok "Julia + VERITAS Julia dependencies ready"
