#!/bin/bash
# Avelon OS Build Script - V9 (Conflict Fix)
set -e

echo "--- 🚀 Avelon OS Builder V9 gestart ---"

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

# 4. Veiligheidschecks
# We checken nu op de _fix bestandsnaam!
if [ ! -f "build_env/airootfs/etc/calamares/modules/unpackfs_fix.conf" ]; then
    echo "❌ FOUT: unpackfs_fix.conf ontbreekt! Heb je Stap 1 wel gedaan?"
    exit 1
fi

# 5. Fix permissies
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

# --- OPSTART SCRIPT (Wachtwoord + Calamares Fix) ---
# Hier gebeurt de magie: we zetten het wachtwoord EN we wisselen het config bestand om.
mkdir -p build_env/airootfs/etc/systemd/system/
cat <<EOF > build_env/airootfs/etc/systemd/system/setup-avelon.service
[Unit]
Description=Setup Avelon Environment
Before=sddm.service

[Service]
Type=oneshot
# 1. Zet wachtwoord op 'avelon'
# 2. Overschrijf de standaard unpackfs.conf met onze FIX versie
ExecStart=/bin/bash -c "echo 'avelon:avelon' | chpasswd; mv /etc/calamares/modules/unpackfs_fix.conf /etc/calamares/modules/unpackfs.conf"

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