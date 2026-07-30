# Gravitee AI Gateway

Stack Gravitee APIM **indépendante** de la stack LLM (projet compose séparé `gravitee-apim`),
placée en coupure devant Ollama et PaddleOCR : tout le trafic LLM/OCR passe par la gateway.

## ⚠️ Fonctionnalités IA et licence (état vérifié le 2026-07-29, APIM 4.12)

Les fonctionnalités IA de Gravitee (**AI Agent Management / Agent Mesh**) exigent une
**licence Enterprise** — elles ne sont **pas disponibles en Community Edition** :

- LLM Proxy (wizard de création d'API type LLM, traduction OpenAI ↔ providers) : **EE**
- Token Rate Limit, guardrails, semantic caching, model routing, MCP/A2A proxy : **EE**
- Sources : [Proxy your LLMs](https://documentation.gravitee.io/apim/agent-mesh/llm-proxy/proxy-your-llms)
  (prérequis « An Enterprise License »), [Enterprise Edition](https://documentation.gravitee.io/apim/readme/enterprise-edition)
  (section « AI Agent Management »).

Ce qui reste possible en CE : proxy HTTP v4 classique devant Ollama (routage, plans
keyless/API key, analytics, rate limiting standard) — c'est ce que met en place
`scripts/bootstrap-apis.sh`.

**Débloquer les features IA en local** : l'image Docker est identique CE/EE depuis APIM 4.x.
Déposer la licence de l'entreprise dans `gravitee/license.key` (gitignoré) et redémarrer :
les entrées AI Agent Management apparaissent dans la console. Demander une clé de
dev/test au TAM Gravitee de l'entreprise (elle paie déjà une licence).

## Démarrage

```bash
make start              # stack LLM (crée le réseau llm-provider-network)
make gravitee-start     # MongoDB + Elasticsearch + gateway + management API + console
make gravitee-bootstrap # crée et déploie les APIs "LLM Proxy" (/llm) et "OCR Proxy" (/ocr)
```

- Gateway : `http://localhost:8082` — Console : `http://localhost:8084` (admin/admin)
- Portail développeur (optionnel) : `docker compose --profile portal up -d` dans `gravitee/`
- Test : `curl http://localhost:8082/llm/api/tags` (liste des modèles Ollama via la gateway)

## Flux

```
Open WebUI ──OLLAMA_BASE_URL──▶ gravitee-gateway:8082/llm ──▶ ollama:11434
Caddy api.{DOMAIN} ──rewrite /llm──▶ gravitee-gateway:8082 ──▶ ollama:11434
Caddy ocr.{DOMAIN} ──rewrite /ocr──▶ gravitee-gateway:8082 ──▶ paddleocr-vl-api:8080
```

La gateway rejoint le réseau externe `llm-provider-network` pour atteindre les backends ;
le reste de la stack Gravitee vit sur son propre réseau `gravitee-network`.

## Migration vers le Gravitee Enterprise hosté

Aucun changement de code — uniquement des variables :

| Où | Variable | Local (défaut) | Hosté |
|---|---|---|---|
| `.env` racine | `LLM_GATEWAY_URL` | `http://gravitee-gateway:8082/llm` | `https://gw.entreprise.com/llm` |
| `.env` racine | `LLM_GATEWAY_UPSTREAM` | `gravitee-gateway:8082` | `https://gw.entreprise.com` |
| `gravitee/.env` | `MGMT_API_URL` + `MGMT_API_TOKEN` | mgmt API local (admin/admin) | mgmt API hosté + PAT |
| Cloud (TF) | `TF_VAR_llm_gateway_url` / `_upstream` | — | idem hosté |

Puis rejouer `gravitee/scripts/bootstrap-apis.sh` (avec `LLM_BACKEND_TARGET` pointant sur
l'URL publique de la stack, ex. `https://api.sahlu.dev`) pour recréer les mêmes APIs sur
l'environnement hosté, et arrêter la stack locale (`make gravitee-stop`) — elle n'est plus
nécessaire, c'est tout l'intérêt de son isolation.

## Fichiers

- `docker-compose.yml` — stack APIM (versions et ports pilotés par variables, cf. `.env.example`)
- `scripts/start.sh` — vérifie le réseau, crée `license.key` vide si absent, `up -d`
- `scripts/bootstrap-apis.sh` — création idempotente des APIs v4 proxy + plan keyless,
  publication, démarrage, déploiement (Management API v2, basic auth ou PAT)
- `license.key` — vide = CE ; licence entreprise = EE + features IA (gitignoré)
- `data/` — données MongoDB/Elasticsearch/logs (gitignoré)
