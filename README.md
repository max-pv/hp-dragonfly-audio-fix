# AMD Rembrandt SoundWire Audio Fix

Enable internal SoundWire audio on AMD Rembrandt platforms where ACP revision `0x60`/`0x6f`
is rejected by drivers that only accept ACP `0x63`.

> **Warning:** This project replaces in-kernel modules. Use at your own risk.

---

## What this fixes (generic)

This patch set is designed for **Rembrandt ACP 6.x systems** where the hardware is
register-compatible with ACP `0x63` but firmware/kernel combinations still fail to
enumerate SoundWire properly.

Typical symptoms:
- No internal speaker output
- PipeWire fallback to dummy output
- No SoundWire slave devices under `/sys/bus/soundwire/devices`

Core fix scope:
- ACP revision compatibility (`0x60`/`0x6f` paths)
- SoundWire manager bring-up
- ACPI property fallback (`mipi-sdw-master-list`)
- Runtime-ID collision fix for DMIC path

---

## Machine-specific extras

Some laptops need additional quirks beyond the generic patch set.

This repo separates those quirks into **extra profiles** under `extras/`.

Available profile:
- `hp-dragonfly-pro`

Use extras by passing `EXTRA=<profile>` to build/install targets.

---

## Quick Start

### 1) Prepare kernel source (automated)

```bash
KSRC="$(./scripts/fetch-kernel-source.sh --print-path)"
```

Supported in `fetch-kernel-source.sh`:
- Fedora/RHEL-like (`dnf`/`koji` SRPM flow)
- Debian/Ubuntu (`apt source`)
- Arch-like (`pkgctl`/`asp` + `makepkg --nobuild`)

### 2) Build and install generic fix

```bash
make build KSRC="$KSRC"
sudo make install
sudo reboot
```

### 3) Build and install with machine extras (example)

```bash
make build KSRC="$KSRC" EXTRA=hp-dragonfly-pro
sudo make install EXTRA=hp-dragonfly-pro
sudo reboot
```

Convenience target:

```bash
make hp-dragonfly-pro KSRC="$KSRC"
```

---

## Kernel source notes

- Do **not** use `/usr/src/kernels/$(uname -r)` directly as `KSRC` (headers/build tree only).
- Prefer `./scripts/fetch-kernel-source.sh`.
- Manual fallback instructions are in:
  - `docs/kernel-source-manual.md`

---

## DKMS

Install DKMS build/rebuild support:

```bash
sudo make dkms-install
```

With extras:

```bash
sudo make dkms-install EXTRA=hp-dragonfly-pro
```

Remove DKMS registration:

```bash
sudo make dkms-remove
```

---

## Validation

### Basic runtime checks

```bash
ls /sys/bus/soundwire/devices/
aplay -l
arecord -l
```

### Patch/harness checks

```bash
make test
make test EXTRA=hp-dragonfly-pro

# Equivalent direct harness commands:
./testing/run-harness.sh
./testing/run-harness.sh --extra hp-dragonfly-pro
```

Optional build smoke in harness:

```bash
make test EXTRA=hp-dragonfly-pro TEST_BUILD=1
```

---

## Troubleshooting

### Build failed with missing source files

Use:

```bash
./scripts/fetch-kernel-source.sh --print-path
```

### Modules fail to load (vermagic / section size mismatch)

Source tree does not match distro ABI. Rebuild with distro-matched source via
`fetch-kernel-source.sh`.

### Dummy output after install

Check:

```bash
lspci -nnk -s 61:00.5
ls /sys/bus/soundwire/devices/
```

Then restart user audio services:

```bash
systemctl --user restart wireplumber pipewire pipewire-pulse
```

---

## Repository layout

```text
.
├── Makefile
├── patches/
│   ├── full-diff.patch
│   └── upstream/
├── extras/
│   └── hp-dragonfly-pro/
│       ├── patches/
│       ├── ucm/
│       └── modprobe.d/
├── scripts/
│   ├── fetch-kernel-source.sh
│   ├── build.sh
│   ├── install.sh
│   ├── uninstall.sh
│   ├── dkms-build.sh
│   ├── dkms-install.sh
│   └── dkms-remove.sh
├── docs/
│   └── kernel-source-manual.md
└── testing/
    ├── README.md
    └── run-harness.sh
```
