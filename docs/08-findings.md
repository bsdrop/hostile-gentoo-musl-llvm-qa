# 08 · QA findings — the bug-report-worthy stuff

> **Context:** The actual QA payoff: concrete, reproducible breakage in the Gentoo ecosystem under
> the musl/LLVM/SELinux/Wayland/test combination, framed for filing. Standalone. Logs referenced
> here are under `artifacts/checkpoints/` and (in the guest) `/var/log/portage/`.

## F1 — libselinux fails to build on musl (`USE_LFS=y` uses glibc-only `stat64`) ★ strongest
- **Package:** `sys-libs/libselinux-3.10-r1`. **Phase:** compile.
- **Error:** `selinux_restorecon.c:446: variable has incomplete type 'struct stat64'` +
  `:460: call to undeclared function 'lstat64'`.
- **Cause:** the Makefile passes `USE_LFS=y`, and the source uses `struct stat64`/`lstat64()`, which
  **musl does not provide** (its `stat`/`lstat` are already 64-bit). clang makes the implicit decl a
  hard error.
- **musl-specific, not toolchain-specific:** would fail on GCC too (incomplete type is fatal).
- **Fix candidate:** use `stat`/`lstat` on musl, or guard the `*64` names with `__GLIBC__`.
- **Impact:** blocks the *entire* SELinux userland on musl until patched. Patch in
  `config/etc-portage/patches/sys-libs/libselinux/0001-musl-no-stat64.patch`.

## F2 — `FEATURES=test` reintroduces X11 on a no-X11 target ★ structural
- **Symptom:** `emerge -uDN @world` and even targeted base rebuilds pull `x11-base/xorg-server`,
  `media-libs/mesa[X]`, `libepoxy[X]` and then fail on `xorg-server[xvfb]`.
- **Chain:** `dev-libs/glib[dbus]` → `gdbus-codegen` → `gnome-base/dconf[test]` → X stack; also
  `net-firewall/iptables[test]` `REQUIRED_USE="test?(conntrack nftables)"`.
- **Cause:** global `FEATURES=test` auto-enables `test` USE on GUI/D-Bus libs, whose **test-deps**
  require X. **Conclusion:** `FEATURES=test` is effectively incompatible with a Wayland-only/no-X11
  musl/llvm desktop target. (Mitigated by command-scoped `FEATURES=-test` on bulk rebuilds.)

## F3 — enabling SELinux-aware coreutils breaks the build sandbox ★ surprising
- **Symptom:** after `coreutils[selinux]`, every package install fails; log shows repeated
  `F: open_wr / S: deny / P: /proc/thread-self/attr/fscreate` during `cp -a`.
- **Cause:** SELinux-aware `cp -a` writes the fscreate context to `/proc/*/attr/fscreate`; Gentoo's
  build sandbox denies that path.
- **Fix candidate:** `sys-apps/sandbox` should allow `/proc/*/attr/` when SELinux is active (we add
  `SANDBOX_WRITE` manually). High impact: silently bricks all emerges once SELinux is on.

## F4 — elogind fails to build on musl
- **Package:** `sys-auth/elogind-257.16`. **Error:** `sd-journal/journal-file.h:80: field has
  incomplete type 'struct stat'` (missing `<sys/stat.h>` visibility on musl).
- **Workaround:** none applied; substituted standalone `seatd`. Reportable as a musl include bug.

## F5 — `FEATURES=test` REQUIRED_USE / cycle cluster
A family of test-induced resolution failures, each individually a paper-cut but collectively the
dominant friction:
- `lvm2[test]` `REQUIRED_USE="test?(lvm)"` (pulled by `grub[device-mapper]`).
- `expect`↔`dejagnu` circular build dep; `efivar`→`grub`→`efibootmgr` cycle.
- `setools`/`selinux-python` test-deps → `pyqt6[testlib]` + python tree → `pillow`
  `REQUIRED_USE="test?(jpeg jpeg2k lcms tiff truetype)"` (unsatisfiable); `setuptools` slot conflict.
- `app-misc/pax-utils[test]` `REQUIRED_USE="test?(python)"` (in `@system`, blocks `@world`).
- **Theme for a report:** on a fresh musl/llvm base, `FEATURES=test` cannot resolve `@system`/`@world`
  without numerous per-package test exceptions; several REQUIRED_USE constraints make `test` a hard
  blocker rather than a soft one.

## F6 — profile gap: no musl+llvm+hardened+selinux profile; `selinux` USE masked off-profile
- There is no composite profile for the target; and `selinux` is masked by `profiles/base/use.mask`
  unless on a SELinux profile, so a musl/llvm SELinux target needs a manual `use.mask` override.

## Open / in-progress / roadmap
Done in order; each stage snapshots before the next so failures are recoverable.

1. **Full-LTO `@world` (441 pkgs):** running; per-package full-LTO failures (if any) get appended
   here with logs. On success → snapshot `base-full-lto`. See [06-full-lto.md](06-full-lto.md).
2. **Hyprland** (compositor, the "B" goal): heavy C++ Wayland stack — a strong combined test of
   full-LTO + musl + clang. Attempted on the full-LTO base.
3. **GNOME:** stretch goal. Known to fail even on Arch per the user, so this is expected to be a
   high-value *failure* artifact as much as a success target.
4. **Browsers — run at least one from each family** under Wayland:
   - Firefox family: **Mullvad Browser**, **Tor Browser**, **LibreWolf**
   - Chromium family: **Trivalent**, **Cromite**, **Brave**
   These are the real torture test for musl + clang + LTO (giant C++ builds, many of which assume
   glibc); each that builds *and runs* is recorded, each that breaks is filed here with its log.
5. **SELinux → enforcing:** only if the desktop + at least one browser actually run. Move
   `SELINUX=enforcing` after reviewing AVC denials and extending policy for the custom daemons.
   Until then it stays **permissive** (target was "enabled if feasible," already met).
