#!/bin/bash
set -e

DISK="/dev/sdX"         # CHANGE THIS to your actual disk
EFI_PART="${DISK}1"
ROOT_PART="${DISK}2"
HOSTNAME="archlinux"
LOCALE="en_US.UTF-8"
TIMEZONE="UTC"

echo "[+] Formatting partitions..."
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 "$ROOT_PART"

echo "[+] Mounting partitions..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

echo "[+] Installing base system..."
pacstrap -K /mnt base linux linux-firmware nano networkmanager grub efibootmgr

echo "[+] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "[+] Setting up system..."
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

sed -i "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname
cat <<EOT >> /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOT

echo "[+] Set root password:"
passwd

systemctl enable NetworkManager

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

echo "[+] Done. You can now reboot."
