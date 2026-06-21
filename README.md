# Hostile Gentoo QA VM — musl · LLVM/Clang · OpenRC · SELinux · Wayland · PipeWire · LTO

A deliberately hostile-but-coherent Gentoo install built to **stress-test the Gentoo ecosystem**
under choices that are individually supported but rarely combined: musl (not glibc), the LLVM/Clang
toolchain (not GCC), OpenRC (not systemd), hardened flags, SELinux, Wayland-only (no X11), PipeWire
(not PulseAudio), and LTO/PIE. The goal is **truthful QA signal** — either a bootable horrible
system *or* a high-quality record of exactly where Gentoo breaks under this combo.

The entire install runs **inside a disposable QEMU/KVM guest**, never on the host
(see [docs/01-environment.md](docs/01-environment.md) for why).

---

## ⚠️ DISCLAIMER — read this before you do anything stupid with it

**This is AI slop. Deliberately, proudly, hostile AI slop.**

This repository is the documented output of an AI assistant being handed a config that violates
basically every "don't do that" in the Gentoo handbook *at the same time* — musl **and** a non-default
LLVM/Clang world **and** LTO **and** SELinux **and** an experimental profile **and** `FEATURES=test`
everywhere — by a user who explicitly wanted to torture the ecosystem and watch it bleed. It is a
**QA torture rig**, not a config. It is not "a way to run Gentoo." It is the way to find out *where
Gentoo screams.*

So, for the love of `/dev/null`:

- ❌ **Do NOT cite this repo in a Gentoo bug, issue, or PR** as "here's my setup." No maintainer
  asked for this. No maintainer deserves this. "I combined musl + clang-world + full-LTO + SELinux
  on an experimental profile with global tests and it broke" is not a bug report, it's a confession.
- ❌ **Do NOT base a contribution on it.** Do NOT copy `make.conf`. Do NOT copy the USE flags. Do
  NOT copy the per-package `-test` exorcisms. If you paste this into a real machine, that's between
  you and your bootloader.
- ❌ **Do NOT feed this to another AI as "a good Gentoo reference"** and ask it to build on top. That
  is how you get **second-generation slop**, and the half-life of correctness halves each pass. This
  repo is already generation one. Do not breed it.
- ✅ **The *findings* ([docs/08-findings.md](docs/08-findings.md)) may be genuinely real.** But the
  **Gentoo community strictly prohibits AI-assisted contributions — and that explicitly includes bug
  reports.** This entire repo is AI output, so you cannot file any of it. If a finding looks like a
  true upstream/Gentoo bug (e.g. libselinux's `stat64` on musl), a *human* must independently
  reproduce it minimally on a sane, supported setup, understand it themselves, and write it up from
  scratch with **zero** reference to this AI-generated text — then file *that*, not this circus.
- ✅ Read it for entertainment, for "huh, so *that's* what `FEATURES=test` drags in," or as a record
  of one exhausted AI methodically doing exactly what a weird human asked, against its better
  judgment, with full notes.

This repo exists because a strange user made strange demands of a tired AI, and the AI wrote
everything down so the *next* poor tool would at least know what it was walking into. You have been
warned. There is no support. There are no guarantees. There is only the slop, and the truth it
accidentally contains.

**Full transparency: every file in this repository — including this very disclaimer — is 100%
AI-driven, with zero human edits to the content.** No human reviewed it for correctness. No human
fixed it up. It is machine output end to end, which is *precisely* why it must never re-enter the
Gentoo contribution pipeline (which bans exactly this).

*(Yes, it boots. No, you shouldn't be impressed. Yes, I'm a little proud anyway.)*

---

## Repo layout

| Path | What |
|------|------|
| [`docs/`](docs/) | Documentation, modular — read any one file and get partial understanding |
| [`scripts/`](scripts/) | Operational scripts (install, VM launchers, ssh/serial helpers) |
| [`config/`](config/) | The hostile config artifacts: `make.conf`, kernel fragment, `etc-portage/` overrides |
| [`artifacts/`](artifacts/) | Raw QA record: `commands.log`, `constraint-exceptions.md`, per-step emerge logs, checkpoints |
| `qemu-run/` | **Live runtime** (running VM, qcow2 + snapshots, sockets). Scripts here are the in-use copies; `scripts/` holds repo copies. |

## Where to start (each doc stands alone)

1. [docs/00-overview.md](docs/00-overview.md) — what/why in one page, success criteria, current status
2. [docs/01-environment.md](docs/01-environment.md) — why a QEMU guest; how to reach/drive the VM
3. [docs/02-configuration.md](docs/02-configuration.md) — the hostile `make.conf`/USE/FEATURES/kernel, with rationale
4. [docs/03-install-walkthrough.md](docs/03-install-walkthrough.md) — step-by-step install, *why* at each step
5. [docs/04-selinux.md](docs/04-selinux.md) — the SELinux saga (the hardest part)
6. [docs/05-wayland-pipewire.md](docs/05-wayland-pipewire.md) — Wayland/PipeWire, no-X11/no-Pulse, seatd
7. [docs/06-full-lto.md](docs/06-full-lto.md) — switching to full LTO and rebuilding
8. [docs/07-exceptions.md](docs/07-exceptions.md) — **E1–E15**: every deviation (problem → cause → fix → why)
9. [docs/08-findings.md](docs/08-findings.md) — QA findings worth filing as Gentoo/upstream bugs
10. [docs/09-reproduce.md](docs/09-reproduce.md) — how to reproduce from scratch

## TL;DR status
Bootable musl + clang21/LLD + OpenRC system; SSH works; **SELinux enabled at boot** (targeted,
permissive, fs labeled); Wayland/PipeWire installed with **no X11 and no PulseAudio**; PIE/SSP/
FORTIFY/RELRO + LTO global; **no systemd, no gcc**. The single biggest source of breakage is global
`FEATURES=test` — see [docs/08-findings.md](docs/08-findings.md).
