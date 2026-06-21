# 09 · Reproduce from scratch

> **Context:** How to rebuild this whole thing on another machine. Standalone checklist; pairs with
> `scripts/install.sh` and the rationale in [03-install-walkthrough.md](03-install-walkthrough.md).

## Inputs
- A Linux host with **QEMU/KVM** + `qemu-img`, `sshpass`, `socat`, `jq`, `bsdtar`.
- Gentoo **minimal install ISO** + **`stage3-amd64-musl-llvm-openrc`** tarball.
- This repo (`config/` and `scripts/` are what matter).

## 1. Make the guest
```sh
qemu-img create -f qcow2 gentoo-musl-llvm.qcow2 60G
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd OVMF_VARS.fd       # writable UEFI vars
bsdtar xf <iso> boot/gentoo boot/gentoo.igz               # live kernel + initrd for direct boot
# boot the live ISO with serial on a unix socket + 9p share of this dir:
scripts/launch-vm.sh        # (edit paths/port inside if needed; SSH fwd host:2224->guest:22)
```
Direct-kernel cmdline used: `root=live:CDLABEL=Gentoo-amd64-<date> ... cdroot console=ttyS0,115200`.

## 2. Bootstrap the live env (over serial via `vmctl.py`)
Set a root password, start sshd (`/etc/init.d/sshd start`, `PermitRootLogin yes`). From then on use
`scripts/gssh 'cmd'`.

## 3. Run the install
`scripts/install.sh` is the distilled, ordered procedure. It expects the stage3 + this repo
reachable at `/mnt/hostshare` (the 9p share). It will:
partition `/dev/vda` → unpack stage3 → chroot → drop in `config/make.conf` + the
`config/etc-portage/` overrides (and the libselinux patch) → `emerge-webrsync` → build the clang
kernel from `config/kernel-qa.fragment` → grub → fstab/services → SELinux (permissive) →
Wayland/PipeWire → (then) full LTO.

> Read [03-install-walkthrough.md](03-install-walkthrough.md) alongside it — the *why* for each step
> (especially: mount `/boot` before grub; the `FEATURES=test` exceptions E4–E13; unmask `selinux`
> E10; seatd-not-elogind E14/E15).

## 4. Boot the installed system
```sh
scripts/launch-disk.sh      # OVMF -> /boot/EFI/BOOT/BOOTX64.EFI -> GRUB -> disk
```

## 5. Verify (the success checklist)
```sh
scripts/gssh 'uname -a; ldd --version; clang --version; gcc --version || echo no-gcc; \
  cat /proc/1/comm; sestatus; id -Z; rc-status; \
  qlist -ICv x11-base/xorg-server || echo no-xorg; \
  qlist -ICv media-sound/pulseaudio || echo no-pulse'
```
Expect: musl, clang21/lld, **no gcc**, `init`, SELinux enabled/permissive, OpenRC services up, **no
xorg-server**, **no pulseaudio**.

## 6. Snapshot
```sh
# guest powered off:
qemu-img snapshot -c base-musl-llvm-selinux-wayland gentoo-musl-llvm.qcow2
# after a verified full-LTO base:
qemu-img snapshot -c base-full-lto gentoo-musl-llvm.qcow2
```

## Credentials / ports (this instance)
SSH `root@127.0.0.1:2224`, password `gentooqa`. Change for any non-disposable use.
