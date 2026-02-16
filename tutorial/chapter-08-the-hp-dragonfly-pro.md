# Chapter 8: The HP Dragonfly Pro

*In which we meet our patient, examine its internals, and understand exactly why it was silent.*

---

## The Machine

The **HP Dragonfly Pro Laptop PC** is a premium business laptop from HP. Here are the relevant specs:

| Spec | Value |
|------|-------|
| Model | HP Dragonfly Pro Laptop PC |
| Board ID | 8A7F |
| CPU | AMD Ryzen (Rembrandt) |
| Audio Processor | AMD ACP 6.0 (revision 0x60) |
| Speaker Amplifiers | 2× Realtek RT1316 (SoundWire) |
| Audio Bus | SoundWire (link 0) |
| Microphone | DMIC (Digital Microphone, works fine) |
| HDMI Audio | AMD Radeon HD Audio (works fine) |
| OS | Fedora 43 Workstation, kernel 6.18.9 |

From the outside, it's a sleek, modern laptop. From the inside, it's a fascinating case study in how even well-designed hardware can be let down by software support.

## What Worked

Before we started, some audio features already worked:

- ✅ **HDMI audio** — if you connected an external monitor with speakers, you'd get sound
- ✅ **USB-C audio** — external USB audio devices worked
- ✅ **Digital microphone** — the built-in DMIC worked for input (video calls, recording)
- ✅ **Bluetooth audio** — pairing Bluetooth headphones worked

## What Didn't Work

- ❌ **Internal speakers** — complete silence
- ❌ **PipeWire** showed "Dummy Output" — meaning no valid audio sink was found
- ❌ `/sys/bus/soundwire/devices/` was **empty** — no SoundWire codecs enumerated
- ❌ `aplay -l` showed no SoundWire playback device

The internal speakers were completely invisible to the operating system. As far as Linux was concerned, this laptop simply didn't have speakers. Which is... a bold claim for a laptop.

> 🔇 **The user experience:** You buy a $1,500 laptop, install Linux, and discover you can't play sound from the speakers. You check the settings — "Dummy Output." You try every troubleshooting guide on the internet. Nothing works. This was the situation before our fix.

## The Hardware Architecture (Detailed)

Here's the complete audio path inside the Dragonfly Pro:

```
┌──────────────────────────────────────────────────────┐
│                    AMD Ryzen CPU                      │
│                                                       │
│  ┌─────────────────────────────────────────────────┐ │
│  │            PCI Device 1022:15E2 (rev 0x60)      │ │
│  │            Audio CoProcessor (ACP 6.0)           │ │
│  │                                                   │ │
│  │   ┌──────────┐  ┌──────────┐  ┌──────────┐      │ │
│  │   │  DMIC    │  │ SoundWire│  │  HDMI    │      │ │
│  │   │  Engine  │  │Controller│  │  Audio   │      │ │
│  │   │ (works!) │  │ (SDWC)   │  │ (works!) │      │ │
│  │   └──────────┘  └─────┬────┘  └──────────┘      │ │
│  │                        │                          │ │
│  └────────────────────────┼──────────────────────────┘ │
│                           │                             │
└───────────────────────────┼─────────────────────────────┘
                            │
                    SoundWire Bus (2 wires)
                            │
              ┌─────────────┼──────────────┐
              │             │              │
        ┌─────┴──────┐ ┌───┴────────┐     │
        │ RT1316 #1  │ │ RT1316 #2  │     │
        │ (Slave 0)  │ │ (Slave 1)  │     │
        │ Left Amp   │ │ Right Amp  │     │
        │ + DAC      │ │ + DAC      │     │
        └─────┬──────┘ └─────┬──────┘     │
              │               │            │
         🔊 Left          🔊 Right        │
         Speaker          Speaker          │
                                          │
                                     (Link 1: disabled)
```

The ACP has multiple engines inside it. The DMIC engine (for the built-in microphone) and the HDMI audio engine both worked from day one. Only the SoundWire engine was broken — specifically, its interaction with the kernel driver was broken.

## Why Only SoundWire Was Broken

The DMIC and HDMI paths use different drivers that have separate revision handling. The DMIC driver (`pci-acp6x`) already supported revision 0x60 for microphone capture. HDMI audio uses the AMD GPU driver, which is completely separate.

But the SoundWire path — the one connecting to the speakers — goes through a chain of drivers that were written primarily for the newer Phoenix platform (revision 0x63). Nobody had tested them with Rembrandt (0x60).

It's like a building where the elevators work fine, the stairs work fine, but the escalator (which uses the same motor as the elevator) was installed with the wrong control panel.

## The Driver Fight

Here's something fun: **three different drivers** all tried to claim the same PCI device:

| Driver | File | Purpose | What happened |
|--------|------|---------|---------------|
| `snd-pci-acp6x` | `pci-acp6x.c` | DMIC-only driver | Claimed the device → only DMIC worked |
| `snd-sof-amd-rembrandt` | `pci-rmb.c` | SOF firmware driver | No firmware exists → dead end |
| `snd-pci-ps` | `pci-ps.c` | Full SoundWire driver | Never got a chance to load |

All three drivers match the same PCI ID (`1022:15E2`). A **configuration function** (`snd_amd_acp_find_config()`) decides which one gets priority. For the Dragonfly Pro, no special configuration existed, so the DMIC-only driver (`pci-acp6x`) won by default.

This was like assigning a plumber to do an electrician's job just because the plumber showed up first.

Our fix added logic to `pci-acp6x` to detect when SoundWire hardware is present and back off, letting `pci-ps` (the full SoundWire driver) handle the device instead.

## The DMI Quirk

Linux uses **DMI** (Desktop Management Interface) tables to identify the specific machine model. Drivers can include DMI tables to apply special behavior for specific laptops:

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

This tells the driver: "When running on an HP Dragonfly Pro, set the speaker flag so the machine driver knows to set up SoundWire speaker outputs."

Without this entry, the driver didn't know this machine has SoundWire speakers. It's like a restaurant that doesn't have your table reservation — even if the table exists, they won't seat you.

## Summary: Everything That Was Wrong

Here's the complete list of issues, in the order we discovered and fixed them:

| # | Issue | Why It Mattered |
|---|-------|----------------|
| 1 | `pci-acp6x` claimed the device | Blocked `pci-ps` from loading |
| 2 | `pci-ps` rejected revision 0x60 | Driver refused to probe |
| 3 | ACPI address was wrong (5 vs 2) | SoundWire controller not found |
| 4 | ACPI property name deprecated | SoundWire link mask not read |
| 5 | `amd_manager` rejected 0x60 | SoundWire bus didn't start |
| 6 | `ps-sdw-dma` rejected 0x60 | DMA engine didn't configure |
| 7 | `acp-sdw-legacy-mach` rejected 0x60 | Machine driver didn't bind |
| 8 | No DMI quirk for HP Dragonfly | Machine driver didn't know about speakers |
| 9 | No machine table for RT1316-only | Codec combination unrecognized |
| 10 | RT1316 DACs defaulted to off | Amplifiers muted at startup |

Ten issues. Every single one had to be fixed for sound to come out. Miss even one and you get silence.

## Key Takeaways

- The HP Dragonfly Pro has **AMD ACP 6.0 + two RT1316 SoundWire amplifiers**
- HDMI, USB-C, Bluetooth, and DMIC all worked — only **internal speakers** were broken
- **Three drivers competed** for the same device; the wrong one won
- **Ten separate issues** across 9 source files needed fixing
- The core problem: ACP revision 0x60 was not supported in any SoundWire-related driver
- Every layer of the stack — from PCI probe to ALSA mixer — had to be fixed

---

[← Previous: Chapter 7](chapter-07-acpi.md) | [Next: Chapter 9 — The Bug →](chapter-09-the-bug.md)
