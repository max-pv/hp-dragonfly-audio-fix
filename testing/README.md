# Testing harness

Use this harness to verify that patch sets are coherent and apply cleanly.

## Quick validation

```bash
./testing/run-harness.sh
```

## Validate with machine-specific extras

```bash
./testing/run-harness.sh --extra hp-dragonfly-pro
```

## Include module build smoke test

```bash
./testing/run-harness.sh --build --extra hp-dragonfly-pro
```

What it checks:
- `patches/full-diff.patch` applies cleanly
- split upstream patches apply in order
- optional extra profile patches apply cleanly
- revision constants are used (no `case 0x60`/`case 0x6f` in patch files)
