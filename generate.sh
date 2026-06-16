#!/bin/bash
# ================================================
#  generate.sh — Génère les patches et copie les fichiers custom
#  À lancer après avoir mis à jour tes fichiers dans /opt/ptero-addons/files/
# ================================================
set -e

PANEL="/var/www/vhosts/adkynet.com/panel.adkynet.com/"
ADDONS="/opt/pterodactyl-addons"
PATCHES="$ADDONS/patches"
FILES="$ADDONS/files"
CUSTOM="$ADDONS/custom"

echo "======================================"
echo "  Génération des patches Ptero-Addons"
echo "======================================"

if [ ! -d "$FILES" ] || [ -z "$(find "$FILES" -type f 2>/dev/null)" ]; then
    echo ""
    echo "⚠️  Aucun fichier trouvé dans $FILES"
    echo "    Place tes fichiers modifiés/custom dans ce dossier en respectant"
    echo "    l'arborescence du panel. Exemple :"
    echo "    $FILES/app/Http/Controllers/MonController.php"
    exit 1
fi

mkdir -p "$PATCHES"
mkdir -p "$CUSTOM"
rm -f "$PATCHES"/*.patch
rm -rf "$CUSTOM"/*

echo ""
PATCH_COUNT=0
CUSTOM_COUNT=0
WARN_COUNT=0

find "$FILES" -type f | sort | while read -r modified_file; do

    relative="${modified_file#$FILES/}"
    original="$PANEL/$relative"

    if [ ! -f "$original" ]; then
        # Fichier custom : n'existe pas dans le panel officiel → on le copie
        dest="$CUSTOM/$relative"
        mkdir -p "$(dirname "$dest")"
        cp "$modified_file" "$dest"
        echo "  [CUSTOM]  $relative"
        CUSTOM_COUNT=$((CUSTOM_COUNT + 1))
    else
        patch_name=$(echo "$relative" | tr '/' '-').patch
        diff -u "$original" "$modified_file" \
            --label "a/$relative" \
            --label "b/$relative" \
            > "$PATCHES/$patch_name" || true

        if [ -s "$PATCHES/$patch_name" ]; then
            echo "  [PATCH]   $relative"
            PATCH_COUNT=$((PATCH_COUNT + 1))
        else
            # Fichier identique à l'original → inutile
            rm -f "$PATCHES/$patch_name"
            echo "  [SKIP]    $relative  ← identique à l'original, ignoré"
            WARN_COUNT=$((WARN_COUNT + 1))
        fi
    fi

done

echo ""
echo "======================================"
echo "  Résumé :"
echo "  🩹 Patches  : $PATCHES"
echo "  📁 Custom   : $CUSTOM"
echo ""
echo "  Lance apply.sh après ta prochaine MAJ Pterodactyl."
echo "======================================"
