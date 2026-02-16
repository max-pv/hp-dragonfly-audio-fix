#!/bin/bash
# dkms-remove.sh — Remove DKMS registration
#
# Usage: sudo ./scripts/dkms-remove.sh

set -euo pipefail

DKMS_NAME="hp-dragonfly-audio"
DKMS_VER="1.0"
DKMS_SRC="/usr/src/${DKMS_NAME}-${DKMS_VER}"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $(id -u) -eq 0 ]] || error "Run as root (sudo $0)"

info "Removing DKMS package ${DKMS_NAME}/${DKMS_VER}..."
dkms remove "${DKMS_NAME}/${DKMS_VER}" --all 2>/dev/null || true
rm -rf "$DKMS_SRC"

info "✓ DKMS package removed."
info "  Note: UCM profile and modprobe config are still installed."
info "  To fully uninstall: sudo make uninstall"
