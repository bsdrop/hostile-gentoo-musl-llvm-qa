# 06 · Full LTO

Why and how the system moves from ThinLTO to full LTO, and what is specific about applying it.

## Two phases

Bring-up used ThinLTO (`-flto=thin`): faster, much lower peak RAM, and less fragile, which makes a
bootable base quick to reach. The target is full LTO (`-flto`), which is heavier and more likely to
expose miscompiles, OOM, and link failures, which is the breakage this project records. The order is:
reach a clean ThinLTO base, snapshot it, then switch to full LTO.

## Why `emerge -e @world` is required

The LTO level is in `COMMON_FLAGS`, a CFLAG, not in USE. Portage tracks USE changes for `--newuse` and
`-uDN`, but not CFLAG changes, so switching `-flto=thin` to `-flto` triggers no rebuilds through
`-uDN`. The only way to re-apply it across the system is an emptytree rebuild, `emerge -e @world`,
which recompiles everything including the toolchain. Here that is 441 packages.

## How it is run

```sh
# make.conf: COMMON_FLAGS ... -flto=thin  ->  -flto
FEATURES="-test" emerge -e --keep-going=y @world
```

- `FEATURES=-test` (command-scoped): a full `@world` rebuild under `FEATURES=test` does not resolve and
  pulls X11 (see [08-findings.md](08-findings.md) and E11): `iptables[test]` REQUIRED_USE, and
  `glib` → `dconf[test]` → `xorg-server` and `mesa[X]`. This one bulk rebuild runs with tests off; the
  global `FEATURES=test` in make.conf is unchanged.
- `--keep-going`: full LTO is fragile, so the build continues and collects every failure instead of
  stopping at the first. Build logs are preserved (`PORTAGE_LOGDIR=/var/log/portage`).

## RAM

The heaviest links under full LTO (for example `sys-devel/llvm` and `mesa`) use a lot of RAM; the
16 GiB guest with 8 GiB swap is the margin. If a full-LTO link fails or runs out of memory,
`--keep-going` continues and the previously installed copy stays in place, so the system remains
bootable.

## Success criterion and snapshot

Full LTO is considered successful when the full-LTO `@world` rebuild completes (apart from documented
`--keep-going` failures) and the VM still boots. On success the state is snapshotted as
`base-full-lto` and used as the base for later work. Any package that cannot build under full LTO is
recorded in [08-findings.md](08-findings.md) with its log.
