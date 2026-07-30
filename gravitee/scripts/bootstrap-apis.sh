#!/bin/bash
# Crée et déploie sur Gravitee les APIs proxy vers la stack LLM (LLM + OCR).
# Idempotent : une API déjà existante (même nom) est ignorée.
# Cible le Gravitee local par défaut ; pour le Gravitee hosté de l'entreprise,
# renseigner MGMT_API_URL + MGMT_API_TOKEN dans gravitee/.env.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/../.env" ] && set -a && source "$SCRIPT_DIR/../.env" && set +a

MGMT_API_URL="${MGMT_API_URL:-http://localhost:8083}"
MGMT_API_USER="${MGMT_API_USER:-admin}"
MGMT_API_PASSWORD="${MGMT_API_PASSWORD:-admin}"
MGMT_API_TOKEN="${MGMT_API_TOKEN:-}"
LLM_BACKEND_TARGET="${LLM_BACKEND_TARGET:-http://ollama:11434}"
OCR_BACKEND_TARGET="${OCR_BACKEND_TARGET:-http://paddleocr-vl-api:8080}"
LLM_API_PATH="${LLM_API_PATH:-/llm}"
OCR_API_PATH="${OCR_API_PATH:-/ocr}"

BASE="$MGMT_API_URL/management/v2/organizations/DEFAULT/environments/DEFAULT"

if [ -n "$MGMT_API_TOKEN" ]; then
    AUTH=(-H "Authorization: Bearer $MGMT_API_TOKEN")
else
    AUTH=(-u "$MGMT_API_USER:$MGMT_API_PASSWORD")
fi

req() {
    local method="$1" path="$2" body="${3:-}"
    local args=(-sf -X "$method" "${AUTH[@]}" -H "Content-Type: application/json;charset=UTF-8")
    [ -n "$body" ] && args+=(-d "$body")
    curl "${args[@]}" "$BASE$path"
}

extract_id() {
    grep -o '"id" *: *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/'
}

wait_for_mgmt_api() {
    echo "Attente du Management API ($MGMT_API_URL)..."
    for _ in $(seq 1 60); do
        if curl -sf "${AUTH[@]}" "$BASE/apis?page=1&perPage=1" > /dev/null 2>&1; then
            echo "Management API disponible."
            return 0
        fi
        sleep 5
    done
    echo "ERREUR : Management API injoignable après 5 min." >&2
    exit 1
}

create_api() {
    local name="$1" context_path="$2" target="$3" read_timeout="$4"

    if req GET "/apis?page=1&perPage=200" | grep -q "\"name\" *: *\"$name\""; then
        echo "API '$name' déjà présente — ignorée."
        return 0
    fi

    echo "Création de l'API '$name' ($context_path -> $target)..."
    local api_id
    api_id=$(req POST "/apis" "{
        \"name\": \"$name\",
        \"apiVersion\": \"1.0.0\",
        \"definitionVersion\": \"V4\",
        \"type\": \"PROXY\",
        \"description\": \"Proxy vers $target (géré par bootstrap-apis.sh)\",
        \"listeners\": [{
            \"type\": \"HTTP\",
            \"paths\": [{\"path\": \"$context_path\"}],
            \"entrypoints\": [{\"type\": \"http-proxy\"}]
        }],
        \"endpointGroups\": [{
            \"name\": \"default-group\",
            \"type\": \"http-proxy\",
            \"sharedConfiguration\": {
                \"http\": {
                    \"keepAlive\": true,
                    \"connectTimeout\": 30000,
                    \"readTimeout\": $read_timeout,
                    \"idleTimeout\": 60000
                }
            },
            \"endpoints\": [{
                \"name\": \"default\",
                \"type\": \"http-proxy\",
                \"weight\": 1,
                \"inheritConfiguration\": false,
                \"configuration\": {\"target\": \"$target\"}
            }]
        }]
    }" | extract_id)
    [ -n "$api_id" ] || { echo "ERREUR : création de '$name' échouée." >&2; exit 1; }

    local plan_id
    plan_id=$(req POST "/apis/$api_id/plans" \
        '{"definitionVersion":"V4","name":"Keyless","description":"Accès interne sans clé (auth gérée par Caddy en amont)","security":{"type":"KEY_LESS"},"mode":"STANDARD"}' \
        | extract_id)
    [ -n "$plan_id" ] || { echo "ERREUR : création du plan pour '$name' échouée." >&2; exit 1; }

    req POST "/apis/$api_id/plans/$plan_id/_publish" > /dev/null
    req POST "/apis/$api_id/_start" > /dev/null
    echo "API '$name' créée, plan publié, démarrée et déployée sur la gateway."
}

wait_for_mgmt_api
create_api "LLM Proxy" "$LLM_API_PATH" "$LLM_BACKEND_TARGET" 600000
create_api "OCR Proxy" "$OCR_API_PATH" "$OCR_BACKEND_TARGET" 300000
echo "Bootstrap terminé."
