# AMD Rembrandt SoundWire Fix

## What this repo is

An out-of-tree kernel module patch set for AMD Rembrandt SoundWire audio bring-up.
It targets ACP revision compatibility (`0x60`/`0x6f` vs `0x63` paths), SoundWire
enumeration, and related ASoC glue fixes.

Machine-specific behavior is separated into `extras/<profile>/`.

## Patch layout

- `patches/full-diff.patch`: generic combined patch
- `patches/upstream/*.patch`: generic split patch series
- `extras/<profile>/patches/*.patch`: optional machine-specific quirks

## Build/install paths

- Build/install directly:
  - `make build KSRC=/path/to/linux-source [EXTRA=<profile>]`
  - `sudo make install [EXTRA=<profile>]`
- DKMS:
  - `sudo make dkms-install [EXTRA=<profile>]`
  - `sudo make dkms-remove`

## Source acquisition

Use `scripts/fetch-kernel-source.sh` to prepare distro-matched full source trees
(Fedora/RHEL-like, Debian/Ubuntu, and Arch-like).

Manual fallback instructions are in `docs/kernel-source-manual.md`.

## Validation

Use `testing/run-harness.sh` to verify:
- full patch applies
- split patches apply
- optional extras apply
- revision constants are used
