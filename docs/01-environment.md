# 01 · Environment — why a QEMU guest, and how to drive it

> **Context:** Explains where the install actually runs and how to reach it. Read this if you want
> to launch, log into, or watch the VM. Self-contained.

## Why a guest, not the host
The QA brief described the environment as a "disposable VM." A quick reality check
(`whoami` → `alice`, `lsblk` → a 1.9 TB **LUKS-encrypted btrfs root mounted at `/`**,
`uname` → a CachyOS workstation) showed it was a **real daily machine**, not a disposable VM.
Running the destructive install (partitioning, `mkfs`, "the machine should boot") against the
visible disks would have destroyed a real system.

So the install was redirected into a fresh **QEMU/KVM guest**: a 60 GiB qcow2 disk, 8 vCPU, 16 GiB
RAM, UEFI (OVMF), virtio devices. The host is never touched. "Disposable" becomes literally true.

## Two launchers (they differ on purpose)
- **`scripts/launch-vm.sh`** — boots the **live ISO** by *direct kernel boot* (`-kernel`/`-initrd`
  extracted from the ISO) with `console=ttyS0` so the live environment lands on a serial socket we
  can script. Also shares the host dir over **9p** (`hostshare`) to reach the stage3 tarball.
  Use this to (re)enter the installer/chroot.
- **`scripts/launch-disk.sh`** — boots the **installed system** from disk (OVMF →
  `/boot/EFI/BOOT/BOOTX64.EFI` → GRUB). No ISO, no `-kernel`. This is the normal post-install boot.

A plain `reboot` inside the disk-booted guest cycles back through GRUB (QEMU resets and boots the
disk again), so reboot-persistence is testable.

## How to reach the guest
- **SSH**: host `127.0.0.1:2224` → guest `:22` (user `root`, password `gentooqa`). Wrapper:
  `scripts/gssh 'cmd'`. (The installed system regenerated host keys, so the wrapper clears its
  `known_hosts` on change.) SSH is multiplexed — you can `tail -f` a build while other commands run.
- **Serial console**: QEMU exposes it on a unix socket `serial.sock`. Before sshd exists,
  `scripts/vmctl.py` holds the connection (logs to `serial.log`, sends via a FIFO). After sshd,
  just `socat -u UNIX-CONNECT:serial.sock CREATE:serial-disk.log` to capture boot output.
- **QMP monitor**: `qmp.sock`. Clean shutdown for snapshots:
  `printf '{"execute":"qmp_capabilities"}\n{"execute":"quit"}\n' | socat - UNIX-CONNECT:qmp.sock`
  (or `ssh ... poweroff` — the installed system has no acpid, so ACPI powerdown is ignored).

## Watching a build live (no extra setup)
```
scripts/gssh 'tail -f /root/ai-run/checkpoints/<the>.log'
```

## Snapshots
qcow2 internal snapshots, taken with the guest powered off:
```
qemu-img snapshot -c <tag> qemu-run/gentoo-musl-llvm.qcow2
qemu-img snapshot -l qemu-run/gentoo-musl-llvm.qcow2
```
Tags: `base-musl-llvm-selinux-wayland` (base) and `base-full-lto` (once full LTO is verified).

## Host tools used
`qemu-system-x86_64` 11, `qemu-img`, `sshpass`, `socat`, `jq` (for the Discord `say` helper).
KVM is usable without group changes (`/dev/kvm` is world-rw on this host).
