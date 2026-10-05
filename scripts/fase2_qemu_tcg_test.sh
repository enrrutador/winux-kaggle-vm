#!/usr/bin/env bash
# FASE 2 — QEMU mínimo: primero KVM (esperado: fallo en Kaggle), luego TCG.
# Instala QEMU por la vía normal (apt) y bootea Alpine Linux (guest mínimo)
# midiendo: tiempo de boot + overhead de CPU (md5sum 256MB, host vs guest).
# Todo el trabajo se hace en /tmp (scratchpad de sesión, no persistente).
set -u
DIR=/tmp/vmtest; ISO=alpine-virt-3.21.8-x86_64.iso
URL="https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/$ISO"
mkdir -p "$DIR"; cd "$DIR"

echo "== [0] Instalar QEMU por vía normal si falta =="
command -v qemu-system-x86_64 >/dev/null || {
  apt-get update -qq
  apt-get install -y -qq --fix-missing qemu-system-x86 qemu-utils ovmf
}
qemu-system-x86_64 --version | head -1
qemu-system-x86_64 -accel help

echo; echo "== [A] QEMU -> KVM (esperado: FALLO en runtime Kaggle actual) =="
timeout 20 qemu-system-x86_64 -accel kvm -nodefaults -no-user-config \
  -display none -serial none -monitor none -S 2>&1; echo "exit=$?"

echo; echo "== [B] Descargar guest mínimo (Alpine virt, ~64MB) =="
[ -f alpine.iso ] || curl -sSL -o alpine.iso "$URL"; ls -lh alpine.iso
[ -f disk.qcow2 ] || qemu-img create -f qcow2 disk.qcow2 4G >/dev/null

echo; echo "== [C] Baseline host (md5 256MB) =="
( time (dd if=/dev/zero bs=1M count=256 2>/dev/null | md5sum) ) 2>&1 | grep -E "real|^[0-9a-f]{32}"

echo; echo "== [D] Boot TCG (MTTCG, 4 vCPU, 1GB) + benchmark en guest =="
{ sleep 60; printf '\nroot\n'; sleep 30; printf '\nroot\n'; sleep 15
  printf 'grep -m1 "model name" /proc/cpuinfo\n'; sleep 2
  printf 'U1=$(cut -d" " -f1 /proc/uptime); dd if=/dev/zero bs=1M count=256 2>/dev/null | md5sum; U2=$(cut -d" " -f1 /proc/uptime); awk -v a=$U1 -v b=$U2 "BEGIN{print \\"GUEST_DD256_SECONDS\\", b-a}"\n'
  sleep 240; printf 'echo BENCH_DONE\n'; sleep 3; printf 'poweroff\n'; sleep 8;
} | timeout 480 qemu-system-x86_64 \
      -accel tcg,thread=multi -m 1024 -smp 4 \
      -display none -serial stdio -monitor none \
      -cdrom alpine.iso -drive file=disk.qcow2,if=virtio,format=qcow2 \
      -boot d -nic none 2>&1 | grep -E "model name|GUEST_DD256|BENCH_DONE"

echo; echo "Interpretación: GUEST_DD256_SECONDS / real_host = overhead TCG aprox."
# Resultado de referencia (2026-10, Kaggle CPU session, QEMU 6.2):
#   host 0.669s, guest 4.33s → overhead ≈ 6.5x ; boot Alpine ≈ 60-130s
