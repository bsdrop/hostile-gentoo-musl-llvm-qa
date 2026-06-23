# 01 · Environment — the QEMU guest and how to drive it

This page explains where the install runs and how to reach it: launching, logging in, and capturing
output. It can be read on its own.

## Why a guest, not the host

The task described the environment as a disposable VM. It was not: `whoami` returned `alice`, `lsblk`
showed a 1.9 TB LUKS-encrypted btrfs root mounted at `/`, and the system was a CachyOS workstation in
daily use. Running a destructive install (partitioning, `mkfs`) against those disks would have
destroyed a real system.

The install was therefore run inside a fresh QEMU/KVM guest: a 60 GiB qcow2 disk, 8 vCPU, 16 GiB RAM,
UEFI (OVMF), and virtio devices. The host is not modified.

## Two launchers

- `scripts/launch-vm.sh` boots the live ISO by direct kernel boot (`-kernel` and `-initrd` extracted
  from the ISO) with `console=ttyS0`, so the live environment is reachable on a serial socket. It also
  shares the host directory over 9p (`hostshare`) to reach the stage3 tarball. Use this to enter the
  installer or chroot.
- `scripts/launch-disk.sh` boots the installed system from disk (OVMF → `/boot/EFI/BOOT/BOOTX64.EFI` →
  GRUB). No ISO, no `-kernel`. This is the normal post-install boot.

A `reboot` inside the disk-booted guest returns through GRUB (QEMU resets and boots the disk again),
so reboot persistence can be tested.

## Reaching the guest

- SSH: host `127.0.0.1:2224` → guest `:22` (user `root`, password `gentooqa`). Wrapper: `scripts/gssh
  'cmd'`. The installed system regenerated its host keys, so the wrapper clears its `known_hosts` when
  the key changes. SSH is multiplexed, so a build can be followed with `tail -f` while other commands
  run.
- Serial console: QEMU exposes it on the unix socket `serial.sock`. Before sshd exists, `scripts/vmctl.py`
  holds the connection (logs to `serial.log`, sends commands through a FIFO). After sshd is up, capture
  boot output with `socat -u UNIX-CONNECT:serial.sock CREATE:serial-disk.log`.
- QMP monitor: `qmp.sock`. Clean shutdown for snapshots:
  `printf '{"execute":"qmp_capabilities"}\n{"execute":"quit"}\n' | socat - UNIX-CONNECT:qmp.sock`.
  `ssh ... poweroff` does not work for shutdown because the installed system has no acpid, so ACPI
  power-down is ignored.

## Following a build

```
scripts/gssh 'tail -f /root/ai-run/checkpoints/<name>.log'
```

## Snapshots

qcow2 internal snapshots, taken with the guest powered off:

```
qemu-img snapshot -c <tag> <disk>.qcow2
qemu-img snapshot -l <disk>.qcow2
```

## Host tools

`qemu-system-x86_64` 11, `qemu-img`, `sshpass`, `socat`, `jq`. `/dev/kvm` is world-readable and
writable on this host, so KVM works without group changes.
