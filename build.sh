#!/bin/bash

# Avelon OS Build Script
# Dit script moet worden uitgevoerd op een Arch Linux systeem (of in een VM).

set -e # Stop direct als er iets fout gaat
u_name="avelon-user" # Tijdelijke gebruikersnaam voor in de build omgeving

echo "--- 🚀 Avelon OS Builder gestart ---"

# 1. Check of we als Root draaien (nodig voor het bouwen)
if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Draai dit script als root (gebruik sudo ./build.sh)"
  exit
fi

# 2. Check of archiso is geïnstalleerd
if ! command -v mkarchiso &> /dev/null; then
    echo "⚠️  Archiso is niet geïnstalleerd. Installeren..."
    pacman -Sy --noconfirm archiso
fi

# 3. Werkmap aanmaken
echo "--- 📁 Werkmappen voorbereiden... ---"
rm -rf work out build_env
mkdir -p work out build_env

# 4. Kopieer de basis Arch Linux bestanden (Releng profiel)
# Dit zorgt dat de bootloaders (GRUB/Syslinux) goed staan.
cp -r /usr/share/archiso/configs/releng/* build_env/

# 5. Voeg JOUW Avelon bestanden toe aan de build omgeving
echo "--- 🎨 Avelon OS configuratie toepassen... ---"
cp -r airootfs build_env/
cp packages.x86_64 build_env/
cp profiledef.sh build_env/

# 6. Permissies goed zetten voor scripts
chmod +x build_env/airootfs/etc/skel/.config/hypr/*.conf 2>/dev/null || true

# 7. De ISO bouwen!
echo "--- 🔨 ISO wordt gebouwd... (Dit kan even duren) ---"
mkarchiso -v -w work -o out build_env/

echo "--- ✅ Klaar! Je ISO staat in de map 'out/' ---"