#!/bin/bash
# Avelon OS Build Script - Final Version
set -e

echo "--- 🚀 Avelon OS Builder gestart ---"

if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Draai dit script als root (sudo ./build.sh)"
  exit 1
fi

# 1. Schoonmaak
echo "--- 🧹 Oude bestanden opruimen... ---"
rm -rf work out build_env
mkdir -p work out build_env

# 2. Basis kopiëren (Releng profiel)
echo "--- 📦 Basis bestanden kopiëren... ---"
cp -r /usr/share/archiso/configs/releng/* build_env/

# 3. Avelon Configs toepassen
echo "--- 🎨 Configs en Packages kopiëren... ---"
# Kopieer jouw airootfs (met Calamares settings, Hyprland configs, etc.)
cp -r airootfs build_env/
cp packages.x86_64 build_env/
# Kopieer de pacman.conf (met EndeavourOS repo)
cp pacman.conf build_env/

# 4. Check of Calamares bestanden bestaan (Veiligheidscheck)
if [ ! -d "build_env/airootfs/etc/calamares" ]; then
    echo "❌ FOUT: Calamares configs ontbreken in build_env!"
    exit 1
fi

# 5. Fix permissies voor scripts en configs
chmod +x build_env/airootfs/etc/skel/.config/hypr/*.conf 2>/dev/null || true

# --- User & SDDM Config ---
# Dit zorgt dat je automatisch inlogt in de LIVE omgeving om Calamares te kunnen starten
echo "--- 👤 Live Gebruiker instellen... ---"

# Home map maken
mkdir -p build_env/airootfs/home/avelon
cp -r build_env/airootfs/etc/skel/. build_env/airootfs/home/avelon/

# Gebruiker aanmaken
mkdir -p build_env/airootfs/usr/lib/sysusers.d
cat <<EOF > build_env/airootfs/usr/lib/sysusers.d/avelon.conf
u avelon 1000 "Avelon User" /home/avelon /bin/bash
m avelon wheel
m avelon video
EOF

# SDDM activeren
mkdir -p build_env/airootfs/etc/systemd/system/
ln -sf /usr/lib/systemd/system/sddm.service build_env/airootfs/etc/systemd/system/display-manager.service

# Auto-Login instellen
mkdir -p build_env/airootfs/etc/sddm.conf.d
cat <<EOF > build_env/airootfs/etc/sddm.conf.d/autologin.conf
[Autologin]
User=avelon
Session=hyprland
Relogin=false
[Theme]
Current=maldives
EOF

# Profiledef updaten (Permissies)
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
)
EOF

# 6. START DE BOUW
echo "--- 🔨 ISO wordt gebouwd... ---"
# We gebruiken -C pacman.conf zodat hij de EndeavourOS repo gebruikt
mkarchiso -v -w work -o out -C pacman.conf build_env/

echo "--- ✅ Klaar! Je ISO staat in de map 'out/' ---"