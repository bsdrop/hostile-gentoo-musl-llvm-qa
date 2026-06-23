#!/usr/bin/env bash
# Switch a hostile Gentoo image from SELinux permissive to enforcing, with root
# confined to the sysadm_t domain. Run as root inside the guest. Idempotent.
#
# This is the procedure used on both images (musl: targeted policy; glibc: mcs
# policy). See docs/04-selinux.md for the narrative. The most common blocker is
# a mislabeled /root, which stops sshd_t from setting up the login session.
set -eu

POLICY="$(sestatus | awk -F'name:[[:space:]]*' '/Loaded policy name/{print $2}')"
FCTX="/etc/selinux/${POLICY}/contexts/files/file_contexts"

echo "[1/6] full filesystem relabel (policy: ${POLICY})"
setfiles -F -e /proc -e /sys -e /dev -e /run -e /mnt -e /var/tmp/portage "$FCTX" /

echo "[2/6] relabel /root explicitly (it is often left default_t and then sshd_t"
echo "      cannot search it, which silently blocks every login)"
restorecon -RF /root

echo "[3/6] allow SSH logins to reach the sysadm role (anti-lockout; set BEFORE enforcing)"
setsebool -P ssh_sysadm_login on

echo "[4/6] map root to the confined sysadm_u user"
semanage login -a -s sysadm_u -r s0-s0:c0.c1023 root 2>/dev/null \
  || semanage login -m -s sysadm_u root

echo "[5/6] load qa_local (service denials). Rebuild from live denials if needed."
cd "$(dirname "$0")"
if [ -f qa_local.te ]; then
  checkmodule -M -m -o /tmp/qa_local.mod qa_local.te
  semodule_package -o /tmp/qa_local.pp -m /tmp/qa_local.mod
  semodule -i /tmp/qa_local.pp
fi

echo "[6/6] enable auditd, set enforcing, and reboot to verify"
rc-update add auditd default || true
rc-service auditd start || true
sed -i 's/^SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config
echo "Done. Reboot, then check: getenforce -> Enforcing ; id -Z -> sysadm_u:sysadm_r:sysadm_t ;"
echo "ausearch -m AVC -ts boot | grep permissive=0   (should be empty)"
