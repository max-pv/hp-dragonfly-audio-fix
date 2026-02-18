#!/bin/bash
# uninstall.sh — Restore original kernel modules and remove config
#
# Usage: sudo ./scripts/uninstall.sh [kernel-version]

set -euo pipefail

KVER="${1:-$(uname -r)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

MODDIR="/lib/modules/$KVER/kernel"
BACKUP_DIR="$ROOT_DIR/compiled/backup-$KVER"
UCM_DEST="/usr/share/alsa/ucm2/conf.d/amd-soundwire"
MODPROBE_CONF="/etc/modprobe.d/hp-dragonfly-audio.conf"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

declare -A MODULES=(
    ["snd-pci-ps.ko.xz"]="sound/soc/amd/ps"
    ["snd-ps-sdw-dma.ko.xz"]="sound/soc/amd/ps"
    ["snd-ps-pdm-dma.ko.xz"]="sound/soc/amd/ps"
    ["snd-soc-acpi-amd-match.ko.xz"]="sound/soc/amd/acp"
    ["snd-amd-sdw-acpi.ko.xz"]="sound/soc/amd/acp"
    ["snd-acp-sdw-legacy-mach.ko.xz"]="sound/soc/amd/acp"
    ["snd-pci-acp6x.ko.xz"]="sound/soc/amd/yc"
    ["soundwire-amd.ko.xz"]="drivers/soundwire"
)

[[ $(id -u) -eq 0 ]] || error "Run as root (sudo $0)"

# Restore from backup if available
if [[ -d "$BACKUP_DIR" ]]; then
    info "Restoring original modules from backup..."
    for mod in "${!MODULES[@]}"; do
        if [[ -f "$BACKUP_DIR/$mod" ]]; then
            cp "$BACKUP_DIR/$mod" "$MODDIR/${MODULES[$mod]}/$mod"
            info "  Restored: $mod"
        fi
    done
else
    warn "No backup found for kernel $KVER."
    warn "Skipping module restore. Reinstall your kernel's modules package to restore originals."
fi

# Remove config files
rm -f "$MODPROBE_CONF"
rm -rf "$UCM_DEST"
depmod -a "$KVER"

echo ""
info "✓ Uninstall complete. Reboot to restore original behavior."
