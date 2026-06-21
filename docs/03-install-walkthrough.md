# 03 · Install walkthrough — step by step, with *why*

> **Context:** The ordered install, each step with its reason. The executable form is
> `scripts/install.sh`. The hard subsystems get their own deep-dives
> ([04-selinux.md](04-selinux.md), [05-wayland-pipewire.md](05-wayland-pipewire.md),
> [06-full-lto.md](06-full-lto.md)); this is the spine. Standalone.

1. **Partition `/dev/vda`** — GPT: ESP 512M (vfat) + swap 8G + root 51.5G (ext4).
   *Why ext4:* simplest reliable root. *Why 8G swap:* full-LTO links are RAM-hungry; insurance for 16 GiB.

2. **Unpack `stage3-amd64-musl-llvm-openrc`** to `/mnt/gentoo`.
   *Why this stage3:* ships musl + clang/lld + OpenRC and selects the `musl/llvm` profile, so the
   toolchain is correct with zero overrides.

3. **Chroot prep** — bind `/proc /sys /dev /run`, copy `resolv.conf`, **mount the ESP at
   `/mnt/gentoo/boot`**.
   *Why mount /boot now:* grub & grub-themes use `mount-boot.eclass`, which **refuses to install**
   if `/boot` isn't mounted (a safety guard). Skipping this silently drops grub from the merge.

4. **Write `make.conf`** (the hostile config — see [02-configuration.md](02-configuration.md)) and
   `emerge-webrsync` (stage3 has no ebuild tree).

5. **Boot tooling + kernel** — `emerge gentoo-sources installkernel grub efibootmgr dosfstools git`,
   then build the kernel with `make LLVM=1` using `defconfig` + `kernel-qa.fragment`.
   *Why clang kernel:* the LLVM toolchain is the target, and the kernel supports `LLVM=1`.
   *Why no initramfs:* virtio + ext4 are built-in, so the root mounts directly.
   *Expect:* a few `FEATURES=test` bootstrap snags here (E4–E6) — see [07-exceptions.md](07-exceptions.md).

6. **Bootloader** — `grub-install --removable` (writes `BOOTX64.EFI`, which OVMF boots without an
   NVRAM entry — robust for a disposable VM) + a named `Gentoo-QA` entry; `grub-mkconfig`.
   GRUB cmdline gets `console=tty0 console=ttyS0,115200 lsm=...,selinux,...`.

7. **fstab / hostname / root pw / services** — fstab by UUID; `root:gentooqa`; sshd permits root
   (QA convenience); a `ttyS0` agetty in `/etc/inittab`; `rc-update add sshd dhcpcd`.

8. **First boot from disk** (`scripts/launch-disk.sh`) — verify: boots, OpenRC, SSH in ~9 s, musl,
   clang/lld, no gcc, networking. (All confirmed.)

9. **SELinux (permissive)** — the involved part; full story in [04-selinux.md](04-selinux.md).
   Summary: unmask `selinux` USE (E10), patch libselinux for musl (E9), tame `FEATURES=test`
   cascades (E5–E8, E11–E13), rebuild base with `selinux`, label fs, reboot → SELinux active at boot.

10. **Wayland / PipeWire** — see [05-wayland-pipewire.md](05-wayland-pipewire.md). Install
    pipewire/wireplumber/wayland/seatd/mesa with **no X11 and no elogind** (seatd instead, E14/E15).

11. **Full LTO** — see [06-full-lto.md](06-full-lto.md). Switch to `-flto`, `emerge -e @world`.

12. **Snapshot** the verified state (`base-musl-llvm-selinux-wayland`, then `base-full-lto`).
