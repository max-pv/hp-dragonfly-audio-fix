# Chapter 1: What is Linux?

*In which we meet the penguin, learn what an operating system does, and discover why your laptop needs a tiny dictator to function.*

---

## Your Computer is a City

Imagine your laptop as a bustling city. It has:

- **Buildings** (hardware) — the CPU, memory, speakers, screen, keyboard
- **Roads** (buses) — the wires connecting everything together
- **Citizens** (applications) — Firefox, Spotify, your text editor
- **A mayor** (the operating system) — who makes sure everyone follows the rules

Without the mayor, it would be chaos. Firefox would try to use the speakers at the same time as Spotify. Your keyboard would send letters to the wrong window. The screen would display gibberish. It would be like a city council meeting, but worse.

## The Operating System

An **operating system** (OS) is the software that manages all of your computer's hardware and lets applications run without crashing into each other. You've probably heard of a few:

- **Windows** — made by Microsoft, runs on most PCs
- **macOS** — made by Apple, runs on Macs
- **Linux** — made by... well, *everyone*

That last one is the star of our story.

## What Makes Linux Special?

In 1991, a Finnish university student named **Linus Torvalds** was bored. (Great things happen when programmers get bored.) He decided to write his own operating system kernel and posted it online with the now-famous message:

> *"I'm doing a (free) operating system (just a hobby, won't be big and professional like gnu)"*

Spoiler: it got big and professional. Today, Linux runs:

- Every Android phone
- 96% of the world's top supercomputers
- Most of the internet's servers
- The International Space Station
- Your HP Dragonfly Pro laptop (hi there!)

And it's **open source**, meaning anyone can read, modify, and improve the code. This is incredibly important for our story, because it means *we* can fix bugs in it ourselves.

## The Kernel: The Real Boss

Here's where people get confused. "Linux" technically refers to just the **kernel** — the innermost core of the operating system. The kernel is like the city's underground infrastructure: water pipes, electrical grid, sewage system. You never see it, but nothing works without it.

The kernel's job is to:

1. **Talk to hardware** — "Hey speaker chip, play this sound"
2. **Manage memory** — "Firefox, you get this chunk of RAM. No, you can't have Spotify's chunk."
3. **Schedule processes** — "OK Spotify, you get the CPU for 5 milliseconds. Now it's Firefox's turn."
4. **Provide security** — "Random app, you do NOT get to read the user's passwords."

Everything else you see — the desktop, the file manager, the terminal — is built *on top of* the kernel. Those parts come from various projects and are bundled together into what's called a **Linux distribution** (or "distro").

## Distributions

A Linux distribution takes the kernel and wraps it in a complete package with:

- A desktop environment (the graphical interface you click around in)
- A package manager (an app store, basically)
- Pre-installed applications
- System configuration tools

Some popular distros:

| Distro | Known For |
|--------|-----------|
| **Fedora** | Cutting-edge features, used by developers (that's us!) |
| **Ubuntu** | Beginner-friendly, most popular on desktops |
| **Arch Linux** | "I use Arch, by the way" (it's a meme, and a lifestyle) |
| **Debian** | Rock-solid stability, the grandparent of many distros |

Your laptop runs **Fedora 43**, which means you're on a distro that ships the very latest kernel — version 6.18.9 in our case. This is relevant because newer kernels sometimes haven't caught up with newer hardware yet.

> 🐧 **Fun fact:** The Linux mascot is a penguin named **Tux**. Linus Torvalds chose a penguin because he was once bitten by one at a zoo. Really. You can't make this stuff up.

## Key Takeaways

- An **operating system** manages hardware and lets applications run
- **Linux** is an open-source OS kernel created by Linus Torvalds in 1991
- The **kernel** is the core that talks to hardware, manages memory, and schedules processes
- A **distribution** (like Fedora) packages the kernel with a desktop and applications
- Because Linux is open source, **anyone can read and fix the code** — including us

---

[Next: Chapter 2 — How Computers Make Sound →](chapter-02-how-computers-make-sound.md)
