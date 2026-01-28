#!/bin/bash
# Avelon OS Build Script - V12 (Mirrorlist & Total Fix)
set -e

echo "--- 🚀 Avelon OS Builder V12 gestart ---"

if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Draai dit script als root (sudo ./build.sh)"
  exit 1
fi

# 1. Schoonmaak
echo "--- 🧹 Oude bestanden opruimen... ---"
rm -rf work out build_env
mkdir -p work out build_env

# 2. Basis kopiëren
echo "--- 📦 Basis bestanden kopiëren... ---"
cp -r /usr/share/archiso/configs/releng/* build_env/

# 3. Avelon Configs toepassen
echo "--- 🎨 Configs en Packages kopiëren... ---"
cp -r airootfs build_env/
cp packages.x86_64 build_env/
cp pacman.conf build_env/

# 4. FIXES GENEREREN
echo "--- 🔧 Configuraties repareren... ---"
mkdir -p build_env/airootfs/etc/calamares/modules
mkdir -p build_env/airootfs/etc/pacman.d

# FIX 0: DE MIRRORLIST FIX (Het internet probleem oplossen)
# We dwingen de ISO om de stabiele Geo-mirror te gebruiken.
echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > build_env/airootfs/etc/pacman.d/mirrorlist

# FIX A: Unpackfs (Het juiste pad!)
cat <<EOF > build_env/airootfs/etc/calamares/modules/unpackfs_fix.conf
unpack:
    -   source: "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
        sourcefs: "squashfs"
        destination: ""
EOF

# FIX B: Bootloader (Voorkom crash)
cat <<EOF > build_env/airootfs/etc/calamares/modules/bootloader_fix.conf
efiBootLoader: "grub"
kernel: "/vmlinuz-linux"
img: "/initramfs-linux.img"
fallback: "/initramfs-linux-fallback.img"
timeout: "5"
bootloaderEntryName: "Avelon OS"
grubInstall: "grub-install"
grubMkconfig: "grub-mkconfig"
grubCfg: "/boot/grub/grub.cfg"
grubProbe: "grub-probe"
efiBootMgr: "efibootmgr"
installEFIFallback: true
EOF

# FIX C: Services (Geen vmware/firewall onzin)
cat <<EOF > build_env/airootfs/etc/calamares/modules/services-systemd_fix.conf
units:
  - name: "NetworkManager"
    action: "enable"
    mandatory: true
  - name: "sddm"
    action: "enable"
    mandatory: true
EOF

# FIX D: De Slimme Kernel Bouwer (Downloadt linux en bouwt images)
cat <<EOF > build_env/airootfs/etc/calamares/modules/shellprocess-initcpio_fix.conf
i18n:
    name: "Linux Kernels installeren en genereren..."
dontChroot: false
timeout: 600
script:
    - command: "rm -f /etc/mkinitcpio.d/archiso.preset"
    - command: "rm -f /etc/mkinitcpio.d/linux-zen.preset"
    - command: "pacman-key --init"
    - command: "pacman-key --populate archlinux"
    # Omdat we de mirrorlist hebben gefixt, zal dit nu wel werken:
    - command: "pacman -Sy --noconfirm linux linux-firmware"
    - command: "mkinitcpio -p linux"
EOF

# FIX E: Settings (Volgorde corrigeren)
cat <<EOF > build_env/airootfs/etc/calamares/settings_fix.conf
modules-search: [ local ]
instances:
- id:       initcpio
  module:   shellprocess
  config:   shellprocess-initcpio.conf

sequence:
- show:
  - welcome
  - locale
  - keyboard
  - partition
  - users
  - summary
- exec:
  - partition
  - mount
  - unpackfs
  - machineid
  - fstab
  - locale
  - keyboard
  - localecfg
  - users
  - networkcfg
  - hwclock
  - services-systemd
  - shellprocess@initcpio
  - grubcfg
  - bootloader
  - umount
- show:
  - finished

branding: avelon
prompt-install: true
dont-chroot: false
oem-setup: false
disable-cancel: false
disable-cancel-during-exec: true
hide-back-and-next-during-exec: true
quit-at-end: false
EOF

# 5. Fix permissies Hyprland
chmod +x build_env/airootfs/etc/skel/.config/hypr/*.conf 2>/dev/null || true

# --- GEBRUIKER & RECHTEN ---
echo "--- 👤 Gebruiker en Rechten instellen... ---"

# Home map
mkdir -p build_env/airootfs/home/avelon
cp -r build_env/airootfs/etc/skel/. build_env/airootfs/home/avelon/

# User aanmaken
mkdir -p build_env/airootfs/usr/lib/sysusers.d
cat <<EOF > build_env/airootfs/usr/lib/sysusers.d/avelon.conf
u avelon 1000 "Avelon User" /home/avelon /bin/bash
m avelon wheel
m avelon video
EOF

# Sudo NOPASSWD
mkdir -p build_env/airootfs/etc/sudoers.d/
cat <<EOF > build_env/airootfs/etc/sudoers.d/avelon-nopasswd
avelon ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 build_env/airootfs/etc/sudoers.d/avelon-nopasswd

# --- OPSTART SCRIPT (De Wissel-truc & Wachtwoord) ---
mkdir -p build_env/airootfs/etc/systemd/system/
cat <<EOF > build_env/airootfs/etc/systemd/system/setup-avelon.service
[Unit]
Description=Setup Avelon Environment & Fix Calamares
Before=sddm.service

[Service]
Type=oneshot
# Wissel alle bestanden om naar de juiste plek
ExecStart=/bin/bash -c "echo 'avelon:avelon' | chpasswd; mv /etc/calamares/modules/unpackfs_fix.conf /etc/calamares/modules/unpackfs.conf; mv /etc/calamares/modules/bootloader_fix.conf /etc/calamares/modules/bootloader.conf; mv /etc/calamares/modules/services-systemd_fix.conf /etc/calamares/modules/services-systemd.conf; mv /etc/calamares/modules/shellprocess-initcpio_fix.conf /etc/calamares/modules/shellprocess-initcpio.conf; mv /etc/calamares/settings_fix.conf /etc/calamares/settings.conf"

[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/setup-avelon.service build_env/airootfs/etc/systemd/system/multi-user.target.wants/setup-avelon.service

# SDDM & Auto-login
mkdir -p build_env/airootfs/etc/systemd/system/
ln -sf /usr/lib/systemd/system/sddm.service build_env/airootfs/etc/systemd/system/display-manager.service

mkdir -p build_env/airootfs/etc/sddm.conf.d
cat <<EOF > build_env/airootfs/etc/sddm.conf.d/autologin.conf
[Autologin]
User=avelon
Session=hyprland
Relogin=false
[Theme]
Current=maldives
EOF

# Profiledef
cat <<EOF > build_env/profiledef.sh
#!/usr/bin/env bash
iso_name="avelon-os"
iso_label="AVELON_\$(date +%Y%m)"
iso_publisher="Avelon Team"
iso_application="Avelon OS Installer"
iso_version="\$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-ia32.grub.esp' 'uefi-x64.grub.esp'
           'uefi-ia32.grub.eltorito' 'uefi-x64.grub.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/home/avelon"]="1000:1000:755"
  ["/etc/skel/.config/hypr/hyprland.conf"]="0:0:755"
  ["/etc/sudoers.d/avelon-nopasswd"]="0:0:440"
)
EOF

# 6. START DE BOUW
echo "--- 🔨 ISO wordt gebouwd... ---"
mkarchiso -v -w work -o out -C pacman.conf build_env/

echo "--- ✅ Klaar! Je ISO staat in de map 'out/' ---"