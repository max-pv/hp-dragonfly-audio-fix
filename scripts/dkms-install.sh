#!/bin/bash
# dkms-install.sh — Register with DKMS for automatic rebuilds on kernel updates
#
# Usage: sudo ./scripts/dkms-install.sh [kernel-version]

set -euo pipefail

KVER="${1:-$(uname -r)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DKMS_NAME="hp-dragonfly-audio"
DKMS_VER="1.0"
DKMS_SRC="/usr/src/${DKMS_NAME}-${DKMS_VER}"
UCM_DEST="/usr/share/alsa/ucm2/conf.d/amd-soundwire"
MODPROBE_CONF="/etc/modprobe.d/hp-dragonfly-audio.conf"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $(id -u) -eq 0 ]] || error "Run as root (sudo $0)"

info "Installing DKMS package ${DKMS_NAME}/${DKMS_VER}..."

# Copy source to DKMS tree
mkdir -p "$DKMS_SRC"
cp -a "$ROOT_DIR/dkms.conf" "$ROOT_DIR/scripts" "$ROOT_DIR/patches" "$DKMS_SRC/"
chmod +x "$DKMS_SRC/scripts/dkms-build.sh"

# Install UCM and modprobe config (these don't change per-kernel)
mkdir -p "$UCM_DEST"
cp "$ROOT_DIR/ucm/amd-soundwire.conf" "$UCM_DEST/amd-soundwire.conf"
cp "$ROOT_DIR/ucm/HiFi.conf" "$UCM_DEST/HiFi.conf"
cat > "$MODPROBE_CONF" <<'EOF'
softdep snd_acp_sdw_legacy_mach pre: snd_soc_dmic snd_ps_pdm_dma
options snd_acp_sdw_legacy_mach quirk=32800
EOF

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
