#!/bin/bash

# Script de lancement rapide pour LLM Provider
# Ce script s'assure que vous êtes dans le bon répertoire

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "   LLM Provider - Lancement rapide"
echo "============================================"
echo ""
echo "Répertoire du script: $SCRIPT_DIR"
echo "Répertoire actuel: $(pwd)"
echo ""

# Aller dans le bon répertoire
cd "$SCRIPT_DIR"

echo "Navigation vers: $SCRIPT_DIR"
echo ""

# Vérifier que le Makefile existe
if [ ! -f "Makefile" ]; then
    echo "ERREUR: Makefile non trouvé dans $SCRIPT_DIR"
    exit 1
fi

echo "Makefile trouvé ✓"
echo ""
echo "Lancement du service..."
echo ""

# Lancer make start
make start
