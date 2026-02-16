# Chapter 7: ACPI

*In which we learn that your BIOS secretly contains a tiny programming language, and that hardware descriptions are just opinion pieces written by firmware engineers.*

---

## The Boot Chicken-and-Egg Problem

When your computer turns on, the kernel needs to know what hardware exists. PCI handles discoverable devices (Chapter 5), but some things can't be discovered through PCI alone:

- How many SoundWire links are enabled?
- What codecs are connected to which link?
- What GPIO pins control power sequencing?
- Is there a SoundWire controller hidden inside the Audio CoProcessor?

This information lives in **ACPI tables** — a set of data structures provided by the **BIOS/UEFI firmware**.

## What is ACPI?

**ACPI** stands for **Advanced Configuration and Power Interface**. It's a specification that defines how the firmware (BIOS) describes hardware to the operating system. Think of it as a **user manual** that the BIOS hands to the kernel at boot time:

> "Dear Linux, here's a map of all the hardware in this laptop. The audio chip is at this address, it has a SoundWire controller at sub-address 2, and there are two RT1316 amplifiers connected. Enjoy! — Love, HP BIOS"

ACPI was originally designed to handle power management (hence the P in the name), but it grew to encompass all kinds of hardware description.

## ACPI Tables

ACPI information is organized into **tables**, each with a four-letter name:

| Table | Full Name | Contains |
|-------|-----------|----------|
| DSDT | Differentiated System Description Table | Main hardware description |
| SSDT | Secondary System Description Table | Additional hardware (there can be dozens) |
| FACP | Fixed ACPI Description | Power management basics |
| MADT | Multiple APIC Description | CPU interrupt routing |

The DSDT and SSDTs contain actual *code* written in a language called **AML** (ACPI Machine Language). Yes, your BIOS contains programs that the kernel runs. This is both powerful and terrifying.

> 🤯 **Fun fact:** ACPI is basically firmware engineers writing programs that run inside your operating system. What could possibly go wrong? (A lot. ACPI bugs are one of the most common causes of Linux hardware issues.)

## ACPI and Our Audio Hardware

The HP Dragonfly Pro's BIOS has 35 SSDT tables. SSDT27 is the interesting one — it describes the audio hardware:

```
Device (ACP_)               ← Audio CoProcessor
{
    Name (_ADR, 0x00000005)  ← PCI function 5
    
    Device (SDWC)            ← SoundWire Controller  
    {
        Name (_ADR, 0x02)    ← Sub-address 2 (important!)
        
        // SoundWire configuration
        Name (SWMC, Package () {
            "mipi-sdw-master-list", 0x01,   ← Link 0 enabled
        })
        
        Device (SWM0)        ← SoundWire Manager 0
        {
            Device (SLV0)    ← Slave device 0
            {
                Name (_ADR, 0x000030025D131601)  ← RT1316 Left
            }
            Device (SLV1)    ← Slave device 1
            {
                Name (_ADR, 0x000031025D131601)  ← RT1316 Right
            }
        }
    }
}
```

This tells the kernel: "Under the Audio CoProcessor, at sub-address 2, there's a SoundWire controller. It has one active link (link 0) with two RT1316 amplifiers."

## The Two ACPI Bugs We Found

### Bug 1: Deprecated Property Name

The ACPI standard for SoundWire was updated at some point, renaming:
- Old name: `mipi-sdw-master-list`
- New name: `mipi-sdw-manager-list`

HP's BIOS uses the **old name**. The Linux kernel only looks for the **new name**. Result: the kernel doesn't find the SoundWire configuration and gives up.

Our fix: try the new name first, then fall back to the old name. Simple and backwards-compatible.

### Bug 2: Sub-Address Mismatch

The SoundWire controller (SDWC) lives at ACPI sub-address `_ADR = 2`. But the driver was looking for it at address `5` (which is correct for ACP 6.3 but wrong for ACP 6.0):

```c
// Original code:
#define ACP63_SDW_ADDR  5   // Correct for Phoenix (rev 0x63)

// Our fix:
#define ACP60_SDW_ADDR  2   // Correct for Rembrandt (rev 0x60)

// In the driver:
u64 sdw_addr = (acp_data->acp_rev < ACP63_PCI_REV) ?
                ACP60_SDW_ADDR : ACP63_SDW_ADDR;
```

Looking at the wrong address is like trying to find your hotel room on the 5th floor when you're actually booked on the 2nd floor. You'll wander the hallway forever.

> 🔍 **How we found this:** We read the BIOS description (the ACPI table) which said "SoundWire controller is at room #2." Then we looked at the driver code and saw it was looking at room #5. Simple mismatch. AMD changed where they put the controller between older (Rembrandt) and newer (Phoenix) chips.

## _OSI: The OS Identity Check

ACPI has a fun (read: infuriating) feature called `_OSI` — Operating System Interface. BIOS code can check which OS is running and behave differently:

```
If (_OSI("Windows 2020")) {
    // Enable fancy feature
} Else {
    // Don't enable it
}
```

This means some hardware features might be **hidden from Linux** because the BIOS only enables them for Windows. We investigated this possibility early in our debugging:

```bash
# We booted with this kernel parameter:
acpi_osi="Windows 2020"
```

This tells Linux to pretend to be Windows when ACPI asks. In our case, it didn't make a difference — the SoundWire devices are described unconditionally. But it's a common trick worth knowing about.

> 🪟 **Fun fact:** Linux has been pretending to be Windows for ACPI compatibility since approximately forever. The kernel parameter `acpi_osi` has a long and storied history of working around BIOS bugs. Sometimes the best way to make hardware work on Linux is to convince the BIOS it's running Windows. It's the software equivalent of wearing a disguise.

## Dumping ACPI Tables

You can examine your ACPI tables with:

```bash
# Dump all tables to binary files
sudo acpidump > acpi.dat

# Decompile to human-readable source
iasl -d acpi.dat

# Now read the .dsl files
less ssdt27.dsl
```

The decompiled `.dsl` files are written in **ASL** (ACPI Source Language) — a C-like language that's surprisingly readable once you know what you're looking at. We spent a lot of time reading SSDT27 to understand the audio hardware layout.

## Common Questions

**Q: How did you figure out that revision 0x60 wasn't supported?**

A: We looked at the kernel driver source code and found `switch` statements that checked the revision number. They had cases for 0x63, 0x70, 0x71... but not 0x60. When the driver encountered our revision, it hit the `default:` case which just gives up and returns an error.

**Q: How do you know that rev 0x60 is "Rembrandt"?**

A: From AMD documentation and kernel source code comments. When kernel developers add support for new hardware, they usually comment which platform/codename it is. There's no single official lookup table, but you find it by:
- Reading kernel source comments
- Checking AMD's public documentation (when available) 
- Searching kernel mailing list discussions where developers mention which chip is which

**Q: Why couldn't the driver just support revision 0x60 from the start?**

A: The SoundWire driver was written when Phoenix (rev 0x63) was the newest platform. The developer who wrote it either didn't have access to older Rembrandt hardware to test, or AMD's documentation didn't mention that Rembrandt had the same SoundWire controller. It's not intentional - just an oversight. This happens a lot in Linux: new hardware gets supported, but older compatible hardware gets forgotten about.

## Key Takeaways

- **ACPI** is how the BIOS describes hardware to the OS — a "user manual" provided at boot
- ACPI tables contain actual **code** that the kernel executes
- The HP Dragonfly Pro's BIOS correctly describes the SoundWire hardware in **SSDT27**
- We found two ACPI-related bugs:
  1. **Deprecated property name** (`mipi-sdw-master-list` vs `mipi-sdw-manager-list`)
  2. **Wrong sub-address** (driver looked at ADR=5 instead of ADR=2)
- `_OSI` checks can hide hardware from Linux, but this wasn't the issue here
- You can dump and read ACPI tables with `acpidump` and `iasl`

---

[← Previous: Chapter 6](chapter-06-soundwire.md) | [Next: Chapter 8 — The HP Dragonfly Pro →](chapter-08-the-hp-dragonfly-pro.md)
