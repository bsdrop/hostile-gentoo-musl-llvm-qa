# 02 · Configuration — the hostile make.conf, USE, FEATURES, kernel

> **Context:** The actual config that makes this system "hostile but coherent," with the reasoning
> behind each choice. The live files are in `config/` (`make.conf`, `kernel-qa.fragment`,
> `etc-portage/`). Standalone, but per-package overrides are explained in [07-exceptions.md](07-exceptions.md).

## Profile
`default/linux/amd64/23.0/musl/llvm` — chosen because it ships the target toolchain *by default*:
`CC=clang`, `CXX=clang++`, `LD=ld.lld`, `AR=llvm-ar`, `NM=llvm-nm`, and forces `pie cet seccomp`.
**Why not a hardened/selinux profile:** there is no `musl/llvm/hardened` or `musl/llvm/selinux`
composite; the hardened/selinux leaf profiles are GCC-based and would drop LLVM (a hard
constraint). So hardening + SELinux are layered on top via flags and USE — see E2.

## make.conf (key lines + why)
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
- **`-flto` (full):** the QA target is full LTO. `-flto=auto` (the briefing's spelling) is a
  GCC-ism; clang needs `-flto`/`-flto=thin`. Bring-up used ThinLTO for speed/RAM, then switched to
  full — see E1 and [06-full-lto.md](06-full-lto.md).
- **`-fstack-protector-strong` + `-D_FORTIFY_SOURCE=3`:** hardening. PIE/CET/seccomp come from the
  23.0 profile, RELRO+BIND_NOW from LDFLAGS.
- **`ACCEPT_KEYWORDS="~amd64"`:** the musl/llvm profile is experimental; many deps are ~amd64 (E3).
- **`FEATURES=test`:** kept globally per the brief. This is the chief breakage source (see findings);
  it is *never* globally disabled — only narrow per-package/-operation exceptions exist.
- **`PORTAGE_LOGDIR`:** `fail-clean` deletes the build dir on failure; this keeps a copy of every
  `build.log` so compile errors survive for bug reports.
- **`-X -pulseaudio -systemd`:** enforce no X11 / no PulseAudio / no systemd globally.

## Effective toolchain (verified)
```
CC=clang  CXX=clang++  LD=ld.lld  AR=llvm-ar  CHOST=x86_64-pc-linux-musl  ELIBC=musl
clang version 21.1.8 ; LLD 21.1.8 ; ldd → "musl libc (x86_64)" ; gcc → not installed
```

## Kernel (`config/kernel-qa.fragment`)
Built with **clang** (`make LLVM=1`); config = `make defconfig` + the fragment. Why these knobs:
- **virtio built-in** (`VIRTIO_BLK/PCI/NET/GPU`, `EXT4_FS`, `EFI_STUB`): root mounts with **no
  initramfs**; simplest reliable boot in QEMU.
- **serial** (`SERIAL_8250_CONSOLE`): headless console after reboot.
- **SELinux** (`SECURITY_SELINUX`, `AUDIT`, `CONFIG_LSM=...,selinux`, `EXT4_FS_SECURITY`): required
  for the SELinux target — see [04-selinux.md](04-selinux.md).
- **hardening** (`RANDOMIZE_BASE`, `FORTIFY_SOURCE`, `HARDENED_USERCOPY`, `INIT_ON_ALLOC`,
  `SLAB_FREELIST_HARDENED`, `STACKPROTECTOR_STRONG`): matches the hardened intent at the kernel level.

## What is intentionally NOT changed
musl→glibc, OpenRC→systemd, clang→gcc default, global `-X`/`-pulseaudio`/`-systemd`, global LTO/PIE
off, global `FEATURES=-test`, profile→an easier one. None of these are touched anywhere.
