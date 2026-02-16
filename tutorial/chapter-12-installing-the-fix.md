# Chapter 12: Installing the Fix

*In which we learn the practical art of replacing kernel modules without breaking everything, and discover that `xz` compression has opinions about checksums.*

---

## What Gets Installed

The complete fix consists of:

| Component | Files | Location |
|-----------|-------|----------|
| 7 kernel modules | `.ko.xz` files | `/lib/modules/<kernel-version>/kernel/...` |
| UCM profile | 2 config files | `/usr/share/alsa/ucm2/conf.d/amd-soundwire/` |
| modprobe config | 1 config file | `/etc/modprobe.d/hp-dragonfly-audio.conf` |

## The Easy Way: install.sh

We created an installer script that handles everything:

```bash
sudo /home/max/audio_fix/install.sh
```

Here's what it does, step by step:

### Step 1: Back Up Original Modules

Before replacing anything, the script copies the original modules to a backup directory. This is your safety net — if something goes wrong, you can restore them.

```
/home/max/audio_fix/backup-6.18.9-200.fc43.x86_64/
    snd-pci-ps.ko.xz           ← Original from Fedora
    snd-ps-sdw-dma.ko.xz
    soundwire-amd.ko.xz
    ... etc
```

### Step 2: Copy Patched Modules

Each patched module file is copied to its correct location in the kernel module tree:

```
/lib/modules/6.18.9-200.fc43.x86_64/kernel/
    sound/soc/amd/ps/snd-pci-ps.ko.xz          ← Patched
    sound/soc/amd/ps/snd-ps-sdw-dma.ko.xz      ← Patched
    sound/soc/amd/acp/snd-soc-acpi-amd-match.ko.xz  ← Patched
    sound/soc/amd/acp/snd-amd-sdw-acpi.ko.xz   ← Patched
    sound/soc/amd/acp/snd-acp-sdw-legacy-mach.ko.xz  ← Patched
    sound/soc/amd/yc/snd-pci-acp6x.ko.xz       ← Patched
    drivers/soundwire/soundwire-amd.ko.xz       ← Patched
```

### Step 3: Install UCM Profile

The UCM files are copied to the ALSA configuration directory:

```
/usr/share/alsa/ucm2/conf.d/amd-soundwire/
    amd-soundwire.conf    ← Main config
    HiFi.conf             ← Profile with DAC unmute sequences
```

### Step 4: Install modprobe Configuration

```
/etc/modprobe.d/hp-dragonfly-audio.conf
```

Contains: `options snd_acp_sdw_legacy_mach quirk=32768`

This sets the `ASOC_SDW_CODEC_SPKR` quirk flag, telling the machine driver that this laptop has SoundWire speakers.

### Step 5: Rebuild Module Index

```bash
depmod -a
```

Updates the module dependency database so `modprobe` can find the new modules.

### Step 6: Reboot

After `install.sh` completes, reboot for the new modules to take effect.

## The Gotchas

### Gotcha 1: XZ Compression Checksums

Kernel modules are compressed with XZ, but there's a catch:

```bash
# WRONG — default CRC64 checksum, kernel can't load it:
xz module.ko

# RIGHT — CRC32 checksum, kernel happy:
xz --check=crc32 module.ko
```

The kernel's built-in XZ decompressor only supports CRC32 checksums. The `xz` command defaults to CRC64. If you compress with the wrong checksum, the module silently fails to load and you spend an hour wondering why.

> 🤦 **True story:** We spent one of our early reboots debugging why a freshly compiled module wasn't loading. The error message was completely generic. Turns out it was the checksum format. Thanks, xz.

### Gotcha 2: File Copy Corruption

On some filesystem configurations, `cp` can produce zero-byte destination files when copying `.ko.xz` modules to `/lib/modules/`. We never figured out exactly why. The workaround:

```bash
# Instead of:
cp source.ko.xz /lib/modules/.../destination.ko.xz

# Use:
dd if=source.ko.xz of=/lib/modules/.../destination.ko.xz bs=4k
```

`dd` does a raw byte copy that consistently works. The installer script tries `dd` first and falls back to `cp`.

### Gotcha 3: Kernel Updates Overwrite Modules

When Fedora updates the kernel package (`dnf update kernel`), it overwrites the module files in `/lib/modules/`. **Your patched modules will be replaced** with the original (non-working) ones.

After any kernel update, re-run:

```bash
sudo /home/max/audio_fix/install.sh
sudo reboot
```

Or, if the new kernel version is different from 6.18.9, you'll need to recompile the modules from source for the new kernel. The installer will warn you about version mismatches.

### Gotcha 4: Module Signing Warnings

Fedora kernels expect signed modules. Our custom-compiled modules aren't signed, so you'll see warnings in `dmesg`:

```
module: snd_pci_ps: module verification failed: signature and/or required key missing
```

This is harmless — Fedora allows unsigned modules in its default configuration. The warning is just informational. If Secure Boot is enforced on your system, you may need to sign the modules or disable Secure Boot.

## Uninstalling

To revert everything:

```bash
sudo /home/max/audio_fix/uninstall.sh
sudo reboot
```

This restores the original modules from the backup directory and removes the modprobe configuration. You'll be back to silence, but at least it's a *known* silence.

## Manual Installation (For the Brave)

If you prefer to do everything by hand:

```bash
# 1. Copy modules (example for one module)
sudo dd if=snd-pci-ps.ko.xz \
        of=/lib/modules/$(uname -r)/kernel/sound/soc/amd/ps/snd-pci-ps.ko.xz \
        bs=4k

# 2. Rebuild module index
sudo depmod -a

# 3. Copy UCM profile
sudo mkdir -p /usr/share/alsa/ucm2/conf.d/amd-soundwire
sudo cp amd-soundwire.conf HiFi.conf /usr/share/alsa/ucm2/conf.d/amd-soundwire/

# 4. Set modprobe option
echo 'options snd_acp_sdw_legacy_mach quirk=32768' | \
    sudo tee /etc/modprobe.d/hp-dragonfly-audio.conf

# 5. Reboot
sudo reboot
```

## After Reboot Checklist

After rebooting with the patched modules, verify everything works:

```bash
# 1. Check SoundWire devices appeared
ls /sys/bus/soundwire/devices/
# Expected: sdw:0:0:025d:1316:01:0  sdw:0:0:025d:1316:01:1

# 2. Check ALSA card exists
aplay -l | grep amdsoundwire
# Expected: card 1: amdsoundwire [amdsoundwire]

# 3. Check PipeWire sees speakers
wpctl status | grep -i speaker
# Expected: Audio Coprocessor Internal Speakers

# 4. Check DAC switches are on
amixer -c amdsoundwire cget name='rt1316-1 DAC Switch'
# Expected: values=on,on

# 5. Play test sound
speaker-test -D plughw:amdsoundwire,2 -c 2 -t sine -l 1

# 6. Or run the smoke test
bash /mnt/audio_issue/test.sh
```

## Key Takeaways

- Use `install.sh` for easy one-command installation
- Always **back up original modules** before replacing them
- Watch out for **XZ checksum format** (must use CRC32)
- **Kernel updates overwrite patched modules** — re-run installer after updates
- Module signing warnings are **harmless** on Fedora's default configuration
- Use `uninstall.sh` to revert if anything goes wrong
- Always verify with the **post-reboot checklist**

---

[← Previous: Chapter 11](chapter-11-ucm-and-pipewire.md) | [Next: Chapter 13 — Upstream Contributions →](chapter-13-upstream-contributions.md)
