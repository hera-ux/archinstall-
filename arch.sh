#!/bin/bash

# PARTE 1: Particionado
read -p "¿Qué disco quieres usar? (ej: sda, nvme0n1): " disco

(
echo g
echo n
echo 1
echo
echo +1G
echo t
echo 1
echo n
echo 2
echo
echo +4G
echo t
echo 2
echo 19
echo n
echo 3
echo
echo
echo w
) | fdisk /dev/$disco

mkfs.fat -F32 /dev/${disco}1
mkswap /dev/${disco}2
swapon /dev/${disco}2
mkfs.ext4 /dev/${disco}3

curl -o /etc/pacman.d/mirrorlist "https://archlinux.org/mirrorlist/?country=ES&protocol=https&use_mirror_status=on"
sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist

mount /dev/${disco}3 /mnt
mkdir -p /mnt/boot
mount /dev/${disco}1 /mnt/boot

# PARTE 2: Instalación
echo "Instalando sistema base..."
pacstrap /mnt base linux linux-firmware nano

genfstab -U /mnt >> /mnt/etc/fstab

read -p "Hostname: " hostname
read -sp "Contraseña de root: " rootpass
echo
read -p "Nombre de usuario: " username
read -sp "Contraseña de usuario: " userpass
echo

cat > /mnt/setup.sh <<EOF
#!/bin/bash
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc
echo "es_ES.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=es_ES.UTF-8" > /etc/locale.conf
echo "KEYMAP=es" > /etc/vconsole.conf
echo "$hostname" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
HOSTS
echo "root:$rootpass" | chpasswd
useradd -m -G wheel -s /bin/bash $username
echo "$username:$userpass" | chpasswd
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
# Script de instalación de drivers para Arch Linux

echo "Selecciona tu tarjeta gráfica:"
echo "1) NVIDIA (GTX 900 series en adelante)"
echo "2) NVIDIA (GTX 600/700 series)"
echo "3) NVIDIA (GTX 400/500 series)"
echo "4) AMD"
echo "5) Instalar ambos (NVIDIA + AMD)"
read -p "Opción: " opcion

case $opcion in
    1)
        echo "Instalando drivers NVIDIA modernos..."
        pacman -S --noconfirm nvidia nvidia-utils nvidia-settings lib32-nvidia-utils opencl-nvidia lib32-opencl-nvidia
        ;;
    2)
        echo "Instalando drivers NVIDIA 470xx..."
        pacman -S --noconfirm nvidia-470xx-dkms nvidia-470xx-utils nvidia-settings lib32-nvidia-470xx-utils
        ;;
    3)
        echo "Instalando drivers NVIDIA 390xx..."
        pacman -S --noconfirm nvidia-390xx-dkms nvidia-390xx-utils lib32-nvidia-390xx-utils
        ;;
    4)
        echo "Instalando drivers AMD..."
        pacman -S --noconfirm mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau radeontop opencl-mesa lib32-opencl-mesa
        ;;
    5)
        echo "Instalando drivers NVIDIA + AMD..."
        pacman -S --noconfirm nvidia nvidia-utils nvidia-settings lib32-nvidia-utils opencl-nvidia lib32-opencl-nvidia
        pacman -S --noconfirm mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau radeontop opencl-mesa lib32-opencl-mesa
        ;;
    *)
        echo "Opción no válida"
        exit 1
        ;;
esac

echo "Reconstruyendo initramfs..."
mkinitcpio -P
echo "drivers instalados" 
pacman -S --noconfirm networkmanager
systemctl enable NetworkManager
EOF

chmod +x /mnt/setup.sh
arch-chroot /mnt /setup.sh
rm /mnt/setup.sh

echo "¡Listo! Reinicia con: umount -R /mnt && reboot"
