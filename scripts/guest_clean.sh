#!/usr/bin/env bash
# Limpieza pre-checkpoint DENTRO del guest (corre como root).
# Achica el qcow2 antes de subirlo al Dataset. Uso:  sudo bash guest_clean.sh
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get clean
rm -rf /var/cache/apt/archives/*.deb /var/cache/apt/*.bin 2>/dev/null || true
apt-get autoremove -y --purge || true
journalctl --vacuum-size=100M --vacuum-time=7d 2>/dev/null || true
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
rm -rf /root/.cache/* 2>/dev/null || true
for d in /home/*/.cache; do rm -rf "$d" 2>/dev/null || true; done
rm -f /var/lib/snapd/cache/* 2>/dev/null || true
rm -f /var/log/*.gz /var/log/*.[0-9] 2>/dev/null || true
sync
df -h / | tail -1
echo CLEAN-OK
