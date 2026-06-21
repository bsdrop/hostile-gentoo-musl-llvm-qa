# 06 · Full LTO

> **Context:** Why and how the system moves from ThinLTO to full LTO, and what's special about
> applying it. Standalone.

## Why two phases
Bring-up used **ThinLTO** (`-flto=thin`): faster, far lower peak RAM, less fragile — ideal to get a
bootable base quickly. The QA target is **full LTO** (`-flto`), which is heavier and more likely to
expose miscompiles / OOM / link failures (exactly the breakage we want to surface). So: get a clean
ThinLTO base, snapshot it, then escalate to full LTO.

## Why `emerge -e @world` is required
LTO level lives in `COMMON_FLAGS` (a **CFLAG**), not in USE. Portage tracks USE changes for
`--newuse`/`-uDN`, but **not** CFLAG changes — so switching `-flto=thin` → `-flto` triggers *zero*
rebuilds via `-uDN`. The only way to re-apply it across the system is an **emptytree** rebuild:
`emerge -e @world` (recompile everything from scratch). Here that's 441 packages, including the
toolchain itself.

## How it's run
```sh
# make.conf: COMMON_FLAGS ... -flto=thin  ->  -flto
FEATURES="-test" emerge -e --keep-going=y @world
```
- **`FEATURES=-test` (command-scoped):** a full-`@world` rebuild under `FEATURES=test` is
  unresolvable and pulls X11 (see [08-findings.md](08-findings.md) / E11) — `iptables[test]`
  REQUIRED_USE, and `glib`→`dconf[test]`→`xorg-server`/`mesa[X]`. So this single bulk rebuild runs
  with tests off; the global `FEATURES=test` in make.conf is unchanged.
- **`--keep-going`:** full LTO is fragile; keep building and collect every failure rather than
  stopping at the first. Build logs are preserved (`PORTAGE_LOGDIR=/var/log/portage`) for triage.

## Risk notes
- The heaviest links (e.g. `sys-devel/llvm`, `mesa`) under full LTO are RAM-intensive; the 16 GiB
  guest + 8 GiB swap is the safety margin. If a full-LTO link OOMs/fails, `--keep-going` continues
  and the *previously installed* copy stays in place, so the system remains bootable.

## Success criterion / snapshot
"Full LTO success" = the full-LTO `@world` rebuild completes (modulo documented `--keep-going`
failures) **and the VM still boots**. On success, snapshot it as **`base-full-lto`** and use that as
the base for further experiments (e.g. Hyprland). Any package that cannot be built under full LTO is
recorded in [08-findings.md](08-findings.md) with its log.
