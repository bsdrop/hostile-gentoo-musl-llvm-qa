# 04 · SELinux — the hardest part

> **Context:** A self-contained account of getting SELinux working on a musl/clang/OpenRC system
> that is *not* on a SELinux profile. This is where most QA findings came from. You can read this
> alone; cross-refs point to [07-exceptions.md](07-exceptions.md) for the terse exception entries.

## Outcome first
SELinux ends up **enabled at boot**: `sestatus` → enabled / targeted / **permissive**, the
filesystem is labeled (`/sbin/init` → `init_exec_t`, `/` → `root_t`), processes are contextualized
(`ps -eZ` → `init_t`, `kernel_t`), and the shell has a context (`id -Z` →
`unconfined_u:unconfined_r:unconfined_t`). Permissive (not enforcing) is deliberate: it logs
denials without locking out SSH while labeling/policy settle.

## The blockers, in the order they bit, and why

1. **`selinux` USE is masked off-profile (E10).** `profiles/base/use.mask` masks `selinux`; only the
   SELinux profiles unmask it. On `musl/llvm` it stays masked, so the userland installs but
   *nothing integrates* (coreutils/openrc/pam build `-selinux`). **Fix:** `/etc/portage/profile/use.mask`
   with `-selinux` to unmask. **Why it matters:** without this, boot-time policy loading is impossible.

2. **libselinux won't compile on musl (E9).** `selinux_restorecon.c` uses glibc-only `struct stat64`
   / `lstat64()` (the Makefile forces `USE_LFS=y`); musl has no `*64` API (its `stat`/`lstat` are
   already 64-bit), and clang turns the implicit declaration into a hard error. **Fix:** a 2-line
   `/etc/portage/patches` patch (`stat64`→`stat`, `lstat64`→`lstat`). **Why:** libselinux is the
   foundation; nothing SELinux builds without it. *(This is musl-specific, not clang/LTO-specific.)*

3. **`FEATURES=test` makes the userland uninstallable (E7/E8).** Global test auto-enables `test` USE
   on `selinux-python`/`setools`, which pull `pyqt6[testlib]` and a Python test tree
   (cryptography, werkzeug, pip, poetry-core…) that terminates in `dev-python/pillow` with an
   unsatisfiable `REQUIRED_USE="test?(jpeg jpeg2k lcms tiff truetype)"`. **Fix:** disable tests for
   the SELinux cluster and `dev-python/*` only (C/C++ tests stay on — that's where this QA cares).

4. **The sandbox blocks SELinux-aware coreutils (E13).** After coreutils is rebuilt `selinux`, `cp -a`
   writes the fscreate context to `/proc/*/attr/fscreate`; Gentoo's build sandbox *denies* that path
   → **every** subsequent emerge install fails. **Fix:** `sandbox.d` adds `SANDBOX_WRITE` for the
   `/proc/*/attr/` paths. **Why it's nasty:** turning on SELinux silently breaks all future builds
   until the sandbox is taught about the attr procfs.

5. **Integrating SELinux without dragging in X11 (E11/E12).** Rebuilding base packages with `selinux`
   under `FEATURES=test` pulls `dbus`/`glib` test-deps that need `xorg-server`/`mesa[X]` — i.e. tests
   would reintroduce X11, violating no-X11. **Fix:** run that *one* rebuild with command-scoped
   `FEATURES=-test` (global `test` unchanged). Packages rebuilt with `selinux`: openrc, coreutils,
   util-linux, pam, shadow, procps, findutils, openssh, sysvinit.

## Boot-time loading
With `openrc[selinux]` + `sysvinit[selinux]` + the `selinux-openrc` policy module, the policy loads
automatically at boot (dmesg shows `SELinux: Initializing` + policy capabilities). Kernel side is in
`kernel-qa.fragment` (`SECURITY_SELINUX`, `AUDIT`, `CONFIG_LSM=...,selinux`, `EXT4_FS_SECURITY`).

## What's left for "enforcing"
Move `SELINUX=enforcing` after reviewing AVC denials; that needs broader policy coverage for the
custom daemons. Documented as a follow-up, not a blocker — the target was "enabled if feasible," and
it is enabled.
