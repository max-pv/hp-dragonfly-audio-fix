# Chapter 2: How Computers Make Sound

*In which we learn that speakers are just fancy drums, and that turning numbers into vibrations is harder than it sounds. (Pun intended.)*

---

## Sound is Vibration

Before we talk about computers, let's talk about physics for 30 seconds. Don't worry, there's no math.

**Sound** is vibrations traveling through the air. When you pluck a guitar string, it vibrates back and forth. Those vibrations push air molecules around, creating pressure waves. Those waves travel through the air, reach your ear, vibrate your eardrum, and your brain goes "oh hey, that's a guitar."

The number of vibrations per second determines the **pitch**:
- 440 vibrations per second = the note A (like a tuning fork)
- 20 vibrations per second = the lowest sound humans can hear (a deep rumble)
- 20,000 vibrations per second = the highest (that annoying mosquito whine)

The size of the vibrations determines the **volume**: big vibrations = loud, small vibrations = quiet.

That's it. That's sound. Everything else is just details.

## From Numbers to Noise

Your computer stores everything as numbers. Photos? Numbers describing colors of pixels. Text? Numbers mapped to letters. Sound? You guessed it — numbers.

A digital audio file is just a long list of numbers. Each number represents the position of a speaker cone at a specific moment in time. Typically, there are **48,000 numbers per second** (that's what "48 kHz sample rate" means). Your computer reads these numbers and sends them to the speaker fast enough to create smooth vibrations.

This method of storing sound is called **PCM** (Pulse Code Modulation). It's the standard way computers represent audio - just a stream of numbers sampled at regular intervals. Think of it like a flip-book animation: each frame (sample) is slightly different, and when you flip through them fast enough, it looks (or sounds) smooth and continuous.

Here's the journey:

```
🎵 Music file (numbers)
    ↓
💻 CPU reads the file
    ↓
🔌 Audio chip converts numbers to electrical signals (DAC)
    ↓
🔊 Amplifier makes the signal stronger
    ↓
📢 Speaker cone vibrates
    ↓
👂 Your ears hear music
```

## The DAC: Digital to Analog Converter

The most important step in that chain is the **DAC** — the Digital-to-Analog Converter. It's the translator between the digital world (numbers, bits, ones and zeros) and the analog world (continuous electrical waves that move a speaker).

Think of it like this: your computer speaks in Morse code (beep-beep-boop), and the DAC translates it into a smooth human voice.

Every device that plays sound has a DAC somewhere:
- Your phone has one
- Your laptop has one (or several!)
- Those fancy audiophile USB dongles people buy? Those are external DACs

> 🎧 **Fun fact:** Some audiophiles spend thousands of dollars on DACs, claiming they can hear the difference between a $10 DAC and a $1,000 one. Scientists remain skeptical. Wallets remain empty.

## The Amplifier: Making It Loud Enough

The signal coming out of a DAC is very quiet — too quiet to move a speaker cone. That's where the **amplifier** comes in. It takes a weak electrical signal and makes it stronger. Same shape, just bigger.

In our HP Dragonfly Pro, the amplifiers are **Realtek RT1316** chips. There are two of them — one for the left speaker, one for the right. They're smart amplifiers, meaning they also monitor the speaker to prevent damage. Thoughtful little chips.

## The Speaker: The Final Step

A **speaker** is surprisingly simple. It has:

1. A **magnet** (permanent, doesn't change)
2. A **coil of wire** (called the voice coil) sitting inside the magnet
3. A **cone** (usually paper or plastic) attached to the coil

When electricity flows through the coil, it becomes an electromagnet. It pushes and pulls against the permanent magnet, which moves the cone back and forth. Cone moves air. Air reaches your ears. You hear sound.

The whole process from "number in a file" to "air vibrating against your eardrum" happens in about **5 milliseconds**. Faster than you can blink. Faster than you can say "why don't my speakers work on Linux." (We'll get to that.)

## Inside Your Laptop

Here's what the audio hardware looks like inside the HP Dragonfly Pro:

```
┌─────────────────────────────────────────┐
│              AMD CPU (Ryzen)             │
│  ┌─────────────────────────────────┐    │
│  │   ACP (Audio CoProcessor)       │    │
│  │   ┌───────────────────────┐     │    │
│  │   │  SoundWire Controller │     │    │
│  │   └─────────┬─────────────┘     │    │
│  └─────────────┼───────────────────┘    │
└────────────────┼────────────────────────┘
                 │ SoundWire Bus
        ┌────────┴────────┐
        │                 │
  ┌─────┴─────┐    ┌─────┴─────┐
  │  RT1316   │    │  RT1316   │
  │  (Left)   │    │  (Right)  │
  │  Amp+DAC  │    │  Amp+DAC  │
  └─────┬─────┘    └─────┬─────┘
        │                 │
   🔊 Left            🔊 Right
   Speaker             Speaker
```

The AMD CPU has a built-in **Audio CoProcessor** (ACP) that handles audio duties. It connects to the two RT1316 amplifier chips via a digital bus called **SoundWire** (we'll learn about that in Chapter 6). Each RT1316 contains both a DAC and an amplifier, and each one drives one speaker.

It's a clean, modern design. The only problem is that the Linux kernel didn't know how to talk to it. Oops.

## Key Takeaways

- Sound is **vibrations** traveling through air
- Digital audio is a **list of numbers** representing speaker positions over time
- A **DAC** converts digital numbers into analog electrical signals
- An **amplifier** makes the signal strong enough to move a speaker
- The HP Dragonfly Pro has **two RT1316 chips** (amp + DAC combo) connected via SoundWire
- The entire chain from file to sound takes about **5 milliseconds**

---

[← Previous: Chapter 1](chapter-01-what-is-linux.md) | [Next: Chapter 3 — The Linux Audio Stack →](chapter-03-the-linux-audio-stack.md)
