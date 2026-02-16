# Chapter 14: Quizzes

*In which we test your knowledge, reward your attention, and prove that you actually learned something. No cheating — the penguin is watching.*

---

## How to Use This Chapter

Each section below corresponds to a chapter. Try to answer the questions before peeking at the answers. The answers are hidden at the bottom of each quiz section.

Scoring:
- **All correct:** You're ready to submit kernel patches. 🐧
- **Most correct:** Solid understanding. Re-read the chapters you missed.
- **Few correct:** No shame! This stuff is complex. Re-read and try again.

---

## Quiz 1: What is Linux? (Chapter 1)

**Q1.** What is the technical definition of "Linux"?

a) A complete operating system with desktop and apps
b) The kernel — the core that talks to hardware and manages resources
c) A company that makes open-source software
d) A type of penguin

**Q2.** Who created Linux, and in what year?

**Q3.** What is a Linux "distribution"?

a) A way to distribute Linux CDs by mail (it's not the 1990s anymore)
b) A package that bundles the kernel with a desktop, apps, and configuration
c) A different version of the kernel
d) A mirror server that hosts downloads

**Q4.** What distribution does the HP Dragonfly Pro in our story run?

**Q5.** True or False: Because Linux is open source, anyone can read and modify the kernel code.

<details>
<summary>Click for answers</summary>

1. **b)** The kernel — Linux technically refers only to the kernel
2. **Linus Torvalds, 1991**
3. **b)** A distribution bundles the kernel with a desktop environment, package manager, and applications
4. **Fedora 43 Workstation**
5. **True** — and this is exactly why we were able to fix the audio bug ourselves

</details>

---

## Quiz 2: How Computers Make Sound (Chapter 2)

**Q1.** What does DAC stand for?

**Q2.** Put these in order from first to last in the audio pipeline:
- [ ] Amplifier
- [ ] Speaker cone
- [ ] CPU reads audio file
- [ ] DAC converts digital to analog

**Q3.** What is the sample rate "48 kHz" mean?

a) The speaker vibrates 48,000 times per second
b) The audio data contains 48,000 numbers per second
c) The amplifier outputs 48 kilowatts
d) The file is 48,000 bytes

**Q4.** What amplifier chips does the HP Dragonfly Pro use?

**Q5.** True or False: The amplifier converts digital data to analog electrical signals.

<details>
<summary>Click for answers</summary>

1. **Digital-to-Analog Converter**
2. CPU reads audio file → DAC converts digital to analog → Amplifier → Speaker cone
3. **b)** 48,000 numerical samples per second
4. **Two Realtek RT1316** smart amplifiers (one left, one right)
5. **False** — that's the DAC's job. The amplifier makes an existing analog signal stronger.

</details>

---

## Quiz 3: The Linux Audio Stack (Chapter 3)

**Q1.** List the four layers of the Linux audio stack from top to bottom.

**Q2.** What does PipeWire do?

a) Directly controls hardware registers
b) Mixes, routes, and volume-controls audio between applications and ALSA
c) Compiles kernel modules
d) Provides the graphical volume slider

**Q3.** What does ALSA stand for?

**Q4.** In which layer of the audio stack did our bug live?

a) PipeWire
b) ALSA userspace
c) Kernel drivers
d) The application

**Q5.** What is WirePlumber?

<details>
<summary>Click for answers</summary>

1. **Applications → PipeWire → ALSA → Kernel Drivers** (→ Hardware)
2. **b)** PipeWire is the audio server that mixes, routes, and manages audio
3. **Advanced Linux Sound Architecture**
4. **c)** Kernel drivers — specifically the AMD ACP and SoundWire drivers
5. **WirePlumber** is PipeWire's session manager — it makes policy decisions like which device is default and reads UCM profiles

</details>

---

## Quiz 4: Kernel Modules (Chapter 4)

**Q1.** What file extension do kernel modules use?

a) `.dll`
b) `.so`
c) `.ko`
d) `.mod`

**Q2.** What command rebuilds the module dependency index?

**Q3.** Why must you use `xz --check=crc32` instead of plain `xz` when compressing kernel modules?

**Q4.** How many kernel modules did we replace for the audio fix?

**Q5.** What does the `/etc/modprobe.d/hp-dragonfly-audio.conf` file do?

<details>
<summary>Click for answers</summary>

1. **c)** `.ko` (Kernel Object), often compressed as `.ko.xz`
2. **`depmod -a`**
3. The kernel's XZ decompressor only supports CRC32 checksums, not the default CRC64
4. **7** patched modules
5. It sets the `quirk=32768` parameter for the machine driver, telling it this laptop has SoundWire speakers (`ASOC_SDW_CODEC_SPKR` flag)

</details>

---

## Quiz 5: PCI Devices (Chapter 5)

**Q1.** What does PCI stand for?

**Q2.** What is the PCI vendor:device ID for our audio chip?

a) 8086:A0E8
b) 1022:15E2
c) 10DE:1AEB
d) 103C:8A7F

**Q3.** What is the PCI revision of the AMD ACP on the HP Dragonfly Pro?

**Q4.** True or False: PCI device matching uses the revision to select the driver.

**Q5.** Why did the driver reject our hardware even though the PCI ID matched?

<details>
<summary>Click for answers</summary>

1. **Peripheral Component Interconnect**
2. **b)** 1022:15E2 (AMD Audio CoProcessor)
3. **0x60** (Rembrandt / ACP 6.0)
4. **False** — PCI matching uses vendor + device ID. The revision check happens *inside* the driver via switch statements.
5. The driver matched on vendor:device but then checked the revision in internal `switch` statements that only listed 0x63 and above, not 0x60.

</details>

---

## Quiz 6: SoundWire (Chapter 6)

**Q1.** How many physical wires does SoundWire use?

a) 1
b) 2
c) 4
d) 8

**Q2.** What is "enumeration" in the SoundWire context?

**Q3.** What were the contents of `/sys/bus/soundwire/devices/` before the fix?

**Q4.** What is the difference between a SoundWire manager and a peripheral?

**Q5.** What information does a SoundWire device's 48-bit address contain?

<details>
<summary>Click for answers</summary>

1. **b)** 2 wires — clock and data
2. **Enumeration** is the process of discovering connected devices — the manager sends pings and devices respond with their addresses
3. **Empty** — no devices were enumerated because the manager code rejected revision 0x60
4. The **manager** (master) is the controller inside the CPU that runs the bus. **Peripherals** (slaves) are the connected devices (RT1316 amplifiers) that respond to the manager.
5. Manufacturer ID (e.g., 025D = Realtek), part ID (e.g., 1316), version, and instance number

</details>

---

## Quiz 7: ACPI (Chapter 7)

**Q1.** What does ACPI stand for?

**Q2.** What is the purpose of ACPI tables?

a) To make the computer boot faster
b) To describe hardware to the operating system
c) To encrypt the BIOS
d) To store user preferences

**Q3.** What two ACPI-related bugs did we find?

**Q4.** What does `_OSI` do in ACPI?

**Q5.** At what ACPI sub-address is the SoundWire controller (SDWC) on the Dragonfly Pro?

<details>
<summary>Click for answers</summary>

1. **Advanced Configuration and Power Interface**
2. **b)** ACPI tables describe hardware configuration to the OS
3. (1) The BIOS uses the deprecated property name `mipi-sdw-master-list` instead of `mipi-sdw-manager-list`. (2) The driver looked for SDWC at address 5 instead of the correct address 2.
4. `_OSI` lets BIOS code check which OS is running and behave differently (e.g., enable features only for Windows)
5. **`_ADR = 2`** (not 5, which is what ACP 6.3 uses)

</details>

---

## Quiz 8: The HP Dragonfly Pro (Chapter 8)

**Q1.** How many separate issues had to be fixed for speakers to work?

a) 1
b) 3
c) 7
d) 10

**Q2.** Which audio features worked BEFORE the fix? (Select all that apply)

a) HDMI audio
b) Internal speakers
c) USB-C audio
d) Digital microphone
e) Bluetooth audio

**Q3.** Why did `pci-acp6x` need to be modified?

**Q4.** What is a DMI quirk?

<details>
<summary>Click for answers</summary>

1. **d)** 10 separate issues
2. **a, c, d, e** — everything except internal speakers
3. `pci-acp6x` (the DMIC-only driver) was claiming the PCI device before `pci-ps` (the SoundWire driver) could. We added detection logic so it backs off when SoundWire hardware is present.
4. A **DMI quirk** is a special configuration applied based on the machine's DMI identity (vendor + product name). It lets drivers behave differently for specific laptop models.

</details>

---

## Quiz 9: The Bug Hunt (Chapter 9)

**Q1.** Why was the SOF firmware approach a dead end?

**Q2.** What is the "Onion of Bugs" concept?

**Q3.** Approximately how many `switch` statements needed `case 0x60:` added?

a) 3
b) 10
c) 20
d) 50

**Q4.** How many reboots did the debugging process require?

**Q5.** What was the very last fix needed to get actual sound output?

<details>
<summary>Click for answers</summary>

1. AMD never published SOF firmware (`sof-rmb.ri`) for the Rembrandt platform — it simply doesn't exist
2. Each bug fix revealed the next problem underneath — you couldn't see bug #3 until bugs #1 and #2 were fixed, like peeling layers of an onion
3. **c)** Approximately 20 switch statements across 8 files
4. **~15 reboots**
5. Unmuting the RT1316 DAC switches — they default to off, and even with everything else working, the amplifiers were silently muted

</details>

---

## Quiz 10: The Fix (Chapter 10)

**Q1.** What was the most common type of code change in our patches?

**Q2.** Why did we add `ACP60_SDW_ADDR = 2` as a new constant?

**Q3.** How does the `pci-acp6x` fix detect SoundWire hardware?

a) It checks a hardcoded list of laptop models
b) It reads a file from disk
c) It checks for an ACPI child device at address 2
d) It asks PipeWire

**Q4.** What does the RT1316-only machine table entry do?

<details>
<summary>Click for answers</summary>

1. Adding **`case 0x60:` and `case 0x6f:`** to existing switch statements (fall-through to existing ACP 6.3 code paths)
2. The SoundWire controller ACPI address differs between platforms — Rembrandt uses address 2, Phoenix uses address 5. The named constant makes the code self-documenting.
3. **c)** It uses `acpi_find_child_device()` to check for a SoundWire controller (SDWC) at ACPI address 2
4. It teaches the machine driver about a codec configuration with **only RT1316 amplifiers** (no headphone codec). Without it, the driver didn't have a "recipe" for this combination.

</details>

---

## Quiz 11: UCM and PipeWire (Chapter 11)

**Q1.** What does UCM stand for?

**Q2.** What was wrong with the original UCM symlink?

**Q3.** What do the `EnableSequence` entries in our UCM profile do?

**Q4.** Which mixer controls needed to be switched from "off" to "on"?

<details>
<summary>Click for answers</summary>

1. **Use Case Manager**
2. It was a **broken symlink** pointing to `../../sof-soundwire/sof-soundwire.conf` which doesn't exist on Fedora
3. They run ALSA mixer commands (via `cset`) to **unmute the RT1316 DAC switches** when the speaker device is activated by PipeWire
4. `rt1316-1 DAC Switch` and `rt1316-2 DAC Switch` (both needed to be set to `on,on`)

</details>

---

## Quiz 12: Installing the Fix (Chapter 12)

**Q1.** What happens to patched modules when Fedora updates the kernel?

**Q2.** Why must you use `xz --check=crc32` instead of plain `xz`?

**Q3.** What command must be run after installing new module files?

**Q4.** What does the modprobe option `quirk=32768` represent?

<details>
<summary>Click for answers</summary>

1. They get **overwritten** by the distribution's original (unpatched) modules — you must re-run the installer
2. The kernel's XZ decompressor only supports **CRC32** checksums; the default CRC64 causes silent load failures
3. **`depmod -a`** to rebuild the module dependency index
4. `32768` = `ASOC_SDW_CODEC_SPKR` flag, telling the machine driver this system has SoundWire speaker amplifiers

</details>

---

## Quiz 13: Upstream Contributions (Chapter 13)

**Q1.** What tool do kernel developers use to send patches?

a) GitHub Pull Requests
b) GitLab Merge Requests
c) `git send-email`
d) Carrier pigeon

**Q2.** How many patches did we split our fix into?

**Q3.** What does the `Signed-off-by` line in a commit message mean?

**Q4.** How long does it typically take from patch submission to distribution release?

**Q5.** Why is upstreaming important?

<details>
<summary>Click for answers</summary>

1. **c)** `git send-email` — kernel development uses plain text email
2. **4 patches** (platform drivers, SoundWire manager, machine config, ACPI fallback)
3. It certifies the developer has the right to submit the code and agrees to the kernel's **Developer Certificate of Origin** (DCO)
4. **2-6 months** typically
5. It benefits all users with similar hardware, survives kernel updates automatically, and improves Linux's overall hardware support

</details>

---

## 🏆 Final Score

Count your correct answers across all quizzes (55 questions total):

| Score | Rating |
|-------|--------|
| 50-55 | 🐧 **Kernel Hacker** — Submit those patches! |
| 40-49 | 🔊 **Audio Engineer** — Solid understanding of the stack |
| 30-39 | 💻 **Linux Enthusiast** — Good foundation, re-read a few chapters |
| 20-29 | 🔰 **Curious Beginner** — Great start! The concepts will click with re-reading |
| 0-19  | 🤷 **Didn't Read the Book** — That's OK, the speakers still work regardless |

---

*Congratulations on making it through the entire tutorial! You now understand more about Linux audio internals than 99.9% of Linux users. Go forth and debug.*

---

[← Previous: Chapter 13](chapter-13-upstream-contributions.md) | [Back to Table of Contents →](README.md)
