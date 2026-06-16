#!/bin/bash
# ================================================
#  apply.sh — Réapplique tous les addons après MAJ
#  À lancer après chaque mise à jour de Pterodactyl
# ================================================

PANEL="/var/www/vhosts/adkynet.com/panel.adkynet.com/"
ADDONS="/opt/pterodactyl-addons"
FAILED=0
PATCH_OK=0
PATCH_FAIL=0

echo "======================================"
echo "  Application des addons Ptero-Addons"
echo "======================================"

# --- Vérifications ---
if [ ! -d "$PANEL" ]; then
    echo "❌ Dossier panel introuvable : $PANEL"
    exit 1
fi

if [ ! -d "$ADDONS" ]; then
    echo "❌ Dossier addons introuvable : $ADDONS"
    exit 1
fi

# --- Maintenance ---
echo ""
echo "==> Mise en maintenance..."
php "$PANEL/artisan" down

# --- Patches ---
if [ -d "$ADDONS/patches" ] && [ "$(ls -A "$ADDONS/patches/"*.patch 2>/dev/null)" ]; then
    echo ""
    echo "==> Application des patches..."
    for patch in "$ADDONS/patches/"*.patch; do
        name=$(basename "$patch")
        echo "  -> $name"

        # Test à blanc avant d'appliquer
        if patch -p1 --dry-run -d "$PANEL" < "$patch" > /dev/null 2>&1; then
            patch -p1 -d "$PANEL" < "$patch" > /dev/null
            echo "     ✅ OK"
            PATCH_OK=$((PATCH_OK + 1))
        else
            echo "     ❌ CONFLIT — patch non appliqué"
            echo "        Fichier concerné : $patch"
            PATCH_FAIL=$((PATCH_FAIL + 1))
            FAILED=1
        fi
    done
    echo ""
    echo "  Résultat patches : ✅ $PATCH_OK OK  /  ❌ $PATCH_FAIL en échec"
else
    echo ""
    echo "==> Aucun patch trouvé, étape ignorée."
fi

cd "$PANEL"

# --- Addons ainx ---
if [ -d "$ADDONS/ainx" ] && [ "$(ls -A "$ADDONS/ainx/"*.ainx 2>/dev/null)" ]; then
    echo ""
    echo "==> Installation des addons ainx..."
    for file in "$ADDONS/ainx/"*.ainx; do
        echo "  -> $(basename "$file")"
        
        if ainx install "$file" --force; then
            echo "     ✅ OK"
        else
            echo "     ❌ Échec de l'installation ainx"
            FAILED=1
        fi
    done
else
    echo ""
    echo "==> Aucun addon ainx trouvé, étape ignorée."
fi

# --- Rebuild assets ---
echo ""
echo "==> Rebuild des assets..."
if yarn build:production; then
    echo "  ✅ Build OK"
else
    echo "  ⚠️  Build échoué (peut être ignoré si pas de modif JS/CSS)"
fi

# --- Nettoyage cache ---
echo ""
echo "==> Nettoyage du cache..."
php artisan view:clear
php artisan cache:clear
php artisan config:clear
echo "  ✅ Cache nettoyé"

# --- Fin maintenance ---
echo ""
echo "==> Fin de la maintenance..."
php "$PANEL/artisan" up

# --- Rapport final ---
echo ""
echo "======================================"
if [ $FAILED -eq 1 ]; then
    echo "⚠️  Application terminée AVEC DES ERREURS"
    echo ""
    echo "  👉 Pour chaque patch en conflit :"
    echo "     1. Ouvre le fichier concerné dans $PANEL"
    echo "     2. Réapplique ta modification manuellement"
    echo "     3. Relance : generate.sh pour mettre à jour le patch"
else
    echo "✅ Tous les addons ont été appliqués avec succès !"
fi
echo "======================================"
