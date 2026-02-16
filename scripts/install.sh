#!/bin/bash
# install.sh — Install patched audio modules, UCM profile, and modprobe config
#
# Usage: sudo ./scripts/install.sh [kernel-version]

set -euo pipefail

KVER="${1:-$(uname -r)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

MODDIR="/lib/modules/$KVER/kernel"
COMPILED="$ROOT_DIR/compiled/$KVER"
BACKUP_DIR="$ROOT_DIR/compiled/backup-$KVER"
UCM_DEST="/usr/share/alsa/ucm2/conf.d/amd-soundwire"
MODPROBE_CONF="/etc/modprobe.d/hp-dragonfly-audio.conf"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# Module name → kernel subdirectory
declare -A MODULES=(
    ["snd-pci-ps.ko.xz"]="sound/soc/amd/ps"
    ["snd-ps-sdw-dma.ko.xz"]="sound/soc/amd/ps"
    ["snd-soc-acpi-amd-match.ko.xz"]="sound/soc/amd/acp"
    ["snd-amd-sdw-acpi.ko.xz"]="sound/soc/amd/acp"
    ["snd-acp-sdw-legacy-mach.ko.xz"]="sound/soc/amd/acp"
    ["snd-pci-acp6x.ko.xz"]="sound/soc/amd/yc"
    ["soundwire-amd.ko.xz"]="drivers/soundwire"
)

[[ $(id -u) -eq 0 ]] || error "Run as root (sudo $0)"
[[ -d "$COMPILED" ]] || error "No compiled modules in $COMPILED/. Run 'make build' first."

# Backup originals
info "Backing up original modules..."
mkdir -p "$BACKUP_DIR"
for mod in "${!MODULES[@]}"; do
    dest="$MODDIR/${MODULES[$mod]}/$mod"
    if [[ -f "$dest" ]] && [[ ! -f "$BACKUP_DIR/$mod" ]]; then
        cp "$dest" "$BACKUP_DIR/$mod"
        info "  Backed up: $mod"
    fi
done

# Install patched modules
info "Installing patched modules..."
for mod in "${!MODULES[@]}"; do
    dest="$MODDIR/${MODULES[$mod]}/$mod"
    mkdir -p "$(dirname "$dest")"
    dd if="$COMPILED/$mod" of="$dest" bs=4k status=none 2>/dev/null \
        || cp "$COMPILED/$mod" "$dest"
    info "  Installed: $mod → ${MODULES[$mod]}/"
done

# Install UCM profile
info "Installing UCM profile..."
mkdir -p "$UCM_DEST"
cp "$ROOT_DIR/ucm/amd-soundwire.conf" "$UCM_DEST/amd-soundwire.conf"
cp "$ROOT_DIR/ucm/HiFi.conf" "$UCM_DEST/HiFi.conf"

# Install modprobe config
echo 'options snd_acp_sdw_legacy_mach quirk=32768' > "$MODPROBE_CONF"

# Rebuild module dependencies
depmod -a "$KVER"

echo ""
info "✓ Installation complete! Reboot to activate."
info "  Backup saved to: $BACKUP_DIR/"
