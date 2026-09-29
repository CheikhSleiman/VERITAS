#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
log "Installing native Ubuntu dependencies"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
 git curl wget ca-certificates build-essential gcc g++ gfortran cmake ninja-build pkg-config unzip zip dos2unix \
 libglu1-mesa libgl1-mesa-dri libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev libtbb-dev
ok "Native Ubuntu toolchain ready"
