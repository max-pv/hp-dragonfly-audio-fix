# HP Dragonfly Pro extras

This profile contains machine-specific additions on top of the generic Rembrandt SoundWire patch set:

- HP-specific kernel quirks patch (`patches/`)
- UCM profile tuned for this hardware (`ucm/`)
- Modprobe quirk configuration (`modprobe.d/`)

Use this profile by passing `EXTRA=hp-dragonfly-pro` to `make` targets.
