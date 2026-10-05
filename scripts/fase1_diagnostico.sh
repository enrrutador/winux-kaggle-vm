#!/usr/bin/env bash
# FASE 1 — Diagnóstico READ-ONLY del runtime Kaggle
# Determina si la virtualización asistida por hardware (KVM) es viable.
# No modifica el host ni el contenedor (solo lectura).
set -u
s() { echo; echo "=== $* ==="; }

s "OS"; grep -E "PRETTY_NAME" /etc/os-release
s "Kernel / arquitectura"; uname -a; uname -m
s "Virt detectada"; systemd-detect-virt 2>/dev/null || true
s "CPU"; lscpu | grep -Ei "model name|^CPU\(s\)|hypervisor"
s "Flags VMX/SVM expuestos por el hipervisor de Kaggle"
grep -m1 "^flags" /proc/cpuinfo | tr ' ' '\n' | grep -E "^(vmx|svm)$" \
  && echo "VIRT HW EXPUESTA" || echo "SIN VMX/SVM → nested virtualization NO disponible"
s "/dev/kvm (sin crear nada)"
ls -l /dev/kvm 2>&1 || true
test -e /dev/kvm && echo EXISTE || echo "NO EXISTE"
test -r /dev/kvm && echo LEGIBLE; test -w /dev/kvm && echo ESCRIBIBLE
s "Módulo kvm disponible/cargable"
ls /sys/module/kvm 2>&1 | head -1; modinfo kvm 2>&1 | head -1
s "Kernel build tiene KVM compilado?"
(zgrep -E "CONFIG_KVM=" /proc/config.gz 2>/dev/null) || echo "config.gz no accesible"
s "Capabilities del contenedor (¿CAP_SYS_ADMIN?) "
grep -E "CapEff" /proc/self/status
command -v capsh >/dev/null && capsh --decode="$(grep CapEff /proc/self/status | awk '{print $2}')"
s "Recursos (cgroup-aware)"
nproc; cat /sys/fs/cgroup/cpu.max 2>/dev/null; cat /sys/fs/cgroup/memory.max 2>/dev/null
free -h | head -2
df -h /kaggle/working /tmp 2>/dev/null
s "QEMU"
command -v qemu-system-x86_64 && qemu-system-x86_64 --version | head -1 \
  || echo "QEMU no instalado (ver fase2)"

# PRUEBA OPCIONAL de funcionalidad real de /dev/kvm (solo si un día existe):
# crea el nodo solo dentro del contenedor y prueba open + ioctl reales.
if [ "${1:-}" = "--probar-kvm" ]; then
  s "Prueba ioctls KVM (crea nodo local inerte si falta)"
  [ -e /dev/kvm ] || mknod /dev/kvm c 10 232 2>&1
  python3 - <<'EOF'
import os, fcntl
try:
    fd = os.open('/dev/kvm', os.O_RDWR); print("open OK")
    try:
        print("KVM_GET_API_VERSION ->", fcntl.ioctl(fd, 0xAE00, 0))
        print("KVM_CREATE_VM ->", fcntl.ioctl(fd, 0xAE01, 0))
    except OSError as e: print("ioctl falló:", e.errno, e.strerror)
except OSError as e: print("open falló:", e.errno, e.strerror)
EOF
fi
