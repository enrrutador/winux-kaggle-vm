#!/usr/bin/env bash
# Instalacion manual de Winux a /dev/vda (reemplazo deterministico de Calamares GUI).
# Corre DENTRO de la sesion live como root:  sudo bash ins.sh
# Log completo en /tmp/ins.log ; al final apaga la VM (el host relanza desde disco).
set -e
exec > /tmp/ins.log 2>&1
set -x
export DEBIAN_FRONTEND=noninteractive

# --- herramientas (la sesion live a veces no trae parted/unsquashfs) ---
command -v parted >/dev/null || (apt-get update && apt-get install -y parted)
command -v unsquashfs >/dev/null || (apt-get update && apt-get install -y squashfs-tools)

# --- liberar RAM del instalador grafico trabado ---
pkill -9 calamares || true
sleep 2

DISK=/dev/vda
swapoff -a || true
umount -R /mnt 2>/dev/null || true

# --- particionado GPT: 300M EFI + resto ext4 ---
parted -s $DISK mklabel gpt \
  mkpart ESP fat32 1MiB 301MiB \
  mkpart primary ext4 301MiB 100% \
  set 1 esp on
udevadm settle
sleep 2
mkfs.fat -F32 -n EFI ${DISK}1
mkfs.ext4 -F -L Winux ${DISK}2

# --- copiar sistema live al disco ---
mount ${DISK}2 /mnt
mkdir -p /mnt/boot/efi
mount ${DISK}1 /mnt/boot/efi
unsquashfs -f -d /mnt /cdrom/casper/filesystem.squashfs

# --- preparar chroot ---
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
mount --bind /run /mnt/run
mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars || true

# --- fstab / hostname / zona horaria ---
ROOT_UUID=$(blkid -s UUID -o value ${DISK}2)
EFI_UUID=$(blkid -s UUID -o value ${DISK}1)
cat > /mnt/etc/fstab <<EOF
UUID=$ROOT_UUID / ext4 errors=remount-ro 0 1
UUID=$EFI_UUID /boot/efi vfat umask=0077 0 1
EOF
echo winux-vm > /mnt/etc/hostname
ln -sf /usr/share/zoneinfo/America/Los_Angeles /mnt/etc/localtime
rm -f /mnt/etc/machine-id

# --- bootloader (entrada NVRAM + fallback removible) ---
chroot /mnt apt-get update
chroot /mnt apt-get install -y grub-efi-amd64-signed shim-signed efibootmgr
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=WINUX --recheck || true
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck
chroot /mnt update-grub
chroot /mnt update-initramfs -u -k all

# --- usuario + ssh ---
chroot /mnt useradd -m -s /bin/bash -G sudo,adm,cdrom,dip,plugdev kaggle
echo kaggle:winux2026 | chroot /mnt chpasswd
chroot /mnt apt-get install -y openssh-server
chroot /mnt systemctl enable ssh

# --- cierre ---
rm -f /mnt/etc/machine-id
sync
umount -R /mnt || umount -l /mnt || true
sync
echo INSTALACION-OK
sleep 5
poweroff
