# 02 · Configuration — make.conf, USE, FEATURES, kernel

The configuration that defines this system, with the reason for each choice. The live files are in
`config/` (`make.conf`, `kernel-qa.fragment`, `etc-portage/`). Per-package overrides are listed in
[07-exceptions.md](07-exceptions.md).

## Profile

`default/linux/amd64/23.0/musl/llvm`. This profile ships the target toolchain by default: `CC=clang`,
`CXX=clang++`, `LD=ld.lld`, `AR=llvm-ar`, `NM=llvm-nm`, and sets `pie cet seccomp`.

There is no `musl/llvm/hardened` or `musl/llvm/selinux` composite profile. The hardened and selinux
leaf profiles are GCC-based and would drop LLVM, which is required. Hardening and SELinux are therefore
layered on top through flags and USE; see E2 in [07-exceptions.md](07-exceptions.md).

## make.conf

```sh
COMMON_FLAGS="-march=x86-64-v3 -O2 -pipe -fstack-protector-strong \
              -fno-semantic-interposition -flto -D_FORTIFY_SOURCE=3"
LDFLAGS="-Wl,-O1 -Wl,--as-needed -Wl,-z,relro -Wl,-z,now"
ACCEPT_KEYWORDS="~amd64"
FEATURES="test fail-clean buildpkg preserve-libs parallel-install"
PORTAGE_LOGDIR="/var/log/portage"
USE="clang lto pie selinux hardened btrfs elogind dbus nls wayland pipewire alsa libinput \
     policykit networkmanager screencast vaapi vulkan -X -pulseaudio -systemd -gnome -kde -qt5 -qt6"
VIDEO_CARDS="virtio virgl"
INPUT_DEVICES="libinput"
GRUB_PLATFORMS="efi-64"
```

- `-flto` (full): the target is full LTO. `-flto=auto` is a GCC spelling; clang needs `-flto` or
  `-flto=thin`. Bring-up used ThinLTO for build speed and lower RAM, then switched to full LTO; see E1
  and [06-full-lto.md](06-full-lto.md).
- `-fstack-protector-strong` and `-D_FORTIFY_SOURCE=3`: hardening. PIE, CET, and seccomp come from the
  23.0 profile; RELRO and BIND_NOW come from LDFLAGS.
- `ACCEPT_KEYWORDS="~amd64"`: the musl/llvm profile is experimental and many dependencies are only in
  `~amd64`; see E3.
- `FEATURES=test`: kept globally as part of the target. It is the main source of breakage (see
  [08-findings.md](08-findings.md)) and is never disabled globally; only narrow per-package exceptions
  exist.
- `PORTAGE_LOGDIR`: `fail-clean` deletes the build directory on failure. This keeps a copy of every
  `build.log` so compile errors remain available.
- `-X -pulseaudio -systemd`: no X11, no PulseAudio, no systemd, globally.

## Effective toolchain

```
CC=clang  CXX=clang++  LD=ld.lld  AR=llvm-ar  CHOST=x86_64-pc-linux-musl  ELIBC=musl
clang 22.1.8 ; LLD 22.1.8 ; ldd → "musl libc (x86_64)" ; gcc not installed
```

## Kernel (`config/kernel-qa.fragment`)

Built with clang (`make LLVM=1`); config is `make defconfig` plus the fragment.

- virtio built in (`VIRTIO_BLK/PCI/NET/GPU`, `EXT4_FS`, `EFI_STUB`): the root filesystem mounts with no
  initramfs, the simplest reliable boot in QEMU.
- serial (`SERIAL_8250_CONSOLE`): headless console after reboot.
- SELinux (`SECURITY_SELINUX`, `AUDIT`, `CONFIG_LSM=...,selinux`, `EXT4_FS_SECURITY`): required for the
  SELinux target; see [04-selinux.md](04-selinux.md).
- hardening (`RANDOMIZE_BASE`, `FORTIFY_SOURCE`, `HARDENED_USERCOPY`, `INIT_ON_ALLOC`,
  `SLAB_FREELIST_HARDENED`, `STACKPROTECTOR_STRONG`): kernel-level hardening to match the toolchain.

## Not changed

musl is not replaced by glibc; OpenRC is not replaced by systemd; clang remains the default compiler;
`-X`, `-pulseaudio`, and `-systemd` stay global; LTO and PIE stay on; `FEATURES=test` stays on; the
profile is not changed to an easier one.
