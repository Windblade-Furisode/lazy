#!/bin/bash
set -e

# List disks
echo "[*] Available disks:"
lsblk -d -e 7,11 -o NAME,SIZE,MODEL
echo
read -rp "[?] Enter the target disk (e.g. /dev/sda or /dev/nvme0n1): " DISK

# Confirm
echo "[!] WARNING: This will erase ALL data on $DISK"
read -rp "Type YES to confirm: " confirm
if [[ "$confirm" != "YES" ]]; then
    echo "Aborting."
    exit 1
fi

# Partition assumptions
EFI_PART="${DISK}1"
ROOT_PART="${DISK}2"
HOSTNAME="archlinux"
LOCALE="en_US.UTF-8"
TIMEZONE="UTC"

# Format
echo "[+] Formatting $EFI_PART and $ROOT_PART..."
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 "$ROOT_PART"

# Mount
echo "[+] Mounting partitions..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

# Base install
echo "[+] Installing base system..."
pacstrap -K /mnt base linux linux-firmware nano networkmanager grub efibootmgr

# FSTAB
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot config
echo "[+] Configuring system..."
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

echo "[+] Installation complete. Reboot when ready."
