#!/bin/bash
# dkms-build.sh — Called by DKMS to build patched modules for a new kernel
#
# Usage (called by DKMS automatically):
#   dkms-build.sh <kernel-version> <build-output-dir>
#
# This script:
#   1. Finds kernel source for the target version
#   2. Copies it to a temp build area
#   3. Applies the audio patch
#   4. Builds the 7 modules
#   5. Copies .ko files to the DKMS build output directory

set -euo pipefail

KVER="${1:?Usage: dkms-build.sh <kernel-version> <build-output-dir>}"
BUILD_OUT="${2:?Usage: dkms-build.sh <kernel-version> <build-output-dir>}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCH_FILE="$ROOT_DIR/patches/full-diff.patch"
JOBS="$(nproc)"

log() { echo "[dkms-build] $*"; }
die() { echo "[dkms-build] ERROR: $*" >&2; exit 1; }

# ── Find kernel source ──────────────────────────────────────────────────

find_kernel_source() {
    local base_ver="${KVER%%-*}"
    for candidate in \
        "/linux-${base_ver}" \
        "/usr/src/linux-${base_ver}" \
        "$HOME/linux-${base_ver}" \
        ; do
        if [[ -d "$candidate" && -f "$candidate/sound/soc/amd/ps/pci-ps.c" ]]; then
            echo "$candidate"
            return
        fi
    done

    # No full source tree found
    die "No kernel source tree found for version $base_ver.

DKMS needs the full kernel source to build these modules.
Please ensure one of these exists:
  /linux-${base_ver}/
  /usr/src/linux-${base_ver}/

Clone from GitHub:
  git clone --depth 1 --branch v${base_ver} https://github.com/torvalds/linux.git
  sudo mv linux /usr/src/linux-${base_ver}

Then retry: sudo dkms build hp-dragonfly-audio/1.0 -k $KVER"
}

# ── Main build ───────────────────────────────────────────────────────────

log "Building HP Dragonfly Pro audio modules for kernel $KVER"

[[ -f "$PATCH_FILE" ]] || die "Patch not found: $PATCH_FILE"

KSRC="$(find_kernel_source)"
log "Using kernel source: $KSRC"

BUILDDIR="$(mktemp -d /tmp/hp-audio-dkms-XXXXXX)"
trap "rm -rf $BUILDDIR" EXIT

log "Copying kernel source to build area..."
cp -a "$KSRC/." "$BUILDDIR/"

log "Applying audio patch..."
cd "$BUILDDIR"
if patch -p1 --dry-run -R < "$PATCH_FILE" &>/dev/null; then
    log "Patch already applied in source tree, proceeding..."
elif patch -p1 --dry-run < "$PATCH_FILE" &>/dev/null; then
    patch -p1 < "$PATCH_FILE"
else
    die "Failed to apply patch"
fi

log "Preparing build configuration..."
if [[ ! -f "$BUILDDIR/.config" ]]; then
    if [[ -f "/boot/config-$KVER" ]]; then
        cp "/boot/config-$KVER" "$BUILDDIR/.config"
    elif [[ -f "/usr/src/kernels/$KVER/.config" ]]; then
        cp "/usr/src/kernels/$KVER/.config" "$BUILDDIR/.config"
    else
        die "No kernel .config found for $KVER"
    fi
fi

make olddefconfig &>/dev/null
make modules_prepare -j"$JOBS" &>/dev/null

log "Building modules ($JOBS parallel jobs)..."
make -j"$JOBS" M=sound/soc/amd/ps modules
make -j"$JOBS" M=sound/soc/amd/acp modules
make -j"$JOBS" M=sound/soc/amd/yc modules
make -j"$JOBS" M=drivers/soundwire modules

log "Collecting built modules..."
mkdir -p "$BUILD_OUT"

MODULES=(
    "sound/soc/amd/ps/snd-pci-ps.ko"
    "sound/soc/amd/ps/snd-ps-sdw-dma.ko"
    "sound/soc/amd/acp/snd-soc-acpi-amd-match.ko"
    "sound/soc/amd/acp/snd-amd-sdw-acpi.ko"
    "sound/soc/amd/acp/snd-acp-sdw-legacy-mach.ko"
    "sound/soc/amd/yc/snd-pci-acp6x.ko"
    "drivers/soundwire/soundwire-amd.ko"
)

for mod in "${MODULES[@]}"; do
    local_name="$(basename "$mod")"
    if [[ -f "$BUILDDIR/$mod" ]]; then
        cp "$BUILDDIR/$mod" "$BUILD_OUT/$local_name"
        log "  ✓ $local_name"
    else
        log "  ✗ $local_name (not found — check kernel config)"
    fi
done

log "Build complete!"
