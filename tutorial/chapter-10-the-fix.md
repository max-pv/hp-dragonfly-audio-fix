# Chapter 10: The Fix

*In which we examine each patch under a microscope and explain exactly what it does, why it works, and why the original code didn't.*

---

## Overview

We modified **10 kernel source files** and created **2 userspace configuration files**. Let's go through each one.

## Patch 1: `pci-ps.c` — The Main Driver

**File:** `sound/soc/amd/ps/pci-ps.c`
**What it is:** The main platform driver for AMD ACP 6.3+ with SoundWire support.

**Changes (4 switch statements + ACPI address fix):**

### 1a. Accept revision 0x60 at PCI probe

```c
// Before:
switch (pci->revision) {
    case ACP63_PCI_REV:    // only 0x63
    case ACP70_PCI_REV:
    case ACP71_PCI_REV:
        break;
    default:
        return -ENODEV;    // 0x60 rejected here!
}

// After:
switch (pci->revision) {
    case 0x60:             // ← Added: Rembrandt
    case 0x6f:             // ← Added: Rembrandt-R
    case ACP63_PCI_REV:
    case ACP70_PCI_REV:
    case ACP71_PCI_REV:
        break;
    default:
        return -ENODEV;
}
```

**Why:** This is the front door. Without this, the driver refuses to even look at our hardware. By adding `case 0x60:` before the existing `case ACP63_PCI_REV:`, execution "falls through" into the same code path. No new logic needed — just a wider welcome mat.

### 1b. Fix ACPI address for SoundWire controller

```c
// Before:
ret = acp_scan_sdw_devices(&pci->dev, ACP63_SDW_ADDR);  // Always uses 5

// After:
u64 sdw_addr = (acp_data->acp_rev < ACP63_PCI_REV) ?
                ACP60_SDW_ADDR : ACP63_SDW_ADDR;    // 2 for Rembrandt, 5 for Phoenix
ret = acp_scan_sdw_devices(&pci->dev, sdw_addr);
```

**Why:** On Rembrandt, the SoundWire controller sits at ACPI address 2. On Phoenix, it's at address 5. Different BIOS teams, different choices. We check the revision and pick the right address.

### 1c. Two more interrupt handler switch statements

Same pattern — add `case 0x60:` and `case 0x6f:` so the interrupt handler recognizes our revision.

## Patch 2: `acp63.h` — New Constant

**File:** `sound/soc/amd/ps/acp63.h`

```c
// Added:
#define ACP60_SDW_ADDR  2   // SDWC ACPI address for Rembrandt
```

**Why:** Clean code uses named constants, not magic numbers. This defines the Rembrandt SoundWire address alongside the existing Phoenix one.

Also added `subsystem_vendor` and `subsystem_device` fields to the data structure so the machine driver can identify the specific laptop model.

## Patch 3: `ps-sdw-dma.c` — DMA Engine

**File:** `sound/soc/amd/ps/ps-sdw-dma.c`
**What it is:** The DMA engine that transfers audio samples over SoundWire.

**Changes: 5 switch statements + 1 comparison fix**

Same pattern as pci-ps.c — five places where `case 0x60:` and `case 0x6f:` were added. Plus one comparison change:

```c
// Before:
if (sdw_data->acp_rev == ACP63_PCI_REV)   // Only exact match

// After:
if (sdw_data->acp_rev <= ACP63_PCI_REV)   // 0x60 is less than 0x63, so included
```

**Why:** The restore-from-suspend function only ran for exactly revision 0x63. Changing `==` to `<=` includes 0x60 and 0x6f as well. This is actually cleaner than adding more cases because any future revision below 0x63 would also work.

## Patch 4: `pci-acp6x.c` — Driver Conflict Resolution

**File:** `sound/soc/amd/yc/pci-acp6x.c`
**What it is:** The DMIC-only driver for ACP 6.x (Yellow Carp).

**The problem:** This driver matches `1022:15E2` and was claiming our device before `pci-ps` could. But it only handles DMIC, not SoundWire speakers.

```c
// Added:
#include <linux/acpi.h>

// In the probe function:
if (ACPI_COMPANION(&pci->dev) &&
    acpi_find_child_device(ACPI_COMPANION(&pci->dev), 2, 0)) {
    dev_dbg(&pci->dev, "SoundWire ACPI device found, deferring\n");
    return -ENODEV;
}
```

**Why:** Before trying to claim the device, check if there's a SoundWire controller described in ACPI (at address 2). If yes, back off and let `pci-ps` handle it. This is a clean, non-hacky way to resolve the driver conflict — it uses existing ACPI information rather than hardcoded model lists.

## Patch 5: `amd-sdw-acpi.c` — Property Name Fallback

**File:** `sound/soc/amd/acp/amd-sdw-acpi.c`
**What it is:** Scans ACPI tables for SoundWire configuration.

```c
// Before:
ret = fwnode_property_read_u32_array(..., "mipi-sdw-manager-list", ...);
if (ret) {
    dev_err(..., "Failed to read mipi-sdw-manager-list\n");
    return -EINVAL;
}

// After:
ret = fwnode_property_read_u32_array(..., "mipi-sdw-manager-list", ...);
if (ret) {
    // Try deprecated property name used by older BIOS
    ret = fwnode_property_read_u32_array(..., "mipi-sdw-master-list", ...);
}
if (ret) {
    dev_err(..., "Failed to read mipi-sdw-manager-list\n");
    return -EINVAL;
}
```

**Why:** HP's BIOS uses the old property name ("master" instead of "manager"). The MIPI standard renamed it, but not all BIOS versions were updated. This try-new-then-old pattern is standard practice in the kernel.

## Patch 6: `amd-acp63-acpi-match.c` — Machine Table Entry

**File:** `sound/soc/amd/acp/amd-acp63-acpi-match.c`
**What it is:** Contains the tables that map SoundWire device combinations to machine configurations.

**Added a new configuration for RT1316-only setups:**

```c
static const struct snd_soc_acpi_adr_device rt1316_only_group_adr[] = {
    {
        .adr = 0x000030025D131601ull,    // RT1316 Left
        .num_endpoints = 1,
        .endpoints = &spk_l_endpoint,
        .name_prefix = "rt1316-1"
    },
    {
        .adr = 0x000031025D131601ull,    // RT1316 Right
        .num_endpoints = 1,
        .endpoints = &spk_r_endpoint,
        .name_prefix = "rt1316-2"
    },
};
```

**Why:** The kernel already knew about RT1316 when paired with an RT722 headphone codec. But the Dragonfly Pro has RT1316 amplifiers *only* (no headphone codec). We added a configuration for this simpler setup. Without it, the machine driver saw two RT1316s and said "I don't have a recipe for this combination."

Think of it like a restaurant kitchen: they know how to make a burger with fries, but if you order just fries, they say "that's not on the menu." We added "just fries" to the menu.

## Patch 7: `amd_manager.c` — SoundWire Manager

**File:** `drivers/soundwire/amd_manager.c`
**Changes: 4 switch statements**

Same pattern: add `case 0x60:` and `case 0x6f:` to each revision switch. These control which registers the SoundWire manager uses for its link (each link has different register offsets on different platforms, but 0x60 uses the same as 0x63).

## Patch 8: `amd_init.c` — NULL Safety Check

**File:** `drivers/soundwire/amd_init.c`

```c
// Before:
amd_manager = dev_get_drvdata(&ctx->pdev[i]->dev);
ret = amd_sdw_manager_start(amd_manager);

// After:
amd_manager = dev_get_drvdata(&ctx->pdev[i]->dev);
if (!amd_manager)
    return -ENODEV;
ret = amd_sdw_manager_start(amd_manager);
```

**Why:** If the SoundWire manager probe fails (which it did before we fixed `amd_manager.c`), the startup function would crash with a NULL pointer dereference. This safety check prevents a kernel panic. It's defensive programming — belt and suspenders.

## Patch 9: `acp-sdw-legacy-mach.c` — Machine Driver

**File:** `sound/soc/amd/acp/acp-sdw-legacy-mach.c`
**Changes: 3 switch statements + DMI quirk + API adaptation**

Three more `case 0x60:` additions, plus the DMI quirk entry:

```c
{
    .callback = soc_sdw_quirk_cb,
    .matches = {
        DMI_MATCH(DMI_SYS_VENDOR, "HP"),
        DMI_MATCH(DMI_PRODUCT_NAME, "HP Dragonfly Pro Laptop PC"),
    },
    .driver_data = (void *)(ASOC_SDW_CODEC_SPKR),
},
```

This tells the machine driver: "On this specific HP laptop, set the `CODEC_SPKR` flag" — which triggers the SoundWire speaker DAI link creation.

## Patch 10: `ps-pdm-dma.c` — DMIC Runtime-ID Collision Fix

**File:** `sound/soc/amd/ps/ps-pdm-dma.c`  
**What it is:** The PDM/DMIC DMA component used for internal microphone capture.

```c
// Added in acp63_pdm_component:
.use_dai_pcm_id = true,
```

**Why:** After enabling both speaker + DMIC links, the machine card failed with
`snd_soc_register_card failed -16` (busy), which caused "Dummy Output" on boot.
Root cause was a PCM runtime ID collision between SoundWire and PDM paths.
Setting `use_dai_pcm_id` for PDM makes runtime IDs deterministic and non-overlapping.

## The Complete Picture

Here's a visual of which file handles which part of the audio path:

```
Application → PipeWire → ALSA
                           ↓
              acp-sdw-legacy-mach.c  ←── Machine driver (glues it all together)
                           ↓
              amd-acp63-acpi-match.c ←── Codec combination matching
                           ↓
              pci-ps.c               ←── Platform driver (PCI probe + setup)
                           ↓
              ps-sdw-dma.c           ←── SoundWire DMA engine (speaker path)
              ps-pdm-dma.c           ←── PDM DMA engine (mic path)
                           ↓
              amd_manager.c          ←── SoundWire bus controller
                           ↓
              [SoundWire bus]
                           ↓
              RT1316 codec driver    ←── Amplifier configuration
                           ↓
              🔊 Speakers
```

We patched every layer except the RT1316 codec driver itself (which already worked correctly — it just never got loaded because the layers above it all failed).

## Key Takeaways

- **10 files modified**, each addressing a specific layer of the stack
- The most common change: adding `case 0x60:` to `switch` statements (~20 total)
- The ACPI address fix and property name fallback addressed BIOS differences
- The machine table entry taught the kernel about our specific codec combination
- The DMI quirk identifies our specific laptop model
- The driver conflict fix uses ACPI detection (clean) rather than model hardcoding (hacky)
- The final stability fix removed a DMIC/SDW runtime-ID collision that caused `-16` card registration failures
- Every patch is **minimal and upstreamable** — no ugly workarounds

---

[← Previous: Chapter 9](chapter-09-the-bug.md) | [Next: Chapter 11 — UCM and PipeWire →](chapter-11-ucm-and-pipewire.md)
