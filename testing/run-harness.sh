#!/bin/bash
# run-harness.sh — Patch/integration validation harness

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

KVER="$(uname -r)"
KSRC=""
EXTRA_PROFILE=""
DO_FETCH=1
DO_BUILD=0

usage() {
    cat <<'EOF'
Usage: testing/run-harness.sh [options]

Options:
  --kver <version>     Kernel version to validate against (default: running kernel)
  --ksrc <path>        Use existing prepared kernel source path
  --no-fetch           Do not auto-fetch source when --ksrc is missing
  --extra <profile>    Validate extra profile patches (e.g., hp-dragonfly-pro)
  --build              Run module build smoke test after patch apply
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kver) KVER="${2:-}"; shift 2 ;;
        --ksrc) KSRC="${2:-}"; shift 2 ;;
        --no-fetch) DO_FETCH=0; shift ;;
        --extra) EXTRA_PROFILE="${2:-}"; shift 2 ;;
        --build) DO_BUILD=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
    esac
done

log() { echo "[harness] $*"; }
die() { echo "[harness] ERROR: $*" >&2; exit 1; }

[[ -f "$ROOT_DIR/patches/full-diff.patch" ]] || die "Missing patches/full-diff.patch"
[[ -d "$ROOT_DIR/patches/upstream" ]] || die "Missing patches/upstream/"

if [[ -z "$KSRC" ]]; then
    if [[ $DO_FETCH -eq 1 ]]; then
        log "Fetching/preparing source for $KVER..."
        KSRC="$("$ROOT_DIR/scripts/fetch-kernel-source.sh" --kver "$KVER" --print-path)"
    else
        die "--ksrc is required with --no-fetch"
    fi
fi

[[ -d "$KSRC" ]] || die "KSRC not found: $KSRC"
[[ -f "$KSRC/sound/soc/amd/ps/pci-ps.c" ]] || die "KSRC missing AMD audio sources: $KSRC"

TMP1="$(mktemp -d /tmp/rembrandt-harness-full-XXXXXX)"
TMP2="$(mktemp -d /tmp/rembrandt-harness-split-XXXXXX)"
trap 'rm -rf "$TMP1" "$TMP2"' EXIT

log "Copying source trees..."
cp -a "$KSRC/." "$TMP1/src"
cp -a "$KSRC/." "$TMP2/src"

# If we're validating an extra profile, the KSRC tree might already have those patches applied
# (e.g. after a prior build). Reverse them in the temp copies so base patch application is clean.
if [[ -n "$EXTRA_PROFILE" ]]; then
    EXTRA_DIR="$ROOT_DIR/extras/$EXTRA_PROFILE/patches"
    if [[ -d "$EXTRA_DIR" ]]; then
        for p in $(ls "$EXTRA_DIR"/*.patch 2>/dev/null | sort); do
            if patch -d "$TMP1/src" -p1 --dry-run -R < "$p" >/dev/null; then
                patch -d "$TMP1/src" -p1 -R < "$p" >/dev/null
            fi
            if patch -d "$TMP2/src" -p1 --dry-run -R < "$p" >/dev/null; then
                patch -d "$TMP2/src" -p1 -R < "$p" >/dev/null
            fi
        done
    fi
fi

log "Checking full patch applies cleanly..."
grep -q '^--- a/' "$ROOT_DIR/patches/full-diff.patch" || die "full-diff.patch missing '--- a/' paths"
grep -q '^+++ b/' "$ROOT_DIR/patches/full-diff.patch" || die "full-diff.patch missing '+++ b/' paths"
if patch -d "$TMP1/src" -p1 --dry-run -R < "$ROOT_DIR/patches/full-diff.patch" >/dev/null; then
    log "Full patch already applied in source; reversing in temp copy..."
    patch -d "$TMP1/src" -p1 -R < "$ROOT_DIR/patches/full-diff.patch" >/dev/null
fi
patch -d "$TMP1/src" -p1 --dry-run < "$ROOT_DIR/patches/full-diff.patch" >/dev/null
patch -d "$TMP1/src" -p1 < "$ROOT_DIR/patches/full-diff.patch" >/dev/null

log "Checking split patches apply cleanly..."
for p in $(ls "$ROOT_DIR"/patches/upstream/*.patch | sort); do
    if patch -d "$TMP2/src" -p1 --dry-run -R < "$p" >/dev/null; then
        patch -d "$TMP2/src" -p1 -R < "$p" >/dev/null
    fi
    patch -d "$TMP2/src" -p1 --dry-run < "$p" >/dev/null
    patch -d "$TMP2/src" -p1 < "$p" >/dev/null
done

if [[ -n "$EXTRA_PROFILE" ]]; then
    EXTRA_DIR="$ROOT_DIR/extras/$EXTRA_PROFILE/patches"
    [[ -d "$EXTRA_DIR" ]] || die "Extra profile patches not found: $EXTRA_PROFILE"
    log "Checking extra profile patches: $EXTRA_PROFILE"
    for p in $(ls "$EXTRA_DIR"/*.patch | sort); do
        if patch -d "$TMP1/src" -p1 --dry-run -R < "$p" >/dev/null; then
            patch -d "$TMP1/src" -p1 -R < "$p" >/dev/null
        fi
        patch -d "$TMP1/src" -p1 --dry-run < "$p" >/dev/null
        patch -d "$TMP1/src" -p1 < "$p" >/dev/null
    done
fi

log "Checking revision constants usage..."
grep -R "ACP60_PCI_REV" "$TMP1/src/sound/soc/amd" >/dev/null
grep -R "ACP6F_PCI_REV" "$TMP1/src/sound/soc/amd" >/dev/null
if grep -R "^[+].*case 0x60:" "$ROOT_DIR/patches" >/dev/null; then
    die "Magic revision value 'case 0x60' still added in patches/"
fi
if grep -R "^[+].*case 0x6f:" "$ROOT_DIR/patches" >/dev/null; then
    die "Magic revision value 'case 0x6f' still added in patches/"
fi
if grep -q "^[+].*ACP60_PCI_REV" "$ROOT_DIR/patches/full-diff.patch" &&
   ! grep -q "^[+][[:space:]]*#define ACP60_PCI_REV" "$ROOT_DIR/patches/full-diff.patch"; then
    die "full-diff.patch references ACP60_PCI_REV without defining it"
fi
if grep -q "^[+].*ACP6F_PCI_REV" "$ROOT_DIR/patches/full-diff.patch" &&
   ! grep -q "^[+][[:space:]]*#define ACP6F_PCI_REV" "$ROOT_DIR/patches/full-diff.patch"; then
    die "full-diff.patch references ACP6F_PCI_REV without defining it"
fi

if [[ $DO_BUILD -eq 1 ]]; then
    log "Running module build smoke test..."
    make -C "$TMP1/src" KBUILD_MODPOST_WARN=1 M=sound/soc/amd/ps modules >/dev/null
    make -C "$TMP1/src" KBUILD_MODPOST_WARN=1 M=sound/soc/amd/acp modules >/dev/null
    make -C "$TMP1/src" KBUILD_MODPOST_WARN=1 M=sound/soc/amd/yc modules >/dev/null
    make -C "$TMP1/src" KBUILD_MODPOST_WARN=1 M=drivers/soundwire modules >/dev/null
fi

log "PASS: patch harness checks completed."
