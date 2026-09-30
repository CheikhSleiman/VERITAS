#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

log "Building native Geogram/Vorpalite and wiring Geogram.jl"
deactivate_conda
resolve_source_locks

SRC_ROOT="${VERITAS_SRC_ROOT:-$HOME/src}"
SRC="$SRC_ROOT/geogram"
PLATFORM="Linux64-gcc-dynamic"
BUILD_DIR="$SRC/build/${PLATFORM}-Release"
VORPALITE="$BUILD_DIR/bin/vorpalite"
mkdir -p "$SRC_ROOT"

[[ -d "$SRC/.git" ]] || git clone --recurse-submodules "$GEOGRAM_REPO" "$SRC"
[[ -z "$(git -C "$SRC" status --porcelain --untracked-files=no)" ]] || \
  die "$SRC has uncommitted tracked changes"

git -C "$SRC" fetch origin
git -C "$SRC" checkout --detach "$GEOGRAM_COMMIT"
git -C "$SRC" submodule update --init --recursive

# CRITICAL: Geogram/Vorpalite must be configured with the native Ubuntu
# compiler/CMake toolchain, not Conda's compiler wrappers.
NATIVE_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

BUILD_OK=false
if [[ -x "$VORPALITE" ]] && ! ldd "$VORPALITE" 2>/dev/null | grep -q 'not found'; then
  BUILD_OK=true
fi

if [[ "$BUILD_OK" == true ]]; then
  ok "Existing native Vorpalite is healthy; skipping rebuild"
else
  rm -rf "$BUILD_DIR"
  (
    cd "$SRC"
    env PATH="$NATIVE_PATH" CC=/usr/bin/gcc CXX=/usr/bin/g++ \
      ./configure.sh "$PLATFORM"
  )
  env PATH="$NATIVE_PATH" /usr/bin/cmake \
    --build "$BUILD_DIR" --parallel "${VERITAS_BUILD_JOBS:-$(nproc)}"
fi

[[ -x "$VORPALITE" ]] || die "Vorpalite not built: $VORPALITE"
if ldd "$VORPALITE" | grep -q 'not found'; then
  ldd "$VORPALITE"
  die "Vorpalite has unresolved libraries"
fi

export PATH="$HOME/.juliaup/bin:$PATH"

GEOGRAMJL_REPO="$GEOGRAMJL_REPO" GEOGRAMJL_COMMIT="$GEOGRAMJL_COMMIT" \
  julia --project="$VERITAS_ROOT" --startup-file=no - <<'JL'
using Pkg
Pkg.add(url=ENV["GEOGRAMJL_REPO"], rev=ENV["GEOGRAMJL_COMMIT"])
Pkg.instantiate()
Pkg.precompile()
using Geogram
println("Geogram.jl: ", pathof(Geogram))
JL

# Dynamically locate Geogram.jl; never hard-code ~/.julia/packages hashes.
JLROOT="$(julia --project="$VERITAS_ROOT" --startup-file=no -e 'using Geogram; print(dirname(dirname(pathof(Geogram))))')"
TARGET="$JLROOT/ext/geogram/lin64/bin"
mkdir -p "$TARGET"

# Preserve the bundled binary once, then wire the package to the native build.
if [[ -e "$TARGET/vorpalite" && ! -L "$TARGET/vorpalite" ]]; then
  if [[ ! -e "$TARGET/vorpalite.bundled" ]]; then
    mv "$TARGET/vorpalite" "$TARGET/vorpalite.bundled"
  else
    rm -f "$TARGET/vorpalite"
  fi
fi

ln -sfn "$VORPALITE" "$TARGET/vorpalite"
[[ -x "$TARGET/vorpalite" ]] || die "Vorpalite link is not executable"
[[ "$(readlink -f "$TARGET/vorpalite")" == "$(readlink -f "$VORPALITE")" ]] || \
  die "Geogram.jl Vorpalite link points to the wrong executable"

if ldd "$TARGET/vorpalite" | grep -q 'not found'; then
  ldd "$TARGET/vorpalite"
  die "Linked Vorpalite has unresolved libraries"
fi

ok "Geogram.jl wired to native Vorpalite: $VORPALITE"
