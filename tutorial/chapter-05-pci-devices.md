# Chapter 5: PCI Devices

*In which we learn how your computer discovers its own body parts, and why every piece of hardware carries an ID card.*

---

## The Hardware Discovery Problem

When your computer boots up, the kernel faces an existential question: *"What hardware do I have?"*

It can't just look. There's no label on the motherboard saying "Hey, you've got an AMD audio chip at address 0x61." The kernel needs a systematic way to discover, identify, and catalog every piece of hardware. That's where **PCI** comes in.

## What is PCI?

**PCI** stands for **Peripheral Component Interconnect**. It's a standard for connecting hardware devices to the CPU. Think of it as a highway system inside your computer:

- The CPU is downtown
- PCI buses are the highways radiating outward
- Each hardware device is a building along the highway, with a specific address

Modern laptops use **PCIe** (PCI Express), which is the newer, faster version of PCI. But the discovery and identification system works the same way.

## PCI Configuration Space: The ID Card

Every PCI device has a small block of memory called its **configuration space**. This is like an ID card that the device always carries. It contains:

| Field | What It Means | Our Audio Chip |
|-------|--------------|----------------|
| Vendor ID | Who made this chip | `1022` (AMD) |
| Device ID | What chip model is this | `15E2` (Audio CoProcessor) |
| Revision | Which revision/version | `0x60` (Rembrandt) |
| Class | What type of device | Multimedia Audio |
| Subsystem Vendor | Who made the whole board | `103C` (HP) |
| Subsystem Device | Which specific product | `8A7F` (Dragonfly Pro) |

The kernel reads these ID cards during boot and uses them to find the right driver. It's like an airport immigration officer checking your passport:

- Vendor ID + Device ID = your name
- Revision = your birth year
- Class = your profession
- Subsystem = your employer

## Seeing Your PCI Devices

You can list all PCI devices with `lspci`:

```bash
$ lspci
...
61:00.5 Multimedia controller: AMD Audio Coprocessor (rev 60)
...
```

For more detail:

```bash
$ lspci -v -s 61:00.5
61:00.5 Multimedia controller: Advanced Micro Devices [AMD] 
        Audio Coprocessor (rev 60)
        Subsystem: Hewlett-Packard Company Device 8a7f
        Flags: bus master, fast devsel, latency 0, IRQ 90
        Memory at d0500000 (32-bit, non-prefetchable) [size=1M]
```

That `61:00.5` is the **BDF address** (Bus:Device.Function) — the physical location of the chip on the PCI highway. It's like a street address.

## The Matching Game

When the kernel finds a PCI device, it checks every loaded driver's **PCI ID table** to find a match. Here's what the table looks like in actual kernel code:

```c
static const struct pci_device_id acp63_pci_ids[] = {
    { PCI_DEVICE(0x1022, 0x15E2) },
    { 0, }
};
```

This says: "I handle any device from vendor 0x1022 with device ID 0x15E2."

But wait — that matches on vendor and device ID only. What about the **revision**?

Here's the twist: PCI matching doesn't filter by revision. The driver gets loaded for ANY revision of that device. But then, *inside* the driver, there are `switch` statements that check the revision and decide what to do:

```c
switch (pci->revision) {
    case 0x63:  // ACP 6.3 - Phoenix
        // I know this one! Set up for Phoenix.
        break;
    case 0x70:  // ACP 7.0 - Strix Point  
        // I know this too!
        break;
    default:
        // Unknown revision, bail out!
        return -ENODEV;
}
```

See the problem? Revision `0x60` isn't in any `case`. The driver loads, looks at the revision, says "I don't recognize you," and quits. **The hardware goes driverless.**

> 🎭 **Analogy:** Imagine a restaurant that accepts reservations from anyone named "Smith," but when you arrive, the host checks your first name against a list. "John Smith? Right this way. Jane Smith? Of course. Bob Smith? ...sorry, not on the list." Bob Smith is hardware revision 0x60. Bob just wanted dinner.

## Why Different Revisions Exist

A single chip can have multiple revisions because:

1. **Bug fixes** — silicon bugs are corrected in later revisions
2. **New platforms** — the same chip design is used in different CPU generations
3. **Cost optimization** — the chip is manufactured on a newer, cheaper process

AMD's Audio CoProcessor (device 15E2) is used across multiple platforms:

| Revision | Platform | Codename |
|----------|----------|----------|
| `0x60` | Rembrandt | ACP 6.0 (our laptop!) |
| `0x63` | Phoenix | ACP 6.3 |
| `0x6f` | Rembrandt-R | ACP 6.0 variant |
| `0x70` | Strix Point | ACP 7.0 |
| `0x71` | Krackan Point | ACP 7.1 |

All of these share the same vendor:device ID (`1022:15E2`). The revision is the only thing that tells them apart. And the driver had support for 0x63 and above, but not 0x60. 

This is very common in Linux audio — new hardware ships, the kernel supports the *latest* revision, but forgets about earlier revisions that use the same register layout. It's an oversight, not malice.

## What `lspci` Told Us

This was one of the first diagnostic commands we ran:

```bash
$ lspci -nn -s 61:00.5
61:00.5 Multimedia controller [0401]: AMD [1022] Audio Coprocessor [15e2] (rev 60)
```

That `(rev 60)` immediately told us: this is a Rembrandt chip. And a quick look at the kernel source confirmed: no driver handles revision 0x60. Mystery solved. (Well, half of it. The fix took considerably longer.)

> 🔍 **How we looked up "Rembrandt":** We searched the kernel source code for "15e2" (the device ID) and "60" (the revision). The search results showed comments like "ACP 6.0 - Rembrandt" in various files. Kernel developers leave these breadcrumbs to help future debuggers (like us!).

## Common Questions

**Q: How did you find the revision number?**

A: By running `lspci -nn -s 61:00.5`. The `-nn` flag shows both human-readable names and the hex IDs. The `(rev 60)` part is read directly from the PCI device's configuration space - a small piece of memory on the chip itself that stores its ID card information.

**Q: How did you know which kernel files to look at?**

A: We followed a trail:
1. `lspci` told us the PCI ID: `1022:15e2`
2. We searched kernel source for files containing "15e2" 
3. That showed us which drivers match this device
4. We then looked at those driver files to see which ones rejected revision 0x60
5. Error messages in `dmesg` also helped - they told us which drivers were loading and failing

Think of it like following a paper trail: each clue leads to the next file.

**Q: Why does the driver support rev 0x63 but not 0x60 if they're so similar?**

A: Because the driver was written when Phoenix (0x63) was the current platform, and the developer either didn't have Rembrandt (0x60) hardware to test with, or didn't realize it was compatible. It's a common oversight - new hardware gets supported, compatible older hardware gets overlooked. Nobody was being mean to Rembrandt; it just slipped through the cracks.

## Key Takeaways

- **PCI** is the standard bus for connecting hardware to the CPU
- Every PCI device has a **configuration space** with vendor ID, device ID, revision, etc.
- The kernel uses these IDs to **match devices with drivers**
- PCI matching is coarse (vendor + device), but drivers do **fine-grained revision checks** internally
- Our audio chip (`1022:15E2 rev 0x60`) matched the driver but was rejected by internal revision switches
- The fix: add `case 0x60:` to every relevant switch statement

---

[← Previous: Chapter 4](chapter-04-kernel-modules.md) | [Next: Chapter 6 — SoundWire →](chapter-06-soundwire.md)
