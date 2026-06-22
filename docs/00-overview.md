# 00 · Overview

This page describes the project, the target configuration, and the result. It can be read on its own.

## Goal

Build a Gentoo system that combines a set of supported but rarely-combined options, and record where
the ecosystem breaks under that combination. A successful result is either:

- a bootable install that meets all target options, or
- a reproducible record of where it breaks and why.

The priority is an accurate, reproducible record, not a polished install.

## Target configuration

- amd64, musl (not glibc)
- LLVM/Clang toolchain with lld (not GCC) — required
- OpenRC (not systemd)
- Hardened toolchain: PIE, SSP, `_FORTIFY_SOURCE`, RELRO/BIND_NOW, kernel hardening
- SELinux, enabled if feasible
- Wayland only; no X11 unless a dependency forces it
- PipeWire (not PulseAudio)
- LTO: ThinLTO for bring-up, then full `-flto`
- Tests enabled where feasible (`FEATURES=test`)

A target option is never weakened silently. Each deviation is minimal and is recorded in
[07-exceptions.md](07-exceptions.md).

## Result

| Target | Status |
|---|---|
| amd64 / musl | Met. musl confirmed, no glibc. |
| LLVM/Clang/lld | Met. clang with `ld.lld` as default; gcc not installed. |
| OpenRC | Met. No systemd. |
| SELinux | Met. Enabled at boot, targeted policy, filesystem labeled, **enforcing** with `root` mapped to `sysadm_t`. |
| Wayland / PipeWire | Met. Installed with no xorg-server and no pulseaudio. |
| LTO / PIE / hardening | Met. Full `-flto` and PIE/SSP/FORTIFY/RELRO applied globally. |
| Tests | Partial. Global `test` kept; narrow per-package exceptions (see [08-findings.md](08-findings.md)). |

## Main finding

Global `FEATURES=test` is the largest source of breakage on this stack. It enables the `test` USE
flag everywhere, which produces REQUIRED_USE conflicts, circular bootstrap dependencies, and pulls
X11 back in through `glib`, `dbus`, and `dconf` test dependencies, against the no-X11 target. See
[08-findings.md](08-findings.md).

## Index

- VM setup and why not the host: [01-environment.md](01-environment.md)
- The configuration: [02-configuration.md](02-configuration.md)
- The install: [03-install-walkthrough.md](03-install-walkthrough.md)
- Harder areas: [04-selinux.md](04-selinux.md), [05-wayland-pipewire.md](05-wayland-pipewire.md), [06-full-lto.md](06-full-lto.md)
- Deviations: [07-exceptions.md](07-exceptions.md). Findings: [08-findings.md](08-findings.md)
- Reproduce: [09-reproduce.md](09-reproduce.md)
