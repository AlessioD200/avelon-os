#!/bin/bash

# Avelon OS Build Script - V2 (Met User & SDDM Fix)
set -e

echo "--- 🚀 Avelon OS Builder V2 gestart ---"

# 1. Check Root
if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Draai dit script als root (sudo ./build.sh)"
  exit
fi

# 2. Schoonmaak (Cruciaal voor nieuwe poging)
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

# 5. Permissies goed zetten
chmod +x build_env/airootfs/etc/skel/.config/hypr/*.conf 2>/dev/null || true

# --- DE FIX: Gebruiker & SDDM instellen ---
echo "--- 👤 Gebruiker 'avelon' aanmaken en SDDM activeren... ---"

# We gebruiken 'arch-chroot' om commando's IN de nieuwe ISO uit te voeren
# Dit zorgt dat de gebruiker en service echt bestaan in het systeem.
arch-chroot build_env <<EOF
    # 1. Maak gebruiker aan
    useradd -m -G wheel -s /bin/bash avelon
    
    # 2. Zet wachtwoord op 'avelon' (zodat je kan inloggen)
    echo "avelon:avelon" | chpasswd
    
    # 3. Geef sudo rechten (optioneel, handig voor testen)
    echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
    
    # 4. Activeer het inlogscherm
    systemctl enable sddm
EOF
# ------------------------------------------

# 6. Bouwen maar!
echo "--- 🔨 ISO wordt gebouwd... ---"
mkarchiso -v -w work -o out build_env/

echo "--- ✅ Klaar! Je ISO staat in de map 'out/' ---"
echo "--- 👉 Log straks in met gebruiker: 'avelon' en wachtwoord: 'avelon' ---"