#!/usr/bin/env bash
# Launches the Gentoo QA guest under QEMU/KVM.
# Serial console -> unix socket (serial.sock) so it can be driven headlessly.
# QMP monitor       -> unix socket (qmp.sock).
# Host dir shared in via 9p (tag=hostshare) for stage3 tarballs.
# Host tcp 2222 -> guest 22 for SSH once sshd is up.
set -eu
cd "$(dirname "$0")"
HERE="$(pwd)"
HOSTSHARE="$(dirname "$HERE")"   # /home/alice/Documents/gentooshit

LIVE_CMDLINE="dokeymap root=live:CDLABEL=Gentoo-amd64-20260531 rd.live.dir=/ rd.live.squashimg=image.squashfs cdroot console=ttyS0,115200"

exec qemu-system-x86_64 \
  -name gentoo-musl-llvm-qa \
  -enable-kvm -cpu host -smp 8 -m 16384 \
  -machine q35 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file="$HERE/OVMF_VARS.fd" \
  -drive if=virtio,format=qcow2,file="$HERE/gentoo-musl-llvm.qcow2",cache=writeback \
  -cdrom "$HOSTSHARE/install-amd64-minimal-20260531T160106Z.iso" \
  -kernel "$HERE/gentoo-kernel" \
  -initrd "$HERE/gentoo-initrd.igz" \
  -append "$LIVE_CMDLINE" \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2224-:22 \
  -device virtio-net-pci,netdev=net0 \
  -virtfs local,path="$HOSTSHARE",mount_tag=hostshare,security_model=mapped-xattr,readonly=on \
  -display none \
  -serial unix:"$HERE/serial.sock",server,nowait \
  -qmp unix:"$HERE/qmp.sock",server,nowait \
  -rtc base=utc
