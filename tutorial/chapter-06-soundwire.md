# Chapter 6: SoundWire

*In which we learn about a tiny, elegant bus that connects speakers to processors, and discover that even wires have protocols.*

---

## The Problem: Connecting Audio Chips

Inside your laptop, the CPU's audio processor needs to send digital audio data to the amplifier chips (RT1316) that drive the speakers. How do you connect them?

You could use a parallel bus — many wires side by side, each carrying one bit. But that takes a lot of space and uses a lot of power. Inside a thin laptop, space and power are precious.

You could use I²S (Inter-IC Sound) — a classic digital audio connection. But I²S is point-to-point: one wire per device. If you have two amplifiers, you need two sets of wires.

Or you could use **SoundWire** — a modern, elegant solution that puts everything on just **two wires**.

## What is SoundWire?

**SoundWire** is a digital audio bus standard developed by the MIPI Alliance (the same folks who standardized your phone's camera interface). It was designed specifically for connecting audio components inside portable devices.

Two wires. That's it:

| Wire | Name | Purpose |
|------|------|---------|
| 1 | **Clock** | Timing signal — "tick, tick, tick" |
| 2 | **Data** | Audio data, commands, and responses |

On these two tiny wires, SoundWire carries:

- **Multiple audio streams** in both directions (playback AND recording simultaneously)
- **Control commands** (configure the codec, read status)
- **Device discovery** (finding out who's connected)
- **Clock synchronization** (keeping everything in perfect time)

It's like fitting a symphony orchestra through a garden hose. Very impressive engineering.

> 📞 **Analogy:** SoundWire is like a phone call. Two wires (clock + data), and yet you can have a full conversation — talking and listening, asking questions and getting answers, all at the same time. The trick is time-division multiplexing: different information takes turns using the wire, switching so fast it seems simultaneous.

## Masters and Slaves

SoundWire uses a **master-slave** architecture (the standard is moving to the terms "manager" and "peripheral," but most code still uses the old terms):

- **Manager (Master):** The controller inside the CPU. It runs the show — generates the clock, initiates communication, assigns time slots. In our case, this is the AMD ACP's SoundWire controller.

- **Peripheral (Slave):** The devices on the bus. They respond to the manager, send and receive audio data in their assigned time slots. In our case, two RT1316 amplifiers.

```
     ┌──────────────┐
     │  AMD ACP     │
     │  SoundWire   │
     │  Manager     │
     └──────┬───────┘
            │
    ════════╪═══════════  (2 wires: clock + data)
            │
     ┌──────┴───────┐
     │  Link 0      │
     │              │
   ┌─┴──┐      ┌──┴──┐
   │RT  │      │RT   │
   │1316│      │1316 │
   │Left│      │Right│
   └────┘      └─────┘
```

## Device Addresses

Every SoundWire device has a unique **48-bit address** baked into it at the factory. This address contains:

```
0x 0000 3002 5D13 1601
   ──── ──── ──── ────
    │    │    │    │
    │    │    │    └── Part ID (unique per chip type) + instance
    │    │    └────── Manufacturer ID (025D = Realtek)  
    │    └────────── Link ID + device number
    └──────────────── Version
```

Our two RT1316 amplifiers:
- Left speaker:  `0x000030025D131601` (device 0 on link 0)
- Right speaker: `0x000031025D131601` (device 1 on link 0)

Same chip, same manufacturer, just different instance numbers. Like twins with different Social Security numbers.

## Enumeration: The Roll Call

When the SoundWire manager starts up, it performs **enumeration** — discovering what devices are connected. It works like a classroom roll call:

1. Manager sends a ping on the bus
2. Each device responds with its 48-bit address
3. Manager assigns each device a "dynamic address" (a short number for quick communication)
4. Manager reads each device's capabilities (what audio formats it supports, how many channels, etc.)

If enumeration works, you see devices in:

```bash
$ ls /sys/bus/soundwire/devices/
sdw:0:0:025d:1316:01:0    ← RT1316 #1 (left)
sdw:0:0:025d:1316:01:1    ← RT1316 #2 (right)
sdw-master-0-0             ← Manager, link 0
sdw-master-0-1             ← Manager, link 1 (disabled)
```

If enumeration fails, that directory is empty. And that's **exactly what we saw** before the fix. The SoundWire manager was starting up, but no devices were responding. It was sending pings into the void.

## Why Enumeration Failed

The SoundWire manager is part of the kernel driver. Its code has revision checks too:

```c
switch (amd_manager->acp_rev) {
    case ACP63_PCI_REV_ID:   // 0x63
        // Set up registers for link 0
        break;
    default:
        return -EINVAL;   // "I don't know this revision"
}
```

When the revision was 0x60, the manager refused to configure the registers, so it never sent the initial ping, so the RT1316 devices never responded, so the directory was empty.

The devices were there on the wire, patiently waiting. Like dogs at the door when you come home — except the door was locked from the inside.

## SoundWire in the Linux Kernel

The Linux SoundWire subsystem lives in `drivers/soundwire/` and provides:

| Component | File | Role |
|-----------|------|------|
| Bus core | `bus.c` | Generic SoundWire bus management |
| AMD Manager | `amd_manager.c` | AMD-specific controller driver |
| AMD Init | `amd_init.c` | Startup/shutdown orchestration |
| Slave driver | `slave.c` | Generic peripheral (codec) handling |

The AMD manager driver talks to the ACP hardware to send and receive SoundWire frames. The bus core handles the protocol logic. And the codec driver (RT1316, in `sound/soc/codecs/rt1316-sdw.c`) provides the audio-specific configuration.

All three layers need to agree on the ACP revision for things to work. We had to patch the AMD manager and init code to accept 0x60.

## Key Takeaways

- **SoundWire** is a 2-wire digital audio bus for connecting audio chips
- It carries **multiple audio streams**, control commands, and device discovery on just clock + data
- Uses a **manager/peripheral** architecture: one controller, multiple devices
- Each device has a unique **48-bit address** with manufacturer and part IDs
- **Enumeration** is the process of discovering connected devices
- Before the fix, `/sys/bus/soundwire/devices/` was **empty** — enumeration was failing because the manager code rejected revision 0x60
- After the fix, both RT1316 amplifiers appeared — enumeration succeeded!

---

[← Previous: Chapter 5](chapter-05-pci-devices.md) | [Next: Chapter 7 — ACPI →](chapter-07-acpi.md)
