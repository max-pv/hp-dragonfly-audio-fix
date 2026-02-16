# 🔊 How We Fixed the Speakers: A Complete Guide

### The HP Dragonfly Pro Linux Audio Fix — From Zero to Sound

---

*A book for anyone who's ever wondered why their laptop speakers don't work on Linux,
and what it actually takes to fix it.*

*No prior Linux knowledge required. Sense of humor recommended.*

---

## Table of Contents

| # | Chapter | What You'll Learn |
|---|---------|-------------------|
| 1 | [What is Linux?](chapter-01-what-is-linux.md) | Operating systems, kernels, and why penguins matter |
| 2 | [How Computers Make Sound](chapter-02-how-computers-make-sound.md) | The journey from bits to vibrations in the air |
| 3 | [The Linux Audio Stack](chapter-03-the-linux-audio-stack.md) | ALSA, PipeWire, and the layers between apps and speakers |
| 4 | [Kernel Modules](chapter-04-kernel-modules.md) | Drivers, modules, and how Linux talks to hardware |
| 5 | [PCI Devices](chapter-05-pci-devices.md) | How Linux discovers what hardware you have |
| 6 | [SoundWire](chapter-06-soundwire.md) | The digital highway connecting your audio chips |
| 7 | [ACPI](chapter-07-acpi.md) | How your BIOS tells Linux what's inside your laptop |
| 8 | [The HP Dragonfly Pro](chapter-08-the-hp-dragonfly-pro.md) | Our patient: the specific hardware we're fixing |
| 9 | [The Bug](chapter-09-the-bug.md) | What went wrong and how we found it |
| 10 | [The Fix](chapter-10-the-fix.md) | Every patch explained in plain English |
| 11 | [UCM and PipeWire](chapter-11-ucm-and-pipewire.md) | The last mile: getting sound to your desktop |
| 12 | [Installing the Fix](chapter-12-installing-the-fix.md) | Practical guide to applying the patches |
| 13 | [Upstream Contributions](chapter-13-upstream-contributions.md) | How to give this fix back to the Linux community |
| 14 | [Quizzes](chapter-14-quiz.md) | Test your knowledge, chapter by chapter |

---

## Who Is This For?

- **Complete beginners** who want to understand what "kernel" and "driver" actually mean
- **Curious tinkerers** who want to know how Linux audio works under the hood
- **HP Dragonfly Pro owners** who just want their speakers to work, dammit
- **Aspiring kernel developers** who want to see a real-world bug hunt from start to finish

## How to Read This

Start from Chapter 1 and work your way through. Each chapter builds on the previous one.
Or, if you already know what a kernel is and just want the juicy bug-hunting story,
skip straight to Chapter 9.

The quizzes in Chapter 14 are optional but fun. No grades. We promise.

---

*Written February 2026, after approximately 15 reboots, 20+ patched switch statements,
and one mass "Holy smokes, it works!" moment.*
