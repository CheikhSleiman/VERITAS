#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
log "Preflight checks"
[[ "$(uname -m)" == x86_64 ]] || die "Expected x86_64"
source /etc/os-release
[[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]] || die "Expected Ubuntu 24.04"
grep -qi microsoft /proc/version 2>/dev/null && ok "WSL detected" || warn "WSL not detected; installer is validated on WSL2"
case "$VERITAS_ROOT" in /mnt/*) die "Move VERITAS to the Linux filesystem, e.g. /home/$USER/VERITAS";; esac
sudo -v
avail_kb="$(df -Pk "$HOME" | awk 'NR==2{print $4}')"
[[ "$avail_kb" -ge $((15*1024*1024)) ]] || warn "Less than 15 GiB free under HOME"
ok "Ubuntu 24.04 x86_64 and Linux filesystem confirmed"
