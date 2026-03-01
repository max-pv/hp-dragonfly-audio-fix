#!/bin/bash
# fetch-kernel-source.sh — Download and prepare distro-matched kernel source
#
# Usage:
#   ./scripts/fetch-kernel-source.sh
#   ./scripts/fetch-kernel-source.sh --kver 6.18.12-200.fc43.x86_64
#   ./scripts/fetch-kernel-source.sh --out /tmp/kernel-src --print-path
#
# Notes:
#   - This script prepares FULL source (not kernel-devel headers).
#   - For Fedora/RHEL-like distros it fetches the matching kernel SRPM and applies
#     distro patches, then prepares the tree for module builds.

set -euo pipefail

KVER="$(uname -r)"
PRINT_PATH=0
OUT_DIR=""

usage() {
    cat <<'EOF'
Usage: fetch-kernel-source.sh [options]

Options:
  --kver <version>   Kernel version to prepare (default: running kernel)
  --out <dir>        Output directory root (default: <repo>/buildsrc/<base-version>)
  --print-path       Print only the prepared source path to stdout
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kver)
            KVER="${2:-}"
            shift 2
            ;;
        --out)
            OUT_DIR="${2:-}"
            shift 2
            ;;
        --print-path)
            PRINT_PATH=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_VER="${KVER%%-*}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/buildsrc/$BASE_VER}"
JOBS="$(nproc)"

log() { echo "[fetch-kernel-source] $*" >&2; }
die() { echo "[fetch-kernel-source] ERROR: $*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

source /etc/os-release
DISTRO_ID="${ID:-unknown}"
DISTRO_LIKE="${ID_LIKE:-}"

is_fedora_like=0
if [[ "$DISTRO_ID" =~ ^(fedora|rhel|centos|rocky|almalinux)$ ]] || [[ "$DISTRO_LIKE" =~ (fedora|rhel) ]]; then
    is_fedora_like=1
fi

is_debian_like=0
if [[ "$DISTRO_ID" =~ ^(debian|ubuntu|linuxmint|pop)$ ]] || [[ "$DISTRO_LIKE" =~ debian ]]; then
    is_debian_like=1
fi

prepare_common_tree() {
    local src_dir="$1"
    local suffix

    [[ -d "$src_dir" ]] || die "Source directory not found: $src_dir"
    [[ -f "$src_dir/Makefile" ]] || die "No kernel Makefile in: $src_dir"
    [[ -f "$src_dir/sound/soc/amd/ps/pci-ps.c" ]] || die "Source tree is incomplete (missing AMD audio sources): $src_dir"

    suffix="${KVER#${BASE_VER}}"

    if [[ -n "$suffix" ]]; then
        sed -i "s/^EXTRAVERSION = .*/EXTRAVERSION = ${suffix}/" "$src_dir/Makefile"
    fi

    if [[ -f "/boot/config-${KVER}" ]]; then
        cp -f "/boot/config-${KVER}" "$src_dir/.config"
    elif [[ -f "/usr/src/kernels/${KVER}/.config" ]]; then
        cp -f "/usr/src/kernels/${KVER}/.config" "$src_dir/.config"
    else
        die "Could not find kernel config for ${KVER} in /boot or /usr/src/kernels"
    fi

    if [[ -f "/usr/src/kernels/${KVER}/Module.symvers" ]]; then
        cp -f "/usr/src/kernels/${KVER}/Module.symvers" "$src_dir/Module.symvers"
    fi

    (
        cd "$src_dir"
        export LOCALVERSION=
        make olddefconfig >/dev/null
        make prepare modules_prepare -j"$JOBS" >/dev/null
    )
}

prepare_fedora_tree() {
    require_cmd rpm2cpio
    require_cmd cpio
    require_cmd tar
    require_cmd patch

    mkdir -p "$OUT_DIR"
    local srpm=""
    local host_arch kver_noarch
    host_arch="$(uname -m)"
    kver_noarch="${KVER%.$host_arch}"

    pick_srpm() {
        local candidate=""
        for candidate in \
            "$OUT_DIR/kernel-${KVER}.src.rpm" \
            "$OUT_DIR/kernel-${kver_noarch}.src.rpm"; do
            [[ -f "$candidate" ]] && { echo "$candidate"; return 0; }
        done

        candidate="$(find "$OUT_DIR" -maxdepth 1 -type f -name "kernel-${BASE_VER}-*.src.rpm" | sort -V | tail -n 1 || true)"
        [[ -n "$candidate" ]] && { echo "$candidate"; return 0; }
        return 1
    }

    # Reuse an existing matching SRPM if present.
    srpm="$(pick_srpm || true)"

    # Try dnf source download first.
    if [[ -z "$srpm" ]] && command -v dnf >/dev/null 2>&1; then
        log "Trying dnf source download for kernel-${KVER}..."
        dnf -q download --source --destdir "$OUT_DIR" "kernel-${KVER}" >/dev/null 2>&1 || true
        srpm="$(pick_srpm || true)"
    fi

    # Fallback to koji if available.
    if [[ -z "$srpm" ]] && command -v koji >/dev/null 2>&1; then
        log "Trying koji source download for kernel-${KVER}..."
        (
            cd "$OUT_DIR"
            koji download-build --arch=src "kernel-${KVER}" >/dev/null
        ) || true
        srpm="$(pick_srpm || true)"
    fi

    [[ -n "$srpm" ]] || die "Could not download kernel-${KVER}.src.rpm (install/configure dnf source repos or install koji)."

    log "Extracting SRPM..."
    (
        cd "$OUT_DIR"
        rpm2cpio "$srpm" | cpio -idmu >/dev/null
    )

    local tarball patchfile src_dir
    tarball="$(ls -1 "$OUT_DIR"/linux-"$BASE_VER".tar.xz "$OUT_DIR"/linux-*.tar.xz 2>/dev/null | head -n 1 || true)"
    patchfile="$(ls -1 "$OUT_DIR"/patch-*-redhat.patch 2>/dev/null | head -n 1 || true)"
    [[ -n "$tarball" ]] || die "Kernel source tarball not found after SRPM extraction."
    [[ -n "$patchfile" ]] || die "Fedora/RHEL patch file not found after SRPM extraction."

    src_dir="$OUT_DIR/linux-${BASE_VER}"
    rm -rf "$src_dir"
    tar -C "$OUT_DIR" -xf "$tarball"

    log "Applying distro patchset..."
    if patch -d "$src_dir" -p1 --dry-run -R < "$patchfile" >/dev/null 2>&1; then
        :
    elif patch -d "$src_dir" -p1 --dry-run < "$patchfile" >/dev/null 2>&1; then
        patch -d "$src_dir" -p1 < "$patchfile" >/dev/null
    else
        die "Failed to apply distro patchset: $patchfile"
    fi

    if [[ -f "$OUT_DIR/Makefile.rhelver" ]]; then
        cp -f "$OUT_DIR/Makefile.rhelver" "$src_dir/"
    fi

    prepare_common_tree "$src_dir"
    echo "$src_dir"
}

prepare_debian_tree() {
    require_cmd apt
    require_cmd dpkg-source
    require_cmd patch

    mkdir -p "$OUT_DIR"
    log "Trying apt source download (requires deb-src enabled)..."
    (
        cd "$OUT_DIR"
        apt source linux >/dev/null
    ) || die "apt source failed. Enable deb-src repositories, run apt update, then retry."

    local src_dir
    src_dir="$(find "$OUT_DIR" -maxdepth 1 -mindepth 1 -type d -name "linux-*" | sort -V | tail -n 1)"
    [[ -n "${src_dir:-}" ]] || die "Could not locate extracted Debian/Ubuntu kernel source directory."

    prepare_common_tree "$src_dir"
    echo "$src_dir"
}

main() {
    local src_path
    log "Preparing source for kernel: $KVER"
    log "Output root: $OUT_DIR"

    if [[ $is_fedora_like -eq 1 ]]; then
        src_path="$(prepare_fedora_tree)"
    elif [[ $is_debian_like -eq 1 ]]; then
        src_path="$(prepare_debian_tree)"
    else
        die "Unsupported distro (${DISTRO_ID}). Use a full distro-matched source tree manually."
    fi

    if [[ $PRINT_PATH -eq 1 ]]; then
        printf '%s\n' "$src_path"
    else
        log "Prepared source tree: $src_path"
    fi
}

main
