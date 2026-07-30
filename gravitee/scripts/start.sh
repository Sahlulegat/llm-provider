#!/bin/bash
# Démarre la stack Gravitee APIM (indépendante de la stack LLM).
set -euo pipefail

GRAVITEE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$GRAVITEE_DIR"

NETWORK="${LLM_STACK_NETWORK:-llm-provider-network}"
if ! docker network inspect "$NETWORK" > /dev/null 2>&1; then
    echo "ERREUR : le réseau docker '$NETWORK' n'existe pas."
    echo "Démarrer d'abord la stack LLM : make start (à la racine du repo)."
    exit 1
fi

# license.key vide = Community Edition ; y déposer la licence entreprise pour l'EE
if [ ! -f license.key ]; then
    touch license.key
    echo "license.key vide créé (mode Community Edition)."
fi

docker compose up -d
echo ""
echo "Gravitee APIM démarré :"
echo "  Gateway : http://localhost:${GRAVITEE_GATEWAY_PORT:-8082}"
echo "  Console : http://localhost:${GRAVITEE_CONSOLE_PORT:-8084} (admin/admin)"
echo ""
echo "Prochaine étape : ./scripts/bootstrap-apis.sh (crée les APIs LLM/OCR)"
