# Chapter 4: Kernel Modules

*In which we learn that the Linux kernel is modular like LEGO, and that loading the wrong brick makes your spaceship look like a duck.*

---

## The Monolithic Problem

The Linux kernel needs to support thousands of different hardware devices: network cards, graphics chips, USB gadgets, audio chips, webcams, Bluetooth adapters, and that weird gaming mouse with 47 buttons.

If every driver for every device was permanently baked into the kernel, it would be enormous — hundreds of megabytes of code, most of which you'd never use. Your laptop doesn't need a driver for a 1990s SCSI disk controller. Probably.

The solution? **Kernel modules.**

## What is a Module?

A kernel module is a piece of code that can be **loaded into and unloaded from the kernel at runtime** — while the system is running, without rebooting.

Think of the kernel as a smartphone:
- The base kernel = the phone's built-in apps (always there)
- Kernel modules = apps you download from the store (loaded when needed)

When you plug in a USB sound card, the kernel automatically loads the right module. When you unplug it, the module can be unloaded. Neat and tidy.

## Module Files

Modules are stored as files with the `.ko` extension (Kernel Object). On Fedora, they live in:

```
/lib/modules/6.18.9-200.fc43.x86_64/kernel/
```

That path includes the kernel version, so each kernel version has its own set of modules. Here are some examples:

```
kernel/sound/soc/amd/ps/snd-pci-ps.ko.xz        ← Our main audio driver!
kernel/drivers/soundwire/soundwire-amd.ko.xz      ← SoundWire manager
kernel/net/wireless/iwlwifi/iwlwifi.ko.xz         ← WiFi driver
kernel/drivers/gpu/drm/amd/amdgpu/amdgpu.ko.xz   ← Graphics driver
```

Notice the `.xz` extension — modules are compressed to save disk space. The kernel decompresses them on the fly when loading.

> 📦 **Fun fact:** Module compression uses XZ with CRC32 checksums. If you accidentally compress with CRC64 (the default for the `xz` tool), the kernel will refuse to load the module and give you a completely unhelpful error message. Ask us how we know.

## Loading and Unloading Modules

The kernel loads modules automatically when it detects matching hardware, but you can also do it manually:

```bash
# See what modules are currently loaded
lsmod

# Load a module
sudo modprobe snd-pci-ps

# Unload a module
sudo modprobe -r snd-pci-ps

# See info about a module
modinfo snd-pci-ps
```

The `modprobe` command is smart — it handles **dependencies** automatically. If module A needs module B to work, `modprobe A` will load B first. It's like a package manager, but for kernel code.

## How Modules Know Which Hardware to Support

Every module contains a table of hardware IDs it supports. When the kernel discovers a new device (say, a PCI sound card), it broadcasts the device's ID and asks: "Who can handle this?"

Modules raise their hand if the ID matches their table. It's like speed dating:

```
Kernel: "I have a PCI device, vendor 1022, device 15E2, revision 63"
pci-ps: "That's me! I know that one!"
Kernel: "Great, you're hired."

Kernel: "I have a PCI device, vendor 1022, device 15E2, revision 60"
pci-ps: "...never heard of it."
pci-acp6x: "...nope."
pci-rmb: "...not me."
Kernel: "Well this is awkward. No driver for you, sound card."
```

That second scenario? **That's exactly what was happening on our laptop.** Revision 0x60 wasn't in anyone's list.

## Module Parameters

Modules can accept **parameters** — configuration values that change their behavior. You can set them:

1. **At load time**: `modprobe snd-pci-ps some_param=42`
2. **In a config file**: `/etc/modprobe.d/some-config.conf`

For our fix, we use a parameter to tell the machine driver about our speaker setup:

```
# /etc/modprobe.d/hp-dragonfly-audio.conf
options snd_acp_sdw_legacy_mach quirk=32768
```

That `32768` is the `ASOC_SDW_CODEC_SPKR` flag, telling the driver "hey, this machine has SoundWire speakers."

## depmod: The Module Index

After installing new module files, you must run:

```bash
sudo depmod -a
```

This rebuilds the **module dependency index** — a database that tells `modprobe` where every module is and what depends on what. Without running `depmod`, the system won't find your new modules. It's like adding a book to a library without updating the catalog.

## What We Changed

For our audio fix, we replaced **7 kernel modules** with patched versions:

| Module | What We Changed |
|--------|----------------|
| `snd-pci-ps.ko.xz` | Accept ACP revision 0x60, fix SoundWire ACPI address |
| `snd-ps-sdw-dma.ko.xz` | Accept revision 0x60 in DMA configuration |
| `soundwire-amd.ko.xz` | Accept revision 0x60 in SoundWire manager |
| `snd-soc-acpi-amd-match.ko.xz` | Add RT1316 speaker configuration table |
| `snd-amd-sdw-acpi.ko.xz` | Handle deprecated ACPI property name |
| `snd-acp-sdw-legacy-mach.ko.xz` | Accept revision 0x60, add HP Dragonfly DMI quirk |
| `snd-pci-acp6x.ko.xz` | Don't claim device when SoundWire is present |

Each module was:
1. Modified in the kernel source code
2. Compiled (built from source)
3. Compressed with `xz --check=crc32`
4. Copied to `/lib/modules/.../`
5. Registered with `depmod -a`

## Module Signing (A Brief Note)

Modern kernels can require modules to be **cryptographically signed** to prevent malicious code from being loaded into the kernel. Fedora enables this, but in a permissive mode — it warns about unsigned modules in the system log but still loads them.

When you install custom-compiled modules, you'll see warnings like:

```
module: snd_pci_ps: module verification failed: signature and/or required key missing
```

This is normal and harmless for our purposes. The modules still load and work fine.

## Key Takeaways

- **Kernel modules** are loadable pieces of kernel code (drivers) with `.ko` extension
- Modules are loaded **automatically** when matching hardware is detected
- Each module has a table of **hardware IDs** it supports — if your hardware's ID isn't in the table, no driver loads
- **Our bug**: revision 0x60 wasn't in any driver's support table
- After installing new modules, always run `depmod -a` to update the index
- Module parameters (set via `/etc/modprobe.d/`) can configure driver behavior
- Fedora allows unsigned modules with a warning

---

[← Previous: Chapter 3](chapter-03-the-linux-audio-stack.md) | [Next: Chapter 5 — PCI Devices →](chapter-05-pci-devices.md)
