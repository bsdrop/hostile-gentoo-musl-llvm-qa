#!/usr/bin/env bash
# Boots the INSTALLED Gentoo from disk (OVMF UEFI -> /boot/EFI/BOOT/BOOTX64.EFI -> GRUB).
# No live ISO, no -kernel direct boot. Serial -> serial.sock, QMP -> qmp.sock, ssh host:2224->guest:22.
set -eu
cd "$(dirname "$0")"
HERE="$(pwd)"
exec qemu-system-x86_64 \
  -name gentoo-musl-llvm-qa-installed \
  -enable-kvm -cpu host -smp 8 -m 16384 \
  -machine q35 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file="$HERE/OVMF_VARS.fd" \
  -drive if=virtio,format=qcow2,file="$HERE/gentoo-musl-llvm.qcow2",cache=writeback \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2224-:22 \
  -device virtio-net-pci,netdev=net0 \
  -display none \
  -serial unix:"$HERE/serial.sock",server,nowait \
  -qmp unix:"$HERE/qmp.sock",server,nowait \
  -rtc base=utc
