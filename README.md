# HP Dragonfly Pro Audio Fix

Enables internal speaker audio on the **HP Dragonfly Pro Laptop PC** running Linux.

> **Temporary repo** — this exists until the patches are accepted upstream into the
> Linux kernel.

> **⚠️ WARNING: This software replaces kernel modules. Incorrect modifications can
> render your system unbootable. Use entirely at your own risk.**

## The Problem

The HP Dragonfly Pro uses AMD Rembrandt (ACP revision 0x60) with two Realtek RT1316
SoundWire speaker amplifiers. The Linux kernel recognizes ACP 6.3 (Phoenix, rev 0x63)
but not ACP 6.0 (Rembrandt, rev 0x60), even though they use identical register layouts
for SoundWire. This causes:

- No internal speaker output (HDMI, USB-C, and DMIC still work)
- PipeWire shows "Dummy Output" instead of speakers
- `/sys/bus/soundwire/devices` is empty

## The Fix

This patches **7 kernel modules** across the AMD audio and SoundWire subsystems to
accept ACP revision 0x60, adds a DMI quirk for the HP Dragonfly Pro, and installs an
ALSA UCM profile so PipeWire can configure the speakers.

**Modules patched:**

| Module | What it does |
|--------|-------------|
| `snd-pci-ps` | ACP PCI platform driver (main entry point) |
| `snd-ps-sdw-dma` | SoundWire DMA engine |
| `snd-pci-acp6x` | DMIC-only driver (patched to defer to SoundWire driver) |
| `snd-soc-acpi-amd-match` | ACPI machine table (RT1316 config added) |
| `snd-amd-sdw-acpi` | SoundWire ACPI scanner (deprecated property fallback) |
| `snd-acp-sdw-legacy-mach` | Machine driver (HP Dragonfly DMI quirk added) |
| `soundwire-amd` | AMD SoundWire manager driver |

---

## Quick Start

### Prerequisites

- `git`, `gcc`, `make`, `patch`, `xz` (install via your distro's package manager)
- A **full kernel source tree** (not just headers — see [Getting Kernel Source](#getting-kernel-source) below)

### Build & Install

```bash
make build KSRC=/path/to/linux-source
sudo make install
sudo reboot
```

### DKMS (Recommended — survives kernel updates)

```bash
sudo make dkms-install
sudo reboot
```

After rebooting, select **"Internal Speakers — Audio Coprocessor"** in your desktop's
sound settings.

---

## Getting Kernel Source

The build requires a **full kernel source tree** from your **distro** (not vanilla
kernel.org). Distros patch the kernel with ABI-changing modifications — building
against vanilla source produces modules that fail to load.

**Fedora / RHEL / CentOS:**

```bash
# Install the source RPM for your running kernel
koji download-build --arch=src kernel-$(uname -r | sed 's/\.fc.*/.fc$(rpm -E %fedora)/')
# Or download from https://koji.fedoraproject.org/

# Extract and prepare
rpm2cpio kernel-*.src.rpm | cpio -idmv
tar xf linux-$(uname -r | cut -d- -f1).tar.xz
cd linux-$(uname -r | cut -d- -f1)
patch -p1 < ../patch-*-redhat.patch  # Apply distro patches
cp Makefile.rhelver .                 # Copy version metadata
```

**Ubuntu / Debian:**

```bash
apt source linux-image-$(uname -r)
```

**Arch Linux:**

```bash
asp checkout linux
cd linux/trunk
makepkg --nobuild  # Downloads and patches source
```

**If you already have distro-matched source** (e.g., `~/linux/`):

```bash
make build KSRC=~/linux
```

---

## Build Commands

```bash
# Build for current running kernel
make build KSRC=/path/to/linux-source

# Build for a specific kernel version
make build KSRC=/path/to/linux-source KVER=6.18.9-200.fc43.x86_64

# Install
sudo make install

# Uninstall (restores original modules from backup)
sudo make uninstall

# Clean build artifacts
make clean
```

---

## DKMS

DKMS (Dynamic Kernel Module Support) automatically rebuilds these modules when you
install a new kernel. This means your speakers continue working after kernel updates.

```bash
# Install
sudo make dkms-install
sudo reboot

# Check status
dkms status

# Remove
sudo make dkms-remove
```

DKMS copies the patch and build script to `/usr/src/hp-dragonfly-audio-1.0/`. When a
new kernel is installed, it automatically patches, builds, and installs the modules.

**Note:** DKMS still needs the full distro kernel source at build time. Keep a source
tree at `/usr/src/linux-<version>/` or `~/linux-<version>/` for each kernel you run.

---

## Troubleshooting

### No sound after reboot

```bash
# Check sound card detected
aplay -l | grep -i soundwire

# Check SoundWire devices
ls /sys/bus/soundwire/devices/

# Verify modules loaded
lsmod | grep -E 'snd_pci_ps|soundwire_amd|snd_acp_sdw'

# Check for errors
sudo dmesg | grep -iE 'sdw|acp|soundwire' | tail -20

# Unmute RT1316 DACs if needed
amixer -c amdsoundwire cset name='rt1316-1 DAC Switch' on,on
amixer -c amdsoundwire cset name='rt1316-2 DAC Switch' on,on
```

### Modules don't load after kernel update

Your kernel was updated and the patched modules were replaced:

- **With DKMS:** `sudo dkms build hp-dragonfly-audio/1.0 -k $(uname -r) && sudo dkms install hp-dragonfly-audio/1.0 -k $(uname -r)`
- **Without DKMS:** `make build KSRC=/path/to/source && sudo make install`

### Build fails

- Use your **distro's** kernel source, not vanilla kernel.org (see above)
- Check that the patch applies cleanly (it was written for kernel 6.18.9)

### Modules fail to load ("section size must match" or "version magic" errors)

Your modules were built against the wrong kernel source. Distros add ABI-changing
patches (e.g., extra fields in `struct module`). Rebuild using your distro's kernel
source tree.

### PipeWire shows "Dummy Output"

```bash
# Verify UCM profile is installed
ls /usr/share/alsa/ucm2/conf.d/amd-soundwire/
# Should contain: amd-soundwire.conf, HiFi.conf

# Restart PipeWire
systemctl --user restart pipewire pipewire-pulse wireplumber
```

### SoundWire devices not appearing

If `/sys/bus/soundwire/devices/` is empty even after installing the patched modules,
your BIOS may need ACPI hints. Try adding these kernel boot parameters:

```bash
sudo grubby --update-kernel=ALL --args='acpi_osi="Windows 2020" acpi=force'
sudo reboot
```

Check current params with `cat /proc/cmdline`.

---

## Directory Layout

```
├── Makefile               Build/install/DKMS targets (thin wrappers)
├── dkms.conf              DKMS configuration
├── scripts/
│   ├── build.sh           Build patched modules from kernel source
│   ├── install.sh         Install modules + UCM + modprobe config
│   ├── uninstall.sh       Restore original modules from backup
│   ├── dkms-install.sh    Register with DKMS
│   ├── dkms-remove.sh     Remove DKMS registration
│   └── dkms-build.sh      Build script called by DKMS automatically
├── patches/
│   ├── full-diff.patch    Unified patch (source of truth)
│   └── upstream/          4 split patches for kernel mailing list
├── ucm/                   ALSA UCM profile for speaker/mic routing
│   ├── amd-soundwire.conf
│   └── HiFi.conf
└── tutorial/              How this fix works (bug-hunting walkthrough)
```

## Tutorial

The [`tutorial/`](tutorial/README.md) is a 14-chapter walkthrough covering Linux audio,
kernel modules, SoundWire, ACPI, and how this fix was built from scratch — from
identifying the bug to writing the patch. Start with
[`tutorial/README.md`](tutorial/README.md).

---

## System Information

| Property | Value |
|----------|-------|
| Laptop | HP Dragonfly Pro Laptop PC |
| Board | HP 8A7F |
| Platform | AMD Rembrandt |
| PCI Device | 1022:15e2 rev 0x60 |
| Codecs | 2× Realtek RT1316 (SoundWire) |
| ACPI Path | `\_SB_.PCI0.GP17.ACP_.SDWC` |
| Tested Kernel | 6.18.9-200.fc43.x86_64 |
