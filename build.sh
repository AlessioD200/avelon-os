#!/bin/bash
# Avelon OS Build Script - V3 (Auto-Config Methode)
set -e

echo "--- 🚀 Avelon OS Builder V3 gestart ---"

# 1. Check Root
if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Draai dit script als root (sudo ./build.sh)"
  exit
fi

# 2. Schoonmaak
echo "--- 🧹 Oude bestanden opruimen... ---"
rm -rf work out build_env
mkdir -p work out build_env

# 3. Basis kopiëren
echo "--- 📦 Basis bestanden kopiëren... ---"
cp -r /usr/share/archiso/configs/releng/* build_env/

# 4. Avelon Configs toepassen
echo "--- 🎨 Configs en Packages kopiëren... ---"
cp -r airootfs build_env/
cp packages.x86_64 build_env/
cp profiledef.sh build_env/

# 5. Fix permissies voor Hyprland
chmod +x build_env/airootfs/etc/skel/.config/hypr/*.conf 2>/dev/null || true

# --- DE FIX: Automatische Configuraties aanmaken ---
echo "--- ⚙️  Systeem configureren (User & SDDM)... ---"

# A. Maak de gebruiker 'avelon' aan (via systemd-sysusers)
mkdir -p build_env/airootfs/usr/lib/sysusers.d
cat <<EOF > build_env/airootfs/usr/lib/sysusers.d/avelon.conf
u avelon - "Avelon Live User" /home/avelon /bin/bash
m avelon wheel
m avelon video
EOF

# B. Activeer SDDM (Het inlogscherm) via een symlink
mkdir -p build_env/airootfs/etc/systemd/system/
ln -sf /usr/lib/systemd/system/sddm.service build_env/airootfs/etc/systemd/system/display-manager.service

# C. Zet Auto-Login aan (zodat je geen wachtwoord nodig hebt)
mkdir -p build_env/airootfs/etc/sddm.conf.d
cat <<EOF > build_env/airootfs/etc/sddm.conf.d/autologin.conf
[Autologin]
User=avelon
Session=hyprland
EOF

# ---------------------------------------------------

# 6. Bouwen maar!
echo "--- 🔨 ISO wordt gebouwd... ---"
mkarchiso -v -w work -o out build_env/

echo "--- ✅ Klaar! Je ISO staat in de map 'out/' ---"