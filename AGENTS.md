# HP Dragonfly Pro Audio Fix

## What This Is

An out-of-tree kernel module patchset that enables internal speaker audio on the HP Dragonfly Pro laptop (AMD Rembrandt ACP 6.0 + 2× Realtek RT1316 SoundWire amplifiers). It patches 7 kernel modules, provides ALSA UCM profiles, and supports DKMS for automatic rebuilds on kernel updates.

## Architecture

The single source of truth for all code changes is `patches/full-diff.patch` — a unified diff against the upstream kernel tree. The `patches/upstream/` directory contains the same changes split into 4 patches formatted for kernel mailing list submission (generated from the unified patch, not independently maintained).

The build system (`scripts/build.sh`) works by applying the patch to a full kernel source tree, then running `make modules` for 4 subdirectories (`sound/soc/amd/ps`, `sound/soc/amd/acp`, `sound/soc/amd/yc`, `drivers/soundwire`). Built modules are xz-compressed with `--check=crc32` (kernel requirement) and placed in `compiled/<kernel-version>/`.

Two install paths exist:
- **Build-from-source** (`make build && sudo make install`) — any kernel
- **DKMS** (`sudo make dkms-install`) — auto-rebuilds on kernel updates via `scripts/dkms-build.sh`

The UCM profile (`ucm/`) configures PipeWire/ALSA speaker and mic routing. The modprobe config sets `quirk=32768` on the machine driver.

## Build Commands

```bash
# Build modules (requires full kernel source tree, not just kernel-devel headers)
make build KSRC=/path/to/linux-source

# Build for a specific kernel version
make build KSRC=/path/to/linux-source KVER=6.18.9-200.fc43.x86_64

# Install (requires root)
sudo make install

# Uninstall (restores from backup)
sudo make uninstall

# DKMS install/remove
sudo make dkms-install
sudo make dkms-remove

# Clean build artifacts
make clean
```

There are no tests or linters in this project.

## Key Conventions

- All shell scripts live in `scripts/` and use `set -euo pipefail` and colored log helper functions (`info`, `warn`, `error`).
- The Makefile is a thin wrapper that delegates to `scripts/*.sh`.
- `make install` backs up original modules to `compiled/backup-<kver>/` before overwriting. `make uninstall` restores from this backup.
- The DKMS build (`scripts/dkms-build.sh`) copies the full kernel source to a temp directory before patching so the original tree stays clean, unlike `scripts/build.sh` which patches in-place.
- Module install uses `dd if=... of=... bs=4k` with `cp` as fallback (avoids filesystem copy-on-write issues on some setups).
