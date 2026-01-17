#!/bin/bash
# Avelon OS Build Script - V5 (Calamares Edition)
set -e

echo "--- 🚀 Avelon OS Builder V5 gestart ---"

if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Draai dit script als root (sudo ./build.sh)"
  exit
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
# KOPIEER ONZE NIEUWE PACMAN.CONF
cp pacman.conf build_env/

# 4. Fix permissies en User
chmod +x build_env/airootfs/etc/skel/.config/hypr/*.conf 2>/dev/null || true

# --- User & SDDM Config ---
mkdir -p build_env/airootfs/home/avelon
cp -r build_env/airootfs/etc/skel/. build_env/airootfs/home/avelon/

mkdir -p build_env/airootfs/usr/lib/sysusers.d
cat <<EOF > build_env/airootfs/usr/lib/sysusers.d/avelon.conf
u avelon 1000 "Avelon User" /home/avelon /bin/bash
m avelon wheel
m avelon video
EOF

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

cat <<EOF > build_env/profiledef.sh
#!/usr/bin/env bash
iso_name="avelon-os"
iso_label="AVELON_\$(date +%Y%m)"
iso_publisher="Avelon Team"
iso_application="Avelon OS Live"
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
)
EOF

# 5. START DE BOUW (Met de nieuwe pacman.conf)
echo "--- 🔨 ISO wordt gebouwd... ---"
mkarchiso -v -w work -o out -C pacman.conf build_env/

echo "--- ✅ Klaar! Je ISO staat in de map 'out/' ---"