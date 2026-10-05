#!/usr/bin/env bash
# FASE 3 — Windows real en QEMU/TCG sobre Kaggle (SOLO si fases 1-2 OK).
# Requiere ISO de Windows obtenida LEGALMENTE por el usuario, p.ej.:
#   - Windows 10/11 Enterprise Evaluation (90 días): microsoft.com/evalcenter
#   - Windows Server Evaluation: microsoft.com/evalcenter
#   - Drivers virtio-win: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/
# Uso:  ./fase3_windows_vm.sh /ruta/a/windows.iso [ruta virtio-win.iso]
# Notas de diseño (cumplimiento):
#   * VM efímera: disco qcow2 en /tmp (scratch de sesión) → no persiste.
#   * Sin puertos expuestos a Internet: VNC y RDP bindeados SOLO a localhost.
#   * TCG thread=multi: único acelerador funcional en Kaggle (KVM no existe).
set -eu
ISO="${1:?Falta ISO de Windows (legal)}"; VIRTIO="${2:-}"
DIR=/tmp/winvm; mkdir -p "$DIR"; cd "$DIR"

RAM_MB="${RAM_MB:-6144}"      # 6GB: cabe en los ~31GB dejando margen al host
VCPUS="${VCPUS:-4}"           # el host solo tiene 4 vCPU
DISK_GB="${DISK_GB:-40}"
DISK="$DIR/windows.qcow2"

command -v qemu-system-x86_64 >/dev/null || {
  apt-get update -qq; apt-get install -y -qq --fix-missing qemu-system-x86 qemu-utils ovmf
}
[ -f "$DISK" ] || qemu-img create -f qcow2 "$DISK" ${DISK_GB}G

EXTRA_CD=()
[ -n "$VIRTIO" ] && EXTRA_CD=(-drive file="$VIRTIO",media=cdrom,if=ide,readonly=on)

# UEFI (OVMF) recomendado para Win10/11 modernos. Win11 además exige TPM2:
#   apt-get install swtpm swtpm-tools  y añadir: -chardev socket,... -tpmdev emulator,...
# Para una Fase 3 inicial se recomienda Windows 10 Enterprise Eval (sin TPM).
exec qemu-system-x86_64 \
  -accel tcg,thread=multi \
  -cpu qemu64 -smp "$VCPUS" -m "$RAM_MB" \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
  -drive file="$DISK",if=virtio,format=qcow2 \
  -drive file="$ISO",media=cdrom,if=ide,readonly=on \
  "${EXTRA_CD[@]}" \
  -boot d \
  -vga std -display none \
  -vnc 127.0.0.1:1 \
  -device virtio-net-pci,netdev=n0 \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:3389-:3389 \
  -usb -device usb-tablet \
  -monitor unix:"$DIR/monitor.sock",server,nowait
# Estimaciones bajo TCG (~6.5x overhead CPU, medido): instalación Win10 ~2-5h,
# arranque a escritorio ~10-30 min. Uso interactivo vía VNC/RDP: consola usable,
# GUI lenta. El workload ML debe ser ligero (inferencia pequeña, tests).
# Acceso remoto: SOLO localhost; nunca exponer a Internet (ver sección 8 del estudio).
