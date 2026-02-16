# Chapter 9: The Bug Hunt

*In which we become detectives, follow false leads, reboot fifteen times, and slowly unravel a mystery hidden across twenty switch statements.*

---

## The Crime Scene

The symptoms were clear:
- No sound from internal speakers
- PipeWire shows "Dummy Output"
- `/sys/bus/soundwire/devices/` is empty

The question was: **why?**

This chapter tells the story of how we found the answer. It's a detective story, complete with red herrings, false leads, and the satisfaction of finally cracking the case.

## Phase 1: Gathering Evidence

Every good investigation starts with evidence collection. Here's what we ran first:

```bash
# What sound cards does ALSA see?
aplay -l
# Result: Only HDMI audio. No SoundWire card.

# What does PipeWire think?
wpctl status
# Result: "Dummy Output" — no usable audio sink

# Are SoundWire devices present?
ls /sys/bus/soundwire/devices/
# Result: Empty directory. No devices at all.

# What does the kernel log say?
dmesg | grep -i sdw
# Result: SoundWire modules loaded, but no devices found

# What PCI device do we have?
lspci -nn -s 61:00.5
# Result: 1022:15E2 (rev 60) — AMD Audio CoProcessor
```

Key observation: the SoundWire modules loaded successfully, but no codec devices appeared. The bus was running, but nobody was on it.

## Phase 2: ACPI Investigation

We dumped the ACPI tables to understand what hardware the BIOS describes:

```bash
sudo acpidump > acpi.dat
iasl -d acpi.dat
grep -r "SDW\|SoundWire\|1316\|SDWC" *.dsl
```

**Jackpot.** SSDT27 contained a complete description of the SoundWire hardware:
- SDWC controller at `\_SB_.PCI0.GP17.ACP_.SDWC` with `_ADR = 2`
- Two RT1316 devices with proper MIPI addresses
- Link 0 enabled, link 1 disabled

The hardware description was there. The BIOS was doing its job. So the kernel was ignoring perfectly good information. Why?

## Phase 3: The First False Lead — SOF

Our first theory was that this system needed **SOF** (Sound Open Firmware) — an open-source audio firmware from Intel/AMD. Some AMD systems use SOF to handle SoundWire.

We tried:
1. Added a DMI entry to `acp-config.c` with the `FLAG_AMD_SOF` flag
2. Patched `pci-rmb.c` to accept revision 0x60
3. Rebuilt and rebooted

Result: the SOF driver loaded... and immediately failed. There was no `sof-rmb.ri` firmware file available anywhere. AMD never published SOF firmware for Rembrandt.

> 🕳️ **Dead end #1:** SOF firmware doesn't exist for this platform. Three reboots wasted. Time to try another approach.

This was an important lesson: not every AMD audio platform uses SOF. Some use **native drivers** that talk to the hardware directly without firmware.

## Phase 4: The Eureka Moment — pci-ps.c

Looking more carefully at the kernel source, we noticed something crucial. There are **two paths** for SoundWire on AMD:

1. **SOF path** (`pci-rmb.c`) — requires firmware, doesn't exist for Rembrandt
2. **Native path** (`pci-ps.c`) — talks to hardware directly, no firmware needed

`pci-ps.c` was written for ACP 6.3 (Phoenix) and already handled SoundWire natively. If we could make it accept ACP 6.0 (Rembrandt), we wouldn't need SOF at all.

We opened `pci-ps.c` and searched for revision checks:

```c
switch (pci->revision) {
    case ACP63_PCI_REV:    // 0x63
    case ACP70_PCI_REV:    // 0x70
    case ACP71_PCI_REV:    // 0x71
        break;
    default:
        return -ENODEV;    // ← "Not my problem"
}
```

There it was. Revision 0x60 wasn't listed. And this same pattern repeated **four times** in this one file.

## Phase 5: The Domino Effect

Adding `case 0x60:` to `pci-ps.c` was just the beginning. Every file in the chain had the same issue:

**Reboot 1:** pci-ps now probes, but `pci-acp6x` claims the device first!
→ Fix: add SoundWire detection to `pci-acp6x` so it backs off

**Reboot 2:** pci-ps claims the device, but SoundWire manager fails with error -22!
→ Fix: add 0x60 to `amd_manager.c` (4 more switch statements)

**Reboot 3:** SoundWire codecs enumerate! 🎉 But machine driver fails with error -22!
→ Fix: add 0x60 to `acp-sdw-legacy-mach.c` (3 more switch statements)
→ Fix: add RT1316 machine table to `amd-acp63-acpi-match.c`
→ Fix: add ACPI property name fallback to `amd-sdw-acpi.c`

**Reboot 4:** Machine driver loads! But DMA fails with error -22!
→ Fix: add 0x60 to `ps-sdw-dma.c` (5 more switch statements)

**Reboot 5:** DMA works! ALSA card created! `speaker-test` completes! 🎉🎉

**Reboot 6:** But PipeWire still shows "Dummy Output"...
→ Fix: create UCM profile for `amd-soundwire`

**Reboot 7:** PipeWire shows "Internal Speakers"! But no actual sound!
→ Fix: unmute RT1316 DAC switches (they default to off)

**🔊 SOUND! ACTUAL SOUND! FROM THE SPEAKERS!**

Total: ~15 reboots, 20+ switch statements patched, 9 files modified, 1 UCM profile created, 2 mixer switches unmuted.

## The Pattern

Here's the frustrating pattern we saw repeated across every file:

```c
// Someone wrote this for Phoenix (0x63):
switch (acp_rev) {
    case 0x63:
        do_the_thing();
        break;
    default:
        return -EINVAL;
}
```

And nobody ever added Rembrandt (0x60), even though it uses the **exact same registers** and **exact same logic**. The hardware is compatible. The code just doesn't know it.

This is a very common pattern in Linux audio drivers. New hardware support gets added for the latest platform, and older-but-compatible platforms get left behind because:

1. The developer only had the newer hardware to test
2. Nobody reported the bug (Linux on this laptop is rare)
3. AMD didn't submit patches for the older platform

## What We Learned

The root cause wasn't one bug — it was **ten layered issues**. Each one blocked the next from being visible. You had to fix them in order:

```
pci-acp6x claiming device → hides pci-ps probe failure
  → hides SoundWire manager failure
    → hides machine driver failure  
      → hides DMA failure
        → hides missing UCM
          → hides muted DACs
```

Like an onion. An onion that makes you reboot instead of cry.

> 🧅 **The Onion of Bugs:** Each layer of failure hid the next. You couldn't even see bug #3 until you fixed bugs #1 and #2. This is why kernel debugging is hard — error messages only tell you about the *first* failure, and there might be five more behind it.

## Key Takeaways

- Debugging started with **evidence gathering**: `aplay`, `wpctl`, `dmesg`, `lspci`, ACPI dumps
- The **SOF firmware approach was a dead end** — no firmware exists for Rembrandt
- The **native driver path** (`pci-ps.c`) was the correct approach
- **20+ switch statements** across 8 kernel files needed `case 0x60:` added
- Bugs were **layered** — each fix revealed the next problem
- The final fix also required a **UCM profile** and **unmuting the amplifier DACs**
- Total: **~15 reboots** and **9 modified source files** to go from silence to sound

---

[← Previous: Chapter 8](chapter-08-the-hp-dragonfly-pro.md) | [Next: Chapter 10 — The Fix →](chapter-10-the-fix.md)
