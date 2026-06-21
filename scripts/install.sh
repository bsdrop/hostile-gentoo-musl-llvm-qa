#!/usr/bin/env bash
###############################################################################
# Reproducible install: hostile musl/LLVM/hardened/SELinux/Wayland Gentoo QA VM
#
# RUN INSIDE the Gentoo minimal live ISO (booted in QEMU), as root.
# Assumes the stage3 musl-llvm-openrc tarball + this repo are reachable
# (here via a 9p mount at /mnt/hostshare). Target disk = /dev/vda.
#
# This script is the distilled, ordered form of /root/ai-run/commands.log.
# Every deviation from the literal briefing is documented in
# /root/ai-run/constraint-exceptions.md (referenced as E1..E15 below).
###############################################################################
set -euo pipefail
STAGE3=/mnt/hostshare/stage3-amd64-musl-llvm-openrc-20260614T170130Z.tar.xz
G=/mnt/gentoo

############################ 1. partition + format ############################
sgdisk --zap-all /dev/vda
sgdisk -n1:0:+512M -t1:ef00 -c1:ESP \
       -n2:0:+8G   -t2:8200 -c2:swap \
       -n3:0:0     -t3:8300 -c3:root /dev/vda
mkfs.vfat -F32 -n ESP /dev/vda1
mkswap -L swap /dev/vda2 && swapon /dev/vda2
mkfs.ext4 -q -L root /dev/vda3

############################ 2. unpack stage3 #################################
mkdir -p $G && mount /dev/vda3 $G
tar xpf "$STAGE3" -C $G --xattrs-include='*.*' --numeric-owner
# profile is already default/linux/amd64/23.0/musl/llvm (clang/lld/llvm-ar set by profile)

############################ 3. chroot prep ##################################
cp --dereference /etc/resolv.conf $G/etc/
mount --types proc /proc $G/proc
mount --rbind /sys $G/sys;  mount --make-rslave $G/sys
mount --rbind /dev $G/dev;  mount --make-rslave $G/dev
mount --bind /run $G/run;   mount --make-slave $G/run
mkdir -p $G/boot && mount /dev/vda1 $G/boot   # REQUIRED: mount-boot.eclass guard

############################ 4. make.conf (hostile) ##########################
# See qemu-run/ for the canonical /etc/portage/make.conf contents. Key points:
#   COMMON_FLAGS="-march=x86-64-v3 -O2 -pipe -fstack-protector-strong \
#                 -fno-semantic-interposition -flto=thin -D_FORTIFY_SOURCE=3"
#       (-flto=thin for bring-up; switch to -flto (full) later -- E1)
#   LDFLAGS="-Wl,-O1 -Wl,--as-needed -Wl,-z,relro -Wl,-z,now"
#   ACCEPT_KEYWORDS="~amd64"                               (E3)
#   FEATURES="test fail-clean buildpkg preserve-libs parallel-install"
#   PORTAGE_LOGDIR="/var/log/portage"   (so build logs survive fail-clean)
#   USE="clang lto pie selinux hardened btrfs elogind dbus nls wayland pipewire \
#        alsa libinput policykit networkmanager screencast vaapi vulkan \
#        -X -pulseaudio -systemd -gnome -kde -qt5 -qt6"
#   VIDEO_CARDS="virtio virgl"; INPUT_DEVICES="libinput"; GRUB_PLATFORMS="efi-64"
cp /mnt/hostshare/qemu-run/make.conf $G/etc/portage/make.conf   # (export your copy here)

############################ 5. portage overrides (the exceptions) ###########
# These mirror /etc/portage/{package.use,package.env,env,profile,patches,sandbox.d}.
# Reproduce from the captured tree in /root/ai-run/checkpoints/*-portage/etc-portage
# and constraint-exceptions.md. Highlights:
#   profile/use.mask:     -selinux                         (E10 unmask selinux USE)
#   package.use:          sys-boot/grub -device-mapper      (E4)
#                         sys-libs/libselinux python; sys-process/audit python
#                         app-misc/pax-utils python         (test? (python))
#                         sys-auth/seatd server -elogind; pipewire/wireplumber/polkit -elogind (E15)
#                         sys-apps/dbus -elogind            (E14)
#   env/notest.conf:      FEATURES="-test"
#   package.env:          expect,dejagnu,efivar,selinux-python,setools,policycoreutils,
#                         selinux-base,audit,dev-python/*  -> notest.conf  (E5-E8)
#   patches/sys-libs/libselinux/0001-musl-no-stat64.patch  (E9: stat64->stat)
#   sandbox.d/30selinux-attr: SANDBOX_WRITE=/proc/self/attr/:/proc/thread-self/attr/ (E13)

############################ 6. sync + base config ###########################
chroot $G /bin/bash -lc 'emerge-webrsync'
chroot $G /bin/bash -lc 'echo "C.UTF-8 UTF-8" > /etc/locale.gen; true'
ln -sf /usr/share/zoneinfo/UTC $G/etc/localtime

############################ 7. boot tooling + kernel ########################
chroot $G /bin/bash -lc 'emerge --keep-going=y sys-kernel/gentoo-sources sys-kernel/installkernel \
    sys-boot/grub sys-boot/efibootmgr sys-fs/dosfstools sys-apps/diffutils dev-vcs/git'
chroot $G /bin/bash -lc 'eselect kernel set 1'
cp /mnt/hostshare/qemu-run/kernel-qa.fragment $G/root/
chroot $G /bin/bash -lc 'cd /usr/src/linux && make LLVM=1 defconfig \
    && ./scripts/kconfig/merge_config.sh -m .config /root/kernel-qa.fragment \
    && make LLVM=1 olddefconfig && make LLVM=1 -j8 \
    && make LLVM=1 modules_install && make LLVM=1 install'

############################ 8. fstab + bootloader ##########################
# fstab: UUID= for /dev/vda3 (/ ext4), vda1 (/boot vfat), vda2 (swap)
# /etc/default/grub: serial console + lsm=...,selinux,...  (see qemu-run copy)
chroot $G /bin/bash -lc 'grub-install --target=x86_64-efi --efi-directory=/boot --removable --boot-directory=/boot'
chroot $G /bin/bash -lc 'grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Gentoo-QA --boot-directory=/boot || true'
chroot $G /bin/bash -lc 'grub-mkconfig -o /boot/grub/grub.cfg'

############################ 9. services + root + ssh #######################
echo 'hostname="gentoo-qa"' > $G/etc/conf.d/hostname
echo "root:gentooqa" | chroot $G chpasswd
sed -i -e 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' \
       -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' $G/etc/ssh/sshd_config
printf '\ns0:12345:respawn:/sbin/agetty 115200 ttyS0 vt100\n' >> $G/etc/inittab   # serial getty
chroot $G /bin/bash -lc 'rc-update add sshd default; rc-update add dhcpcd default'

########################### 10. SELinux (permissive) ########################
# selinux USE unmasked (E10); userland needs the libselinux musl patch (E9).
chroot $G /bin/bash -lc 'emerge sec-policy/selinux-base-policy sys-apps/policycoreutils \
    sys-libs/libselinux sys-apps/checkpolicy sys-apps/selinux-python sys-process/audit'
printf 'SELINUX=permissive\nSELINUXTYPE=targeted\n' > $G/etc/selinux/config
# Rebuild base with selinux integration WITHOUT tests (E11/E12 avoid X11 cascade):
chroot $G /bin/bash -lc 'FEATURES="-test" emerge -1 sys-apps/openrc sys-apps/coreutils \
    sys-apps/util-linux sys-libs/pam sys-apps/shadow sys-apps/findutils sys-process/procps \
    net-misc/openssh sys-apps/dbus'
# label filesystem, then SELinux loads at boot via openrc[selinux]/sysvinit[selinux]
chroot $G /bin/bash -lc 'setfiles -F -e /proc -e /sys -e /dev -e /run \
    /etc/selinux/targeted/contexts/files/file_contexts /'

########################### 11. PipeWire / Wayland (no X11, no elogind) #####
chroot $G /bin/bash -lc 'FEATURES="-test" emerge media-video/pipewire media-video/wireplumber \
    dev-libs/wayland dev-libs/wayland-protocols sys-auth/seatd media-libs/mesa'
chroot $G /bin/bash -lc 'rc-update add dbus default; rc-update add seatd default'

########################### 12. (later) full LTO ############################
# Switch COMMON_FLAGS -flto=thin -> -flto (full) in make.conf, then rebuild.
# NOTE: a full `emerge -e @world` is gated by E11 (FEATURES=test pulls X11 / unsat REQUIRED_USE);
# rebuild bounded sets with FEATURES=-test where the test-dep X11 cascade would otherwise trigger.

echo "DONE. Reboot from disk (UEFI -> /boot/EFI/BOOT/BOOTX64.EFI -> GRUB)."
