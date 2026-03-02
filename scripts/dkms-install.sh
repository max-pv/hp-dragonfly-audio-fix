#!/bin/bash
# dkms-install.sh — Register with DKMS for automatic rebuilds on kernel updates
#
# Usage: sudo ./scripts/dkms-install.sh [kernel-version] [EXTRA=<profile>]

set -euo pipefail

KVER="${1:-$(uname -r)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTRA_PROFILE=""
for arg in "$@"; do
    case "$arg" in
        EXTRA=*) EXTRA_PROFILE="${arg#EXTRA=}" ;;
    esac
done

DKMS_NAME="amd-rembrandt-sdw-fix"
DKMS_VER="1.0"
DKMS_SRC="/usr/src/${DKMS_NAME}-${DKMS_VER}"
UCM_DEST="/usr/share/alsa/ucm2/conf.d/amd-soundwire"
STATE_DIR="/var/lib/rembrandt-sdw-fix"
STATE_FILE="$STATE_DIR/extra-profile"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $(id -u) -eq 0 ]] || error "Run as root (sudo $0)"

info "Installing DKMS package ${DKMS_NAME}/${DKMS_VER}..."

# Copy source to DKMS tree
mkdir -p "$DKMS_SRC"
cp -a "$ROOT_DIR/dkms.conf" "$ROOT_DIR/scripts" "$ROOT_DIR/patches" "$ROOT_DIR/extras" "$DKMS_SRC/"
chmod +x "$DKMS_SRC/scripts/dkms-build.sh"

if [[ -n "$EXTRA_PROFILE" ]]; then
    EXTRA_DIR="$ROOT_DIR/extras/$EXTRA_PROFILE"
    [[ -d "$EXTRA_DIR" ]] || error "Extra profile not found: $EXTRA_PROFILE"
    printf '%s\n' "$EXTRA_PROFILE" > "$DKMS_SRC/extra-profile.conf"

    if [[ -d "$EXTRA_DIR/ucm" ]]; then
        mkdir -p "$UCM_DEST"
        while IFS= read -r f; do
            cp "$f" "$UCM_DEST/"
        done < <(find "$EXTRA_DIR/ucm" -maxdepth 1 -type f | sort)
    fi
    if [[ -d "$EXTRA_DIR/modprobe.d" ]]; then
        while IFS= read -r f; do
            cp "$f" /etc/modprobe.d/
        done < <(find "$EXTRA_DIR/modprobe.d" -maxdepth 1 -type f -name '*.conf' | sort)
    fi
fi

mkdir -p "$STATE_DIR"
printf '%s\n' "$EXTRA_PROFILE" > "$STATE_FILE"

# Register with DKMS (remove first if already registered)
if dkms status "${DKMS_NAME}/${DKMS_VER}" 2>/dev/null | grep -q "$DKMS_NAME"; then
    info "  DKMS module already registered, rebuilding..."
    dkms remove "${DKMS_NAME}/${DKMS_VER}" --all 2>/dev/null || true
fi

dkms add "${DKMS_NAME}/${DKMS_VER}"

info "  Building for kernel ${KVER}..."
dkms build "${DKMS_NAME}/${DKMS_VER}" -k "$KVER"

info "  Installing modules..."
dkms install "${DKMS_NAME}/${DKMS_VER}" -k "$KVER"

echo ""
info "✓ DKMS installation complete!"
info "  Modules will auto-rebuild when you install a new kernel."
info "  Reboot to activate."
if [[ -n "$EXTRA_PROFILE" ]]; then
    info "  Extra profile installed: $EXTRA_PROFILE"
fi
