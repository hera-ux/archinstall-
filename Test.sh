
#!/bin/bash
echo -e "\e[34m                   -`                    \e[0m"
echo -e "\e[34m                  .o+`                   \e[0m"
echo -e "\e[34m                 `ooo/                   \e[0m"
echo -e "\e[34m                `+oooo:                  \e[0m"
echo -e "\e[34m               `+oooooo:                 \e[0m"
echo -e "\e[34m               -+oooooo+:                \e[0m"
echo -e "\e[34m             `/:-:++oooo+:               \e[0m"
echo -e "\e[34m            `/++++/+++++++:              \e[0m"
echo -e "\e[34m           `/++++++++++++++:             \e[0m"
echo -e "\e[34m          `/+++ooooooooooooo/`           \e[0m"
echo -e "\e[34m         ./ooosssso++osssssso+`          \e[0m"
echo -e "\e[34m        .oossssso-````/ossssss+`         \e[0m"
echo -e "\e[34m       /osssssso.      :ssssssso.        \e[0m"
echo -e "\e[34m      :osssssss/        osssso+++.`      \e[0m"
echo -e "\e[34m     /ossssssss/        +ssssooo/-       \e[0m"
echo -e "\e[34m   `/ossssso+/:-        -:/+osssso+-     \e[0m"
echo -e "\e[34m  `+sso+:-`                 `.-/+oso:    \e[0m"
echo -e "\e[34m `++:.                           `-/+/   \e[0m"
echo -e "\e[34m .`                                 `/   \e[0m"

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
pacstrap /mnt base linux linux-firmware nano sudo

genfstab -U /mnt >> /mnt/etc/fstab

read -p "Hostname: " hostname
read -sp "Contraseña de root: " rootpass
echo
read -p "Nombre de usuario: " username
read -sp "Contraseña de usuario: " userpass
echo

cat > /mnt/setup.sh <<'EOF'
#!/bin/bash
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc
echo "es_ES.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=es_ES.UTF-8" > /etc/locale.conf
echo "KEYMAP=es" > /etc/vconsole.conf
EOF

cat >> /mnt/setup.sh <<EOF
echo "$hostname" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
HOSTS
echo "root:$rootpass" | chpasswd
useradd -m -G wheel -s /bin/bash $username
echo "$username:$userpass" | chpasswd
EOF

cat >> /mnt/setup.sh <<'EOF'
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Habilitar multilib (para librerías de 32 bits)
echo "Habilitando repositorio multilib..."
sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm

# ==========================================
# SELECCIÓN DE KERNEL
# ==========================================
echo ""
echo "============================================"
echo "    SELECCIÓN DE KERNEL LINUX"
echo "============================================"
echo ""
echo "1) Linux (kernel estándar de Arch)"
echo "   → Uso: General, equilibrado, actualizado"
echo "   → Recomendado para: Usuarios que quieren estabilidad y últimas características"
echo ""
echo "2) Linux-LTS (Long Term Support)"
echo "   → Uso: Máxima estabilidad, servidores, producción"
echo "   → Recomendado para: Sistemas que priorizan estabilidad sobre novedades"
echo ""
echo "3) Linux-Zen"
echo "   → Uso: Escritorio, gaming, multimedia"
echo "   → Recomendado para: Gamers y usuarios de escritorio que quieren mejor rendimiento"
echo ""
echo "4) Linux-Hardened"
echo "   → Uso: Seguridad máxima, entornos sensibles"
echo "   → Recomendado para: Usuarios que priorizan seguridad sobre rendimiento"
echo ""
echo "5) CachyOS (BORE scheduler, optimizado para gaming)"
echo "   → Uso: Gaming profesional, latencia ultra-baja"
echo "   → Recomendado para: Gamers competitivos y entusiastas del rendimiento"
echo ""
read -p "Selecciona el kernel a instalar (1-5): " opcion_kernel

case $opcion_kernel in
    1)
        echo ""
        echo "Manteniendo kernel estándar de Arch Linux..."
        # Ya está instalado, no hacer nada adicional
        KERNEL_INSTALADO="linux"
        ;;
    
    2)
        echo ""
        echo "Instalando Linux-LTS (Long Term Support)..."
        pacman -S --noconfirm linux-lts linux-lts-headers
        KERNEL_INSTALADO="linux-lts"
        echo "Kernel LTS instalado correctamente."
        ;;
    
    3)
        echo ""
        echo "Instalando Linux-Zen (optimizado para escritorio)..."
        pacman -S --noconfirm linux-zen linux-zen-headers
        KERNEL_INSTALADO="linux-zen"
        echo "Kernel Zen instalado correctamente."
        ;;
    
    4)
        echo ""
        echo "Instalando Linux-Hardened (seguridad reforzada)..."
        pacman -S --noconfirm linux-hardened linux-hardened-headers
        KERNEL_INSTALADO="linux-hardened"
        echo "Kernel Hardened instalado correctamente."
        ;;
    
    5)
        echo ""
        echo "============================================"
        echo "    INSTALACIÓN DE CACHYOS KERNEL"
        echo "============================================"
        echo ""
        
        # Agregar repositorio CachyOS
        echo "Agregando repositorios de CachyOS..."
        echo "" >> /etc/pacman.conf
        echo "# CachyOS repos" >> /etc/pacman.conf
        echo "[cachyos]" >> /etc/pacman.conf
        echo "Include = /etc/pacman.d/cachyos-mirrorlist" >> /etc/pacman.conf
        
        # Descargar mirrorlist
        curl -o /etc/pacman.d/cachyos-mirrorlist https://mirror.cachyos.org/cachyos-mirrorlist
        
        # Importar claves GPG
        echo "Importando claves GPG de CachyOS..."
        pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
        pacman-key --lsign-key F3B607488DB35A47
        
        # Actualizar base de datos
        pacman -Sy
        
        # Seleccionar variante de kernel CachyOS
        echo ""
        echo "Selecciona la variante de kernel CachyOS:"
        echo "1) linux-cachyos (BORE scheduler - RECOMENDADO)"
        echo "2) linux-cachyos-lts (versión LTS con optimizaciones)"
        echo "3) linux-cachyos-zen (basado en Zen con optimizaciones)"
        read -p "Opción (1-3): " cachyos_variant
        
        case $cachyos_variant in
            1)
                echo "Instalando linux-cachyos con BORE scheduler..."
                pacman -S --noconfirm linux-cachyos linux-cachyos-headers
                KERNEL_INSTALADO="linux-cachyos"
                ;;
            2)
                echo "Instalando linux-cachyos-lts..."
                pacman -S --noconfirm linux-cachyos-lts linux-cachyos-lts-headers
                KERNEL_INSTALADO="linux-cachyos-lts"
                ;;
            3)
                echo "Instalando linux-cachyos-zen..."
                pacman -S --noconfirm linux-cachyos-zen linux-cachyos-zen-headers
                KERNEL_INSTALADO="linux-cachyos-zen"
                ;;
            *)
                echo "Opción no válida, instalando linux-cachyos por defecto..."
                pacman -S --noconfirm linux-cachyos linux-cachyos-headers
                KERNEL_INSTALADO="linux-cachyos"
                ;;
        esac
        
        echo ""
        echo "✓ CachyOS kernel instalado correctamente."
        ;;
    
    *)
        echo "Opción no válida, manteniendo kernel estándar..."
        KERNEL_INSTALADO="linux"
        ;;
esac

echo ""
echo "Kernel seleccionado: $KERNEL_INSTALADO"
echo ""

pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Script de instalación de drivers para Arch Linux
echo ""
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
echo "Drivers instalados correctamente."
echo ""

echo "¿Deseas instalar paquetes adicionales?"
echo "1) Sí, instalar todo"
echo "2) Seleccionar categorías"
echo "3) No, omitir"
read -p "Opción: " instalar_paquetes

if [ "$instalar_paquetes" = "1" ]; then
    echo "Instalando todos los paquetes adicionales..."
    pacman -S --noconfirm base-devel git curl wget nano vim htop fastfetch \
    openssh networkmanager network-manager-applet dialog wpa_supplicant dhcpcd inetutils dnsutils \
    unzip unrar p7zip zip tar gzip bzip2 \
    pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber alsa-utils pavucontrol vlc ffmpeg \
    ttf-dejavu ttf-liberation noto-fonts noto-fonts-emoji \
    chromium \
    python python-pip nodejs npm gcc make cmake gdb \
    gparted ntfs-3g exfat-utils dosfstools \
    man-db man-pages reflector ufw bluez bluez-utils

elif [ "$instalar_paquetes" = "2" ]; then
    echo ""
    echo "Selecciona las categorías a instalar (s/n):"
    
    read -p "¿Herramientas de desarrollo? (s/n): " dev
    if [ "$dev" = "s" ]; then
        pacman -S --noconfirm python python-pip nodejs npm gcc make cmake gdb base-devel git
    fi
    
    read -p "¿Chromium? (s/n): " chrome
    if [ "$chrome" = "s" ]; then
        pacman -S --noconfirm chromium
    fi
    
    read -p "¿Sistema de archivos y discos? (s/n): " discos
    if [ "$discos" = "s" ]; then
        pacman -S --noconfirm gparted ntfs-3g exfat-utils dosfstools
    fi
    
    read -p "¿Fastfetch? (s/n): " fetch
    if [ "$fetch" = "s" ]; then
        pacman -S --noconfirm fastfetch
    fi
    
    read -p "¿Fuentes? (s/n): " fuentes
    if [ "$fuentes" = "s" ]; then
        pacman -S --noconfirm ttf-dejavu ttf-liberation noto-fonts noto-fonts-emoji
    fi
    
    read -p "¿Audio y multimedia? (s/n): " audio
    if [ "$audio" = "s" ]; then
        pacman -S --noconfirm pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber alsa-utils pavucontrol vlc ffmpeg
    fi
    
    read -p "¿Compresión y archivos? (s/n): " compress
    if [ "$compress" = "s" ]; then
        pacman -S --noconfirm unzip unrar p7zip zip tar gzip bzip2
    fi
    
    read -p "¿Utilidades de red? (s/n): " red
    if [ "$red" = "s" ]; then
        pacman -S --noconfirm openssh network-manager-applet dialog wpa_supplicant dhcpcd inetutils dnsutils curl wget
    fi
    
    read -p "¿Herramientas del sistema? (s/n): " sistema
    if [ "$sistema" = "s" ]; then
        pacman -S --noconfirm man-db man-pages reflector ufw bluez bluez-utils nano vim htop
    fi

else
    echo "Omitiendo instalación de paquetes adicionales..."
fi

pacman -S --noconfirm networkmanager
systemctl enable NetworkManager

echo ""
echo "¿Deseas instalar un entorno gráfico?"
echo "1) Sí, seleccionar entorno"
echo "2) No, omitir"
read -p "Opción: " instalar_grafico

if [ "$instalar_grafico" = "1" ]; then
    echo ""
    echo "Selecciona el entorno gráfico:"
    echo ""
    echo "=== ENTORNOS DE BAJOS RECURSOS ==="
    echo "1)  LXDE (muy ligero, ~200MB RAM)"
    echo "2)  LXQt (ligero y moderno, ~300MB RAM)"
    echo "3)  XFCE (equilibrado, ~400MB RAM)"
    echo "4)  MATE (estable, ~500MB RAM)"
    echo ""
    echo "=== ENTORNOS COMPLETOS ==="
    echo "5)  GNOME (moderno, ~800MB RAM)"
    echo "6)  KDE Plasma (completo, ~600MB RAM)"
    echo "7)  Cinnamon (elegante, ~700MB RAM)"
    echo "8)  Budgie (minimalista, ~500MB RAM)"
    echo ""
    echo "=== GESTORES DE VENTANAS (X11) ==="
    echo "9)  i3 (tiling, muy personalizable)"
    echo "10) Openbox (minimalista, muy ligero)"
    echo "11) bspwm (tiling avanzado)"
    echo "12) AwesomeWM (tiling con Lua)"
    echo ""
    echo "=== GESTORES DE VENTANAS (WAYLAND) ==="
    echo "13) Hyprland (tiling moderno con animaciones)"
    echo "14) Sway (i3 para Wayland)"
    echo "15) River (minimalista)"
    echo "16) Niri (scrollable tiling experimental)"
    echo ""
    read -p "Selecciona una opción (1-16): " opcion_de

    case $opcion_de in
        1)
            echo "Instalando LXDE..."
            pacman -S --noconfirm xorg xorg-server lxde lxdm
            systemctl enable lxdm
            ;;
        2)
            echo "Instalando LXQt..."
            pacman -S --noconfirm xorg xorg-server lxqt sddm
            systemctl enable sddm
            ;;
        3)
            echo "Instalando XFCE..."
            pacman -S --noconfirm xorg xorg-server xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
            systemctl enable lightdm
            ;;
        4)
            echo "Instalando MATE..."
            pacman -S --noconfirm xorg xorg-server mate mate-extra lightdm lightdm-gtk-greeter
            systemctl enable lightdm
            ;;
        5)
            echo "Instalando GNOME..."
            pacman -S --noconfirm xorg xorg-server gnome gnome-extra gdm
            systemctl enable gdm
            ;;
        6)
            echo "Instalando KDE Plasma..."
            pacman -S --noconfirm xorg xorg-server plasma kde-applications sddm
            systemctl enable sddm
            ;;
        7)
            echo "Instalando Cinnamon..."
            pacman -S --noconfirm xorg xorg-server cinnamon lightdm lightdm-gtk-greeter
            systemctl enable lightdm
            ;;
        8)
            echo "Instalando Budgie..."
            pacman -S --noconfirm xorg xorg-server budgie-desktop lightdm lightdm-gtk-greeter
            systemctl enable lightdm
            ;;
        9)
            echo "Instalando i3..."
            pacman -S --noconfirm xorg xorg-server i3-wm i3status i3lock dmenu lightdm lightdm-gtk-greeter
            systemctl enable lightdm
            ;;
        10)
            echo "Instalando Openbox..."
            pacman -S --noconfirm xorg xorg-server openbox obconf tint2 lightdm lightdm-gtk-greeter
            systemctl enable lightdm
            ;;
        11)
            echo "Instalando bspwm..."
            pacman -S --noconfirm xorg xorg-server bspwm sxhkd lightdm lightdm-gtk-greeter
            systemctl enable lightdm
            ;;
        12)
            echo "Instalando AwesomeWM..."
            pacman -S --noconfirm xorg xorg-server awesome lightdm lightdm-gtk-greeter
            systemctl enable lightdm
            ;;
        13)
            echo "Instalando Hyprland..."
            pacman -S --noconfirm hyprland kitty waybar swaybg swaylock-effects wofi mako grim slurp
            echo "Nota: Hyprland requiere configuración manual. Inicia con 'Hyprland' en TTY."
            ;;
        14)
            echo "Instalando Sway..."
            pacman -S --noconfirm sway waybar swaybg swaylock kitty wofi mako grim slurp
            echo "Nota: Sway requiere configuración manual. Inicia con 'sway' en TTY."
            ;;
        15)
            echo "Instalando River..."
            pacman -S --noconfirm river waybar kitty wofi mako grim slurp
            echo "Nota: River requiere configuración manual. Inicia con 'river' en TTY."
            ;;
        16)
            echo "Instalando Niri..."
            echo "Advertencia: Niri debe instalarse desde AUR"
            pacman -S --noconfirm git base-devel
            read -p "¿Deseas continuar con instalación desde AUR? (s/n): " instalar_aur
            if [ "$instalar_aur" = "s" ]; then
                echo "Deberás instalar 'niri' manualmente desde AUR después del primer inicio"
                pacman -S --noconfirm waybar kitty wofi mako grim slurp
            fi
            ;;
        *)
            echo "Opción no válida, omitiendo instalación de entorno gráfico..."
            ;;
    esac
    
    echo ""
    echo "Entorno gráfico instalado correctamente."
    
else
    echo "Omitiendo instalación de entorno gráfico..."
fi

# Instalar PipeWire (audio)
echo ""
echo "Instalando sistema de audio PipeWire..."
pacman -S --noconfirm pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber
echo "PipeWire instalado (se iniciará automáticamente al hacer login)."

# Instalar yay
echo ""
echo "Instalando yay (AUR helper)..."
pacman -S --noconfirm git base-devel
EOF

cat >> /mnt/setup.sh <<EOF
cd /home/$username
sudo -u $username git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u $username makepkg -si --noconfirm
cd ..
rm -rf yay
echo "yay instalado correctamente."
EOF

cat >> /mnt/setup.sh <<'EOF'

# Instalar Wine y Proton
echo ""
echo "¿Deseas instalar Wine y Proton para juegos/aplicaciones de Windows?"
echo "1) Sí, instalar todo"
echo "2) No, omitir"
read -p "Opción: " instalar_wine

if [ "$instalar_wine" = "1" ]; then
    echo "Instalando Wine y dependencias..."
    
    # Wine y dependencias principales
    pacman -S --noconfirm wine-staging winetricks wine-gecko wine-mono
    
    # Dependencias de 32 y 64 bits para Wine
    pacman -S --noconfirm lib32-mesa lib32-libgl lib32-gnutls \
        lib32-alsa-lib lib32-alsa-plugins lib32-libpulse \
        lib32-openal lib32-mpg123 lib32-giflib lib32-libpng \
        lib32-gst-plugins-base lib32-gst-plugins-good \
        lib32-v4l-utils lib32-libxcomposite lib32-libxinerama \
        lib32-opencl-icd-loader lib32-vkd3d lib32-vulkan-icd-loader
    
    # Steam (incluye Proton)
    pacman -S --noconfirm steam
    
    # Lutris (gestor de juegos con soporte Proton/Wine)
    pacman -S --noconfirm lutris
    
    # GameMode y Gamescope para mejor rendimiento
    pacman -S --noconfirm gamemode lib32-gamemode gamescope
    
    # Dar permisos nice a gamescope
    setcap 'CAP_SYS_NICE=eip' /usr/bin/gamescope
    
    echo "Wine, Proton (via Steam), Lutris y Gamescope instalados correctamente."
else
    echo "Omitiendo instalación de Wine y Proton..."
fi

echo ""
echo "====================================="
echo "Instalación completada exitosamente"
echo "====================================="
echo "Kernel instalado: $KERNEL_INSTALADO"
echo "====================================="
EOF

chmod +x /mnt/setup.sh
arch-chroot /mnt /setup.sh
rm /mnt/setup.sh

echo ""
echo "¡Instalación finalizada!"
echo "Reinicia el sistema con: umount -R /mnt && reboot"
