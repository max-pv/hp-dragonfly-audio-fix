# Chapter 11: UCM and PipeWire

*In which we fix the last mile, unmute two tiny switches, and learn that even after the kernel works perfectly, userspace can still ruin everything.*

---

## The Last Mile Problem

After all our kernel patches, the situation was:

- ✅ SoundWire codecs enumerated
- ✅ ALSA card "amdsoundwire" created
- ✅ `speaker-test -D hw:amdsoundwire,2` completed without errors
- ❌ PipeWire still showed "Dummy Output"
- ❌ No actual sound from speakers

So the kernel was happy. ALSA was happy. But the user-facing audio system (PipeWire) didn't know what to do with the new hardware. And even when we fixed that, the amplifiers were muted. Two more problems to solve.

## Problem 1: The Missing UCM Profile

### What is UCM?

**UCM** stands for **Use Case Manager**. It's part of ALSA and provides named configurations for sound cards. Think of it as a recipe book:

- "Recipe: Speaker" → use PCM device 2, set these mixer controls
- "Recipe: Headphones" → use PCM device 0, set different mixer controls
- "Recipe: Microphone" → use capture device 3, enable these inputs

UCM profiles live in `/usr/share/alsa/ucm2/` and are organized by sound card name:

```
/usr/share/alsa/ucm2/conf.d/
    amd-soundwire/
        amd-soundwire.conf    ← Main configuration
        HiFi.conf             ← High-fidelity playback/capture profile
```

### The Broken Symlink

The Fedora package for `alsa-ucm` came with a symlink:

```
amd-soundwire.conf → ../../sof-soundwire/sof-soundwire.conf
```

This pointed to the SOF SoundWire profile... which **doesn't exist on Fedora**. A symlink pointing nowhere. A road sign pointing into a lake.

> 🔗 **Fun fact:** A broken symlink is sometimes called a "dangling symlink." It's the file system equivalent of giving someone directions to a building that was demolished last year. "Turn left at the parking lot." "What parking lot?"

### The Fix: Write Our Own UCM Profile

We created two files:

**`amd-soundwire.conf`** — The main UCM configuration:
```
Syntax 4

SectionUseCase."HiFi" {
    File "HiFi.conf"
    Comment "Default"
}
```

This just says: "I have one use case called HiFi, and its details are in HiFi.conf."

**`HiFi.conf`** — The actual profile:
```
SectionVerb {
    EnableSequence []
    DisableSequence []
    Value {
        PlaybackPCM "hw:amdsoundwire,2"
        CapturePCM "hw:amdsoundwire,3"
    }
}

SectionDevice."Speaker" {
    Comment "Internal Speakers"
    EnableSequence [
        cset "name='rt1316-1 DAC Switch' on,on"
        cset "name='rt1316-2 DAC Switch' on,on"
        cset "name='Speaker Switch' on"
    ]
    DisableSequence [
        cset "name='rt1316-1 DAC Switch' off,off"
        cset "name='rt1316-2 DAC Switch' off,off"
        cset "name='Speaker Switch' off"
    ]
    Value {
        PlaybackPCM "hw:amdsoundwire,2"
        PlaybackChannels 2
    }
}

SectionDevice."Mic" {
    Comment "Internal Microphone"
    EnableSequence []
    DisableSequence []
    Value {
        CapturePCM "hw:amdsoundwire,3"
        CaptureChannels 2
    }
}
```

Key parts:
- **PlaybackPCM** tells PipeWire which ALSA device to use for playback (`hw:amdsoundwire,2`)
- **CapturePCM** tells it which device to use for recording (`hw:amdsoundwire,3`)
- **EnableSequence** runs ALSA mixer commands when the device is activated (unmutes the DACs!)
- **DisableSequence** runs commands when deactivated (mutes them)

### How PipeWire Uses UCM

When PipeWire starts (via WirePlumber), here's what happens:

1. WirePlumber scans all ALSA sound cards
2. For each card, it looks for a UCM profile matching the card name
3. If found, it reads the profile to learn:
   - What devices exist (Speaker, Mic, Headphones, etc.)
   - Which PCM streams to use
   - What mixer controls to set
4. It creates PipeWire nodes (sinks and sources) for each device
5. These appear in GNOME Settings as output/input options

Without a UCM profile, WirePlumber sees the sound card but doesn't know what to do with it. It's like finding a control panel with unlabeled buttons — technically functional, but you don't know which button does what.

## Problem 2: Muted Amplifiers

Even after PipeWire created the "Internal Speakers" sink, there was no sound. Why?

The RT1316 amplifier chips have a **DAC Switch** mixer control that defaults to **off**. This is a safety feature — you don't want amplifiers blasting at full volume during initialization. But it means someone needs to turn them on.

The relevant ALSA mixer controls:

```
'rt1316-1 DAC Switch' = off,off    ← Left amplifier MUTED
'rt1316-2 DAC Switch' = off,off    ← Right amplifier MUTED
'Speaker Switch'      = on          ← Master switch was fine
```

The fix was simple:

```bash
amixer -c amdsoundwire cset name='rt1316-1 DAC Switch' on,on
amixer -c amdsoundwire cset name='rt1316-2 DAC Switch' on,on
```

And then we added these to the UCM profile's `EnableSequence` so they're set automatically when PipeWire activates the speaker device.

> 🔇 **The irony:** After patching 9 kernel files, rebuilding modules, rebooting 15 times, and creating a UCM profile... the final fix was flipping two switches from "off" to "on." Sometimes the simplest problems hide behind the most complex ones.

## ALSA Mixer Controls Explained

When you run `amixer -c amdsoundwire contents`, you see all the "knobs" for the sound card. Here's what the important ones do:

| Control | What It Does |
|---------|-------------|
| `Speaker Switch` | Master on/off for all speakers |
| `rt1316-1 DAC Switch` | Left amplifier DAC enable (on/off for L+R channels) |
| `rt1316-2 DAC Switch` | Right amplifier DAC enable |
| `rt1316-1 RX Channel Select` | How to map audio channels to the amplifier |
| `rt1316-1 Vsense Mixer Switch` | Voltage sensing feedback (for speaker protection) |
| `rt1316-1 Isense Mixer Switch` | Current sensing feedback (for speaker protection) |

The Vsense and Isense controls are part of the RT1316's "smart amplifier" feature — it monitors the speaker in real time to prevent damage from excessive volume or heat. Neat!

## Saving Mixer State

ALSA can save and restore mixer settings across reboots:

```bash
# Save current mixer state
alsactl store amdsoundwire

# Restore on next boot (happens automatically via systemd)
alsactl restore amdsoundwire
```

The state is saved to `/var/lib/alsa/asound.state`. Combined with the UCM profile's `EnableSequence`, this ensures the DAC switches stay on across reboots.

## Key Takeaways

- **UCM** (Use Case Manager) tells PipeWire how to use a sound card — which PCM devices, which mixer controls
- The original UCM was a **broken symlink** pointing to a nonexistent SOF profile
- We created a **minimal UCM profile** with Speaker and Mic devices
- The RT1316 **DAC switches default to off** — they must be explicitly enabled
- UCM's `EnableSequence` automatically unmutes the DACs when the speaker is activated
- `alsactl store/restore` persists mixer settings across reboots
- The chain: **UCM profile → WirePlumber reads it → PipeWire creates sinks → GNOME shows "Internal Speakers"**

---

[← Previous: Chapter 10](chapter-10-the-fix.md) | [Next: Chapter 12 — Installing the Fix →](chapter-12-installing-the-fix.md)
