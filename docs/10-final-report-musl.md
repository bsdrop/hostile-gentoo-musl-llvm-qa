# 10 · Final Report — musl image (the briefing's required final-report)

> **Context:** The success report for the musl/LLVM image, structured to the 17 points the briefing
> required. Verified state captured in `artifacts/final/`. Standalone; deep-dives are
> [02-configuration.md](02-configuration.md), [04-selinux.md](04-selinux.md), [07-exceptions.md](07-exceptions.md),
> [08-findings.md](08-findings.md).

**Outcome: SUCCESS** — a bootable, hostile, reproducible Gentoo musl/LLVM QA VM meeting every hard
constraint, with the desktop-environment limits honestly characterized as findings.

1. **Exact stage3:** `stage3-amd64-musl-llvm-openrc-20260614T170130Z.tar.xz`
   (sha256 `b8a97df7…def84bd`, recorded in `artifacts/commands.log`).
2. **Final profile:** `default/linux/amd64/23.0/musl/llvm` (kept; no musl/llvm/hardened/selinux
   composite exists — hardening+SELinux layered, E2).
3. **Final USE:** `clang lto pie selinux hardened btrfs -elogind dbus nls opengl qml wayland pipewire
   alsa libinput policykit networkmanager screencast vaapi vulkan -X -pulseaudio -systemd -gnome -kde`
   (+ `~amd64`; `-elogind` because elogind is unbuildable on musl — E14/E14-COROLLARY). Full make.conf in `config/make.conf`.
4. **Final FEATURES:** `test fail-clean buildpkg preserve-libs parallel-install` + `PORTAGE_LOGDIR`.
   Global `test` kept; narrow per-package / command-scoped `-test` exceptions only (E5–E8, E11–E13, E21).
5. **Compiler/linker:** `clang 22.1.8` / `ld.lld 22`, `AR=llvm-ar`, `NM=llvm-nm` (set by the profile).
6. **musl/glibc:** **musl** (`ldd → musl libc`; `sys-libs/glibc` NOT installed). `sys-devel/gcc-16` IS
   installed (pulled as a build-dep by nodejs/rust during the firefox attempt) but `CC/CXX` remain
   clang/clang++ — the global default toolchain was never switched to GCC.
7. **OpenRC/systemd:** **OpenRC** (sysvinit+openrc); **no systemd** (`systemctl` absent).
8. **SELinux:** **Enforcing**, policy `targeted`, filesystem labeled, services confined
   (`init_t`/`sshd_t`/`system_dbusd_t`/`seatd_t`); **root login mapped to `sysadm_u:sysadm_r:sysadm_t`**
   (a *confined* admin domain — strictly tighter than Rocky/RHEL stock, where root is `unconfined_t`).
   `__default__` → `unconfined_u`. 0 boot AVC denials. Custom module `qa_local` (sshd→unconfined
   transition + service denials, audit2allow). See [04-selinux.md](04-selinux.md).
9. **PipeWire/PulseAudio:** **PipeWire** (+wireplumber); **no PulseAudio** (`media-sound/pulseaudio` absent).
10. **Wayland/X11:** **Wayland-only**, **no `x11-base/xorg-server`**. Only X *client* libs (libX11/
    libXcursor, pulled by Hyprland's cursor dep — E18); XWayland off (`-X`). Compositors use **seatd**.
11. **LTO/PIE/hardening:** **full `-flto`**, `-O3`, `-fstack-protector-strong`, `-D_FORTIFY_SOURCE=3`,
    `-fstack-clash-protection`, `-fcf-protection=full` (CET), `-ftrivial-auto-var-init=zero`,
    `-fzero-call-used-regs=used-gpr`; LDFLAGS RELRO/BIND_NOW/noexecstack/separate-code; PIE/CET/seccomp
    from the 23.0 profile. **Kernel:** clang-built with **KCFI** (`CONFIG_CFI`) + `LTO_CLANG` + KASLR +
    hardened-usercopy + init-on-alloc/free + slab hardening; boot cmdline `lockdown=confidentiality` +
    full CPU side-channel mitigations (`mitigations=auto,nosmt` + explicit spectre/ssb/l1tf/mds/tsx/
    mmio/retbleed/gds) + KSPP params (slab_nomerge, randomize_kstack, pti=on, vsyscall=none, debugfs=off).
12. **Package-specific exceptions:** E1–E22 in `artifacts/constraint-exceptions.md` (curated:
    [07-exceptions.md](07-exceptions.md)). Highlights: libselinux musl `stat64` patch (E9), `selinux`
    USE unmask (E10), `FEATURES=test` cascades (E4–E8/E11–E13/E21), grub `-device-mapper` (E4),
    net-tools ROSE off (E17), global `-elogind` (E14-corollary).
13. **Unresolved / blocked (documented findings, not silent):**
    - **GNOME** (E19) and **KDE Plasma** (E22): blocked by the **logind** requirement
      (elogind unbuildable on musl, systemd prohibited). Compromise advice in [08-findings.md](08-findings.md).
    - **firefox** (E20/F10): static `rust-bin` can't `dlopen` libclang; needs dynamic source rust
      matched to firefox's LLVM slot (21). Deferred (browsers = "later").
    - **systemd-tmpfiles-setup**: non-fatal boot warning under enforcing (services unaffected).
    - **net-tools** (E17), **elogind** (E14): fixed / substituted (seatd).
14. **Reproduce:** `scripts/install.sh` + [09-reproduce.md](09-reproduce.md) + `config/` (make.conf,
    kernel fragments, `etc-portage/` overrides incl. patches) + `artifacts/commands.log`.
15. **Boots after reboot:** **YES** — verified across many reboots (live→disk, full-LTO, hardened
    kernel, KCFI kernel, enforcing). UEFI(OVMF)→GRUB→`vmlinuz-7.1.1-gentoo`→OpenRC.
16. **SSH after reboot:** **YES** — sshd auto-starts (OpenRC); reachable on host `127.0.0.1:2224`;
    works even under SELinux enforcing with root confined to sysadm_t.
17. **Changed from the target & why:** `-flto=auto`→`-flto`/`thin` (GCC-ism→clang spelling, E1);
    hardening+SELinux layered instead of a composite profile (none exists, E2); `~amd64` (experimental
    profile, E3); global `-elogind` (unbuildable on musl, E14); narrow per-package/command-scoped
    `-test` (FEATURES=test induces unresolvable cascades, E5–E13); X *client* libs allowed where a dep
    forces them (E18); ThinLTO→full LTO staging (E1). No hard constraint was silently weakened.

## Snapshots (qcow2, `qemu-run/gentoo-musl-llvm.qcow2`)
`base-musl-llvm-selinux-wayland` → `base-full-lto` → `base-full-lto-hardened` → `hyprland` →
`wayland-desktop` → `hardened-kernel-kcfi` → `enforcing-rollback`(permissive) → `enforcing-ok`(unconfined
root) → `enforcing-tight`(root=sysadm_t, the headline state).

## What works (verified running)
Boot, OpenRC, SSH, networking; clang/lld toolchain; SELinux enforcing (root confined); Hyprland 0.55.4
and sway 1.12 (wlroots 0.20.1) both **built and launched** on virtio-gpu DRM (swrast, no virgl);
PipeWire/wireplumber/seatd; xdg-desktop-portal(-wlr). The KCFI hardened kernel boots and enforces.

## The one-line thesis
On musl + OpenRC (no systemd), **wlroots compositors via seatd are the viable Wayland desktop**;
**GNOME/KDE are not**, because they hard-require logind and `elogind` doesn't build on musl. Global
`FEATURES=test` is the single largest source of friction. Everything else (musl + clang + full-LTO +
KCFI-hardened kernel + enforcing SELinux) works and is reproducible.
