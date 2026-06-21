# 00 · Overview

> **Context:** Start here. One page on what this project is, the constraints, and where it stands.
> You don't need any other file to follow this one.

## The goal
Build a Gentoo system that combines a set of individually-supported but rarely-combined choices,
and find where the Gentoo ecosystem breaks under that combination. A "good" outcome is **either**:
- a bootable (if horrible) Gentoo install meeting all constraints, **or**
- a high-quality, reproducible record of exactly where it breaks and why.

Optimize for *truthful, reproducible QA*, not a pretty install.

## The constraints (the "hostile but coherent" target)
- **amd64**, **musl** (not glibc)
- **LLVM/Clang** toolchain + **lld** (not GCC) — *hard constraint*
- **OpenRC** (not systemd)
- **hardened-oriented**: PIE, SSP, `_FORTIFY_SOURCE`, RELRO/BIND_NOW, kernel hardening
- **SELinux** enabled if feasible
- **Wayland-only**, no X11 unless a dep truly forces it
- **PipeWire** (not PulseAudio)
- **LTO** (ThinLTO for bring-up, then full `-flto`)
- **tests enabled** where feasible (`FEATURES=test`)

Rule: never *silently* weaken a constraint. Any deviation is minimal, documented in
[07-exceptions.md](07-exceptions.md), and reportable as a bug.

## What was actually achieved
| Constraint | Status |
|---|---|
| amd64 / musl | ✅ musl confirmed, no glibc |
| LLVM/Clang/lld | ✅ clang 21 + ld.lld default; **gcc not installed** |
| OpenRC | ✅ no systemd |
| SELinux | ✅ **enabled at boot**, targeted, permissive, filesystem labeled |
| Wayland / PipeWire | ✅ installed; **no xorg-server, no pulseaudio** |
| LTO / PIE / hardening | ✅ full `-flto` + PIE/SSP/FORTIFY/RELRO global |
| tests | ⚠️ global `test` kept; narrow per-package/-op exceptions (see findings) |

## The one big lesson
Global `FEATURES=test` is the dominant source of breakage on this stack: it forces `test` USE
everywhere, producing REQUIRED_USE conflicts, circular bootstrap deps, and — worst — it drags
**X11** back in (via `glib`/`dbus`/`dconf` test-deps), directly fighting the no-X11 constraint.
Details in [08-findings.md](08-findings.md).

## Map of the rest
- *How the VM is set up / why not the host* → [01-environment.md](01-environment.md)
- *The hostile config itself* → [02-configuration.md](02-configuration.md)
- *Doing the install* → [03-install-walkthrough.md](03-install-walkthrough.md)
- *Hard parts*: [04-selinux.md](04-selinux.md), [05-wayland-pipewire.md](05-wayland-pipewire.md), [06-full-lto.md](06-full-lto.md)
- *Every deviation* → [07-exceptions.md](07-exceptions.md) · *Bug-worthy findings* → [08-findings.md](08-findings.md)
- *Reproduce it* → [09-reproduce.md](09-reproduce.md)
