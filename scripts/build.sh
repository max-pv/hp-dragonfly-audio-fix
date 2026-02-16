#!/bin/bash
# build.sh — Build patched AMD audio kernel modules for HP Dragonfly Pro
#
# Usage:
#   ./build.sh                    # Auto-detect kernel source
#   ./build.sh KSRC=/linux-6.18.9 # Use specific kernel source tree
#   ./build.sh KVER=6.18.9-200.fc43.x86_64  # Build for specific kernel version
#
# Requirements:
#   - Build tools: gcc, make, xz, patch
#   - Full kernel source tree with patches already applied, or matching clean source
#
# Output:
#   compiled/<kernel-version>/*.ko.xz
#
# Notes:
#   The build happens IN the source tree (no copy). Build artifacts are cleaned up.
#   The source tree must have the audio patches applied before building.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCH_FILE="$ROOT_DIR/patches/full-diff.patch"

# Parse arguments
KSRC=""
KVER=""
JOBS="$(nproc)"
for arg in "$@"; do
    case "$arg" in
        KSRC=*) KSRC="${arg#KSRC=}" ;;
        KVER=*) KVER="${arg#KVER=}" ;;
        JOBS=*) JOBS="${arg#JOBS=}" ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# Default KVER to running kernel
KVER="${KVER:-$(uname -r)}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[BUILD]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()  { echo -e "${CYAN}[STEP]${NC} $*"; }

# ── Locate kernel source ────────────────────────────────────────────────

find_kernel_source() {
    if [[ -n "$KSRC" ]]; then
        [[ -f "$KSRC/Makefile" ]] || error "KSRC=$KSRC does not contain a kernel Makefile"
        echo "$KSRC"
        return
    fi

    # Try common locations
    local base_ver="${KVER%%-*}"  # e.g. "6.18.9" from "6.18.9-200.fc43.x86_64"
    for candidate in \
        "/linux-${base_ver}" \
        "/usr/src/linux-${base_ver}" \
        "$HOME/linux-${base_ver}" \
        ; do
        if [[ -d "$candidate" && -f "$candidate/Makefile" ]]; then
            # Need full source (not just kernel-devel headers)
            if [[ -f "$candidate/sound/soc/amd/ps/pci-ps.c" ]]; then
                echo "$candidate"
                return
            fi
        fi
    done

    error "Could not find kernel source tree with AMD audio sources.
You need the full kernel source (not just headers).

Clone from GitHub:
  KVER_BASE=\$(uname -r | cut -d- -f1)
  git clone --depth 1 --branch v\${KVER_BASE} https://github.com/torvalds/linux.git

Then re-run:
  $0 KSRC=/path/to/linux"
}

# ── Validate prerequisites ──────────────────────────────────────────────

check_prerequisites() {
    local missing=()
    for cmd in gcc make patch xz; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing[*]}
Install gcc, make, patch, and xz using your package manager."
    fi

    [[ -f "$PATCH_FILE" ]] || error "Patch file not found: $PATCH_FILE"
}

# ── Apply patch if needed ───────────────────────────────────────────────

apply_patch_if_needed() {
    local ksrc="$1"

    cd "$ksrc"
    if patch -p1 --dry-run -R < "$PATCH_FILE" &>/dev/null; then
        info "Patch already applied in source tree ✓"
    elif patch -p1 --dry-run < "$PATCH_FILE" &>/dev/null; then
        step "Applying audio patch..."
        patch -p1 < "$PATCH_FILE"
    else
        error "Failed to apply patch. Source tree may be incompatible.
Ensure the source tree matches the kernel version the patch was written for."
    fi
}

# ── Build modules ───────────────────────────────────────────────────────

build_modules() {
    local ksrc="$1"
    local outdir="$ROOT_DIR/compiled/$KVER"
    mkdir -p "$outdir"

    cd "$ksrc"

    step "Preparing kernel configuration..."
    if [[ ! -f "$ksrc/.config" ]]; then
        if [[ -f "/boot/config-$KVER" ]]; then
            cp "/boot/config-$KVER" "$ksrc/.config"
        elif [[ -f "/usr/src/kernels/$KVER/.config" ]]; then
            cp "/usr/src/kernels/$KVER/.config" "$ksrc/.config"
        else
            error "No kernel .config found for $KVER"
        fi
        make olddefconfig &>/dev/null
    fi

    # Ensure build infrastructure is ready
    if [[ ! -f "$ksrc/scripts/basic/fixdep" ]]; then
        make modules_prepare -j"$JOBS" &>/dev/null
    fi

    step "Building patched modules (using $JOBS parallel jobs)..."
    # Use KBUILD_MODPOST_WARN=1 for out-of-tree M= builds since vmlinux symbols
    # can't be resolved at build time but will resolve at module load time
    make -j"$JOBS" KBUILD_MODPOST_WARN=1 M=sound/soc/amd/ps modules 2>&1 | grep -v '^WARNING: modpost' || true
    make -j"$JOBS" KBUILD_MODPOST_WARN=1 M=sound/soc/amd/acp modules 2>&1 | grep -v '^WARNING: modpost' || true
    make -j"$JOBS" KBUILD_MODPOST_WARN=1 M=sound/soc/amd/yc modules 2>&1 | grep -v '^WARNING: modpost' || true
    make -j"$JOBS" KBUILD_MODPOST_WARN=1 M=drivers/soundwire modules 2>&1 | grep -v '^WARNING: modpost' || true

    step "Compressing modules with xz (CRC32)..."
    local modules=(
        "sound/soc/amd/ps/snd-pci-ps.ko"
        "sound/soc/amd/ps/snd-ps-sdw-dma.ko"
        "sound/soc/amd/acp/snd-soc-acpi-amd-match.ko"
        "sound/soc/amd/acp/snd-amd-sdw-acpi.ko"
        "sound/soc/amd/acp/snd-acp-sdw-legacy-mach.ko"
        "sound/soc/amd/yc/snd-pci-acp6x.ko"
        "drivers/soundwire/soundwire-amd.ko"
    )

    local success=0
    local fail=0
    for mod in "${modules[@]}"; do
        local bname="$(basename "$mod")"
        if [[ -f "$ksrc/$mod" ]]; then
            xz --check=crc32 -f -c "$ksrc/$mod" > "$outdir/${bname}.xz"
            info "  ✓ ${bname}.xz ($(du -h "$outdir/${bname}.xz" | cut -f1))"
            success=$((success + 1))
        else
            warn "  ✗ $bname (not found — build may have failed)"
            fail=$((fail + 1))
        fi
    done

    # Clean build artifacts from source tree
    step "Cleaning build artifacts from source tree..."
    make -j"$JOBS" M=sound/soc/amd/ps clean &>/dev/null || true
    make -j"$JOBS" M=sound/soc/amd/acp clean &>/dev/null || true
    make -j"$JOBS" M=sound/soc/amd/yc clean &>/dev/null || true
    make -j"$JOBS" M=drivers/soundwire clean &>/dev/null || true

    # Also clean our temp build dir if it exists
    rm -rf "$ROOT_DIR/.build"

    if [[ $fail -gt 0 ]]; then
        warn "$success of ${#modules[@]} modules built. $fail failed."
        warn "Check build output above for errors."
    else
        info "All $success modules built successfully!"
    fi

    echo ""
    info "Output: $outdir/"
    ls -lh "$outdir/"
}

# ── Main ────────────────────────────────────────────────────────────────

echo ""
info "HP Dragonfly Pro Audio Fix — Module Builder"
info "Target kernel: $KVER"
echo ""

check_prerequisites

step "Locating kernel source..."
KSRC_FOUND="$(find_kernel_source)"
info "Using kernel source: $KSRC_FOUND"

apply_patch_if_needed "$KSRC_FOUND"
build_modules "$KSRC_FOUND"

echo ""
info "✓ Build complete!"
info "To install: sudo make install"
info "For auto-rebuild on kernel updates: sudo make dkms-install"
