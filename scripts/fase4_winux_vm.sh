#!/usr/bin/env bash
# FASE 4 — Winux 11 en QEMU/TCG sobre Kaggle (re-hidratable por sesión).
# La ISO NO se versiona: se re-descarga de SourceForge si falta (~3 min a ~44MB/s).
# El disco qcow2 vive en /tmp (scratch efímero). Todo bindeado SOLO a localhost.
#
# Uso:
#   ISO_URL="https://sourceforge.net/projects/windows-linux/files/latest/download" \
#     bash fase4_winux_vm.sh
# Env opcionales: DIR (def /tmp/vmtest), RAM_MB (def 8192), VCPUS (def 4),
#   DISK_GB (def 60), ISO_URL, VNC_DISPLAY (def 0), SSH_HOST_PORT (def 2222).
set -eu

DIR="${DIR:-/tmp/vmtest}"
ISO_URL="${ISO_URL:-https://sourceforge.net/projects/windows-linux/files/latest/download}"
RAM_MB="${RAM_MB:-8192}"
VCPUS="${VCPUS:-4}"
DISK_GB="${DISK_GB:-60}"
VNC_DISPLAY="${VNC_DISPLAY:-0}"
SSH_HOST_PORT="${SSH_HOST_PORT:-2222}"

mkdir -p "$DIR"; cd "$DIR"
ISO="$DIR/winux.iso"
DISK="$DIR/winux.qcow2"

command -v qemu-system-x86_64 >/dev/null || {
  apt-get update -qq
  apt-get install -y -qq --fix-missing qemu-system-x86 qemu-utils ovmf
}
qemu-system-x86_64 --version | head -1

if [ ! -f "$ISO" ]; then
  echo "== Descargando Winux ISO (~6.3GB) =="
  curl -sSL -C - -o "$ISO" --retry 3 "$ISO_URL"
else
  echo "== ISO presente, reanudo/verifico =="
  curl -sSL -C - -o "$ISO" --retry 3 "$ISO_URL" || true
fi
ls -lh "$ISO"

[ -f "$DISK" ] || qemu-img create -f qcow2 "$DISK" "${DISK_GB}G"
ls -lh "$DISK"

# Vars UEFI propias por VM (no tocar las del sistema)
if [ ! -f "$DIR/OVMF_VARS.fd" ]; then
  cp /usr/share/OVMF/OVMF_VARS.fd "$DIR/OVMF_VARS.fd" 2>/dev/null \
    || cp /usr/share/OVMF/OVMF_VARS.4m.fd "$DIR/OVMF_VARS.fd"
fi

echo "== Lanzando Winux (TCG, VNC 127.0.0.1:${VNC_DISPLAY}, SSH guest en 127.0.0.1:${SSH_HOST_PORT}) =="
echo "   Instalador: Calamares (Welcome -> Location -> Keyboard -> Partitions -> Users -> Install)"
exec qemu-system-x86_64 \
  -name winux -machine q35 \
  -accel tcg,thread=multi \
  -cpu max -smp "$VCPUS" -m "$RAM_MB" \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
  -drive if=pflash,format=raw,file="$DIR/OVMF_VARS.fd" \
  -drive file="$DISK",if=virtio,format=qcow2 \
  -drive file="$ISO",media=cdrom,if=ide,readonly=on \
  -boot d \
  -device virtio-vga \
  -vnc "127.0.0.1:${VNC_DISPLAY}" \
  -device virtio-net-pci,netdev=n0 \
  -netdev user,id=n0,hostfwd="tcp:127.0.0.1:${SSH_HOST_PORT}-:22" \
  -usb -device usb-tablet \
  -monitor "unix:$DIR/winux-mon.sock,server,nowait" \
  -serial "file:$DIR/winux-serial.log"
# Notas:
# - Boot live KDE ~10-15 min bajo TCG; instalación a qcow2 ~30-90 min.
# - Winux no exige TPM (a diferencia de Win11): sin swtpm.
# - Capturas VNC: usar vncdo contra 127.0.0.1:5900+DISPLAY (solo localhost).
