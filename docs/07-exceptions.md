# 07 · Exceptions (E1–E22)

Every deviation from the literal target, with cause and fix. Each entry follows: what changed, why,
the fix, and why it does not weaken the target. The raw append-only original is
`artifacts/constraint-exceptions.md`; this is the curated view. [04-selinux.md](04-selinux.md) gives
the narrative for E5–E15. There is no E21.

## Spelling and profile

- **E1 — `-flto=auto` → `-flto` (full) and `-flto=thin` (bring-up).** `=auto` is a GCC spelling that
  clang rejects. The valid clang spelling is used. LTO is not disabled; the ThinLTO-to-full change is a
  documented escalation applied via `emerge -e @world` (CFLAG, not USE, so an emptytree rebuild is
  required). 436/441 packages built; the toolchain (clang/llvm 22) was rebuilt under full LTO and the
  system boots. See [06-full-lto.md](06-full-lto.md).
- **E2 — Stay on the `musl/llvm` profile; add hardened and SELinux through flags and USE.** No
  `musl/llvm/hardened` or `musl/llvm/selinux` composite profile exists, and the hardened and selinux
  leaf profiles are GCC-based. LLVM is required, so nothing hardening-related is dropped; it is just not
  profile-driven.
- **E3 — `ACCEPT_KEYWORDS="~amd64"`.** The musl/llvm profile is experimental and many dependencies are
  only in `~amd64`. This is part of the target.

## FEATURES=test fallout (kept global; narrow exceptions only)

- **E4 — `sys-boot/grub -device-mapper`.** `FEATURES=test` forces `lvm2[test]`, whose
  `REQUIRED_USE="test? ( lvm )"` then demands `lvm`; lvm2 was only pulled by `grub[device-mapper]`. The
  VM has no LVM, so device-mapper is dropped. Tests stay on.
- **E5 — `FEATURES=-test` for `expect` and `dejagnu`.** The `test` USE flag creates a circular build
  dependency between them. Per-package, on test-framework packages only.
- **E6 — `FEATURES=-test` for `efivar`.** `efivar[test]` → grub → efibootmgr → efivar cycle.
- **E7 — `FEATURES=-test` for the SELinux userland cluster** (selinux-python, setools, policycoreutils,
  selinux-base). Their test dependencies pull `pyqt6[testlib]` and a Python tree ending at
  `dev-python/pillow` with an unsatisfiable `REQUIRED_USE="test? ( jpeg jpeg2k lcms tiff truetype )"`.
  The SELinux userland is otherwise uninstallable; C/C++ tests stay on.
- **E8 — `FEATURES=-test` for `dev-python/*`.** Pervasive Python test-dependency cascades (pillow,
  setuptools slot conflicts, pyqt6). C extensions are still compiled with the project flags; only
  `pytest` runs are skipped. Bounded to one ecosystem.
- **E9 — libselinux musl patch, plus `FEATURES=-test` for `audit`.**
  `patches/sys-libs/libselinux/0001-musl-no-stat64.patch`: `selinux_restorecon.c` uses the glibc-only
  `struct stat64` and `lstat64()` (Makefile `USE_LFS=y`), which musl lacks. A two-line patch maps
  `stat64`→`stat` and `lstat64`→`lstat`. `audit` fails its test phase on musl, so its tests are
  disabled. Minimal musl portability fix; full diff in `config/etc-portage/patches/` and
  [08-findings.md](08-findings.md).

## Profile mask override

- **E10 — unmask the `selinux` USE flag** (`profile/use.mask = -selinux`). `profiles/base/use.mask`
  masks `selinux`; only SELinux profiles unmask it, so on `musl/llvm` nothing integrates. Required to
  meet the SELinux target on a non-selinux profile.

## no-X11 protection

- **E11 — do not run `@world` under `FEATURES=test`; use command-scoped `-test` for bulk rebuilds.**
  Test dependencies pull `xorg-server` and `mesa[X]` (through `glib` → `dconf[test]`) plus an
  unsatisfiable `iptables` and `xorg-server[xvfb]`. This protects the no-X11 target; global `test`
  stays on for normal builds.
- **E12 — command-scoped `FEATURES=-test` for the SELinux base-integration rebuild.** Same reason.

## sandbox and elogind

- **E13 — `sandbox.d` allows `/proc/*/attr/`.** SELinux-aware `cp -a` writes `/proc/*/attr/fscreate`,
  which the sandbox denies, so all emerge installs fail once SELinux is active. Fix:
  `SANDBOX_WRITE=/proc/self/attr/:/proc/thread-self/attr/`.
- **E14 — elogind is a build blocker on musl.** Two issues. (1) `journal-file.h` used `struct stat`
  without `<sys/stat.h>`; fixed by `patches/sys-auth/elogind/0001-musl-sys-stat.patch`. (2)
  `src/shared/user-record-nss.h` includes `<gshadow.h>`, and musl has no gshadow API (`struct sgrp`,
  `getsgnam`, and so on are glibc-only). This is missing functionality, not a missing include, and
  would require source changes to remove the gshadow usage. elogind therefore does not build on musl.
  Global USE is set to `-elogind`; seatd provides seat management. systemd is prohibited.
- **E15 — standalone `seatd` for seat and session management instead of elogind.** Cause: E14. Fix:
  `seatd[server]` with `-elogind` on pipewire, wireplumber, seatd, polkit, and dbus. The
  Wayland/PipeWire direction is intact.

## Hardening and full-LTO escalation

- **E16 — extra hardening and optimization flags.** `-O2` → `-O3`, plus `-fstack-clash-protection`,
  `-fcf-protection=full` (CET; `endbr64` verified in shipped binaries), `-ftrivial-auto-var-init=zero`,
  and `-fzero-call-used-regs=used-gpr`; LDFLAGS added `-Wl,-z,noexecstack` and `-Wl,-z,separate-code`.
  Applied with a second `emerge -e @world`: 435/440 built with no new failures (only the pre-existing
  net-tools, elogind, and obsolete llvm-21), and the system boots.
- **E16-FIX — removed `-Wl,--icf=safe` from global LDFLAGS.** `--icf` is an lld/gold-only option; GNU
  ld rejects it. The gcc-16 bootstrap links `libgcc_s.so` with GNU ld internally (collect2 uses
  binutils ld, not the system `LD=ld.lld`), so gcc failed, which dropped nodejs and firefox. The flag
  was removed globally; `-z,noexecstack` and `-z,separate-code` are kept because both linkers accept
  them. See E20 and [08-findings.md](08-findings.md).
- **E17 — net-tools ROSE disabled.** `net-tools-2.10` includes `<linux/rose.h>` (guarded by
  `#if HAVE_AFROSE`, default on), which fails because the kernel 7.1 UAPI omits `linux/rose.h`. Fix: an
  `/etc/portage/bashrc` `post_src_prepare` sets `HAVE_AFROSE` and `HAVE_HWROSE` to `n` in `config.in`,
  so `rose.c` compiles as a stub and net-tools builds with the hardening flags. ROSE is ham-radio
  AX.25; iproute2 is used instead.

## Compositors and desktops

- **E18 — Hyprland with XWayland off (`-X`); libXcursor X11 client libraries are unavoidable.**
  Hyprland (from the third-party `hyproverlay` overlay) is built with global `-X`, so there is no
  xwayland and no xorg-server. It unconditionally depends on `x11-libs/libXcursor`, which pulls
  libX11/libXrender/libXfixes (X11 client libraries only, no X server). This is the allowed "X11 only
  where a specific dependency forces it" case. Built with command-scoped `FEATURES=-test` (E11) to
  avoid the `libepoxy`/`libglvnd[test,X]` → xorg-server cascade.
- **E19 — GNOME is blocked on musl (recorded failure, not pursued).** The GNOME 49 stack hard-requires
  (a) elogind across the session, which is unbuildable on musl (E14) with systemd prohibited; (b) X11
  on gtk4, gtk+3, mesa, cairo, libepoxy, libxkbcommon, and vulkan-loader; and (c) PulseAudio via
  `pulseaudio-daemon`, `libcanberra[pulseaudio]`, and `alsa-plugins[pulseaudio]`. The logind
  requirement is the primary blocker and is independent of display protocol. Building GNOME would
  require dropping three target options, so it was not pursued on musl. This is the reason for the
  second image on glibc.
- **E20 — Firefox on musl: builds and runs with a dynamic source rust at a matching LLVM slot.**
  `www-client/firefox` resolves under the target USE (`wayland -X -pulseaudio hardened clang selinux`)
  with no X server and no PulseAudio. The build first failed because a statically-linked
  `dev-lang/rust-bin` cannot `dlopen()` libclang for bindgen. Resolution: set
  `www-client/firefox LLVM_SLOT: -21 22` so Firefox uses the already-installed `dev-lang/rust-1.95.0`
  (slot 22, source, dynamic) instead of defaulting to slot 21. The build is then one package (no rust
  rebuild) and the dynamic rustc loads libclang. `firefox-152.0` built and renders headless; the binary
  is musl-linked. Under enforcing, SELinux denies the firefox content sandbox's `user_namespace create`
  (F10), which is a degradation, not a build failure. Not a target change.

## KDE

- **E22 — KDE Plasma is blocked on musl (same logind cause as GNOME).** A full Plasma build resolved
  277 packages after enabling qt6 and X across the KDE/Qt stack and disabling tests (otherwise
  `libglvnd[test,X]` pulls `xorg-server[xvfb]`). The hard blocker is that
  `kde-plasma/plasma-workspace` unconditionally depends on `kde-frameworks/networkmanager-qt`, which
  hard-depends on `net-misc/networkmanager[elogind]`; elogind is unbuildable on musl (E14) and systemd
  is prohibited. No USE flag removes networkmanager-qt. With tests off, KDE needs only X client
  libraries and XWayland, not a full xorg-server, so it is closer than GNOME on that one axis, but the
  logind requirement is the same. On the glibc image, where elogind builds, KDE resolves and builds
  cleanly (`plasma-desktop-6.7.0`, 161 packages, no failures); `kwin_wayland` starts as a Wayland
  compositor (creates the socket, accepts clients) but its virtual backend cannot render headless in
  QEMU (`DRM_IOCTL_MODE_CREATE_DUMB` fails; mutter's headless backend falls back to swrast, kwin's does
  not). GNOME and KDE therefore both build on glibc and both fail on musl, isolating logind as the cause.

## Never done

musl → glibc; OpenRC → systemd; clang → gcc as the default compiler; global `-X`, `-pulseaudio`, or
`-systemd` turned off; global LTO or PIE turned off; global `FEATURES=-test`; switching to an easier
profile; or any undocumented mask.
