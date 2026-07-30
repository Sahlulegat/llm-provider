# Gravitee AI Gateway — Documentation de référence

Documentation complète de l'intégration Gravitee APIM dans la stack llm-provider.
Pour un démarrage rapide, voir le [README](README.md) ; pour des pas-à-pas, voir [TUTORIALS.md](TUTORIALS.md).

## 1. Pourquoi Gravitee, et pourquoi une stack séparée

Objectif : tester les fonctionnalités **gateway IA** de Gravitee (LLM proxy, token rate
limit, guardrails…) en local, puis basculer sans friction vers le **Gravitee Enterprise
hosté** que l'entreprise paie déjà.

Deux contraintes de conception en découlent :

1. **Gravitee est volontairement indépendant de la stack LLM** : projet compose séparé
   (`gravitee-apim`), réseau propre (`gravitee-network`), cycle de vie propre
   (`make gravitee-*`). Seule la gateway rejoint le réseau `llm-provider-network` pour
   atteindre les backends. Le jour de la migration, on éteint cette stack et il ne reste
   rien d'elle dans la stack LLM — que des URLs dans des variables.
2. **La stack LLM ne connaît Gravitee que par variables d'environnement**
   (`LLM_GATEWAY_*`, `OCR_GATEWAY_*`) : locale ou hostée, c'est le même code.

## 2. Ce qui change par rapport à l'ancien fonctionnement

### Avant

```
Open WebUI ──────────────────────────▶ ollama:11434
Caddy api.{DOMAIN} ──────────────────▶ ollama:11434
Caddy ocr.{DOMAIN} ──────────────────▶ paddleocr-vl-api:8080
```

### Après

```
Open WebUI ──OLLAMA_BASE_URL──▶ gravitee-gateway:8082/llm ──▶ ollama:11434
Caddy api.{DOMAIN} ──rewrite /llm──▶ gravitee-gateway:8082 ──▶ ollama:11434
Caddy ocr.{DOMAIN} ──rewrite /ocr──▶ gravitee-gateway:8082 ──▶ paddleocr-vl-api:8080
```

### Tableau des changements

| Composant | Avant | Après | Fichier |
|---|---|---|---|
| Open WebUI | `OLLAMA_BASE_URL=http://ollama:11434` | `${LLM_GATEWAY_URL:-http://gravitee-gateway:8082/llm}` | `docker-compose.yml` |
| Caddy `api.*` | `reverse_proxy ollama:11434` | `rewrite /llm{uri}` + `reverse_proxy {$LLM_GATEWAY_UPSTREAM}` | `Caddyfile` |
| Caddy `ocr.*` | `reverse_proxy paddleocr-vl-api:8080` | `rewrite /ocr{uri}` + `reverse_proxy {$OCR_GATEWAY_UPSTREAM}` | `Caddyfile` |
| Makefile | — | cibles `gravitee-start/stop/status/logs/bootstrap` | `Makefile` |
| Terraform | — | `TF_VAR_llm_gateway_*` / `TF_VAR_ocr_gateway_upstream` propagées jusqu'au `.env` serveur | `variables.tf`, `main.tf`, `cloud-init.yml` |

### Ce qui ne change PAS

- **Les URLs et chemins vus de l'extérieur** : `api.{DOMAIN}/api/chat` fonctionne comme
  avant — le `rewrite` Caddy ajoute le context path Gravitee (`/llm`), et Gravitee le
  retire avant d'appeler Ollama. Aucun client existant à modifier.
- **L'authentification `X-API-Key` de Caddy** : toujours exigée sur toutes les routes
  publiques, en amont de la gateway. Les plans Gravitee sont keyless en interne (l'auth
  applicative reste du ressort de Caddy tant qu'on est en CE).
- La chaîne CrowdSec, le TLS au load balancer, l'auto-shutdown, PaddleOCR (profil
  `paddle`), le déploiement Terraform.

### Nouvelle conséquence à connaître

La gateway devient un **point de passage obligé** : si la stack Gravitee est arrêtée, le
trafic LLM/OCR tombe (c'est voulu — « tout passe forcément par Gravitee »). Bypass
d'urgence sans toucher au code, dans le `.env` racine :

```bash
LLM_GATEWAY_URL=http://ollama:11434
LLM_GATEWAY_UPSTREAM=ollama:11434
OCR_GATEWAY_UPSTREAM=paddleocr-vl-api:8080
LLM_GATEWAY_PATH=
OCR_GATEWAY_PATH=
```

(un chemin **explicitement vide** désactive le rewrite Caddy — syntaxe `${VAR-def}` dans
le compose), puis `docker compose up -d open-webui caddy`.

## 3. Composants de la stack Gravitee

| Service | Image | Port hôte | Rôle |
|---|---|---|---|
| `gateway` | `graviteeio/apim-gateway` | 8082 | Data plane — proxifie le trafic des APIs déployées |
| `management-api` | `graviteeio/apim-management-api` | 8083 | Control plane — API REST de configuration |
| `management-ui` | `graviteeio/apim-management-ui` | 8084 | Console web (admin/admin) |
| `portal-ui` (profil `portal`) | `graviteeio/apim-portal-ui` | 8085 | Portail développeur, optionnel |
| `mongodb` | `mongo:7.0` | — | Définitions d'APIs, plans, users |
| `elasticsearch` | `elasticsearch:8.16.1` | — | Analytics et logs de la gateway |

Versions et ports surchargeables dans `gravitee/.env` (cf. [.env.example](.env.example)).
Données persistées dans `gravitee/data/` (gitignoré) — `rm -rf gravitee/data` = reset complet.

Réseaux : tout le monde sur `gravitee-network` ; la gateway rejoint **en plus**
`llm-provider-network` (déclaré `external` : la stack LLM doit être démarrée d'abord).

## 4. APIs créées par le bootstrap

`scripts/bootstrap-apis.sh` (idempotent, rejouable) crée via le Management API v2 :

| API | Context path | Backend | readTimeout |
|---|---|---|---|
| LLM Proxy | `/llm` | `http://ollama:11434` | 600 s |
| OCR Proxy | `/ocr` | `http://paddleocr-vl-api:8080` | 300 s |

Chacune : API **v4 http-proxy**, plan **keyless** publié, API démarrée et déployée.
Séquence rejouée par le script : `POST /apis` → `POST /apis/{id}/plans` →
`POST …/_publish` → `POST …/_start` (base
`/management/v2/organizations/DEFAULT/environments/DEFAULT`).

Le script cible n'importe quel Gravitee (local par défaut, hosté via `MGMT_API_URL` +
`MGMT_API_TOKEN` dans `gravitee/.env`) — c'est le même outil qui provisionne les deux.

## 5. Variables — référence complète

### `.env` racine (consommé par la stack LLM)

| Variable | Défaut | Rôle |
|---|---|---|
| `LLM_GATEWAY_URL` | `http://gravitee-gateway:8082/llm` | Base URL Ollama vue par Open WebUI |
| `LLM_GATEWAY_UPSTREAM` | `gravitee-gateway:8082` | Upstream Caddy route `api.*` |
| `OCR_GATEWAY_UPSTREAM` | `gravitee-gateway:8082` | Upstream Caddy route `ocr.*` |
| `LLM_GATEWAY_PATH` | `/llm` | Préfixe réécrit par Caddy (vide = pas de rewrite) |
| `OCR_GATEWAY_PATH` | `/ocr` | Préfixe réécrit par Caddy (vide = pas de rewrite) |

### `gravitee/.env` (stack Gravitee + bootstrap)

| Variable | Défaut | Rôle |
|---|---|---|
| `APIM_VERSION` | `4.12` | Version des 4 images APIM |
| `GRAVITEE_GATEWAY_PORT` / `_MGMT_API_PORT` / `_CONSOLE_PORT` / `_PORTAL_PORT` | 8082/8083/8084/8085 | Ports hôte |
| `LLM_STACK_NETWORK` | `llm-provider-network` | Réseau externe à rejoindre |
| `MGMT_API_URL` | `http://localhost:8083` | Cible du bootstrap |
| `MGMT_API_USER` / `MGMT_API_PASSWORD` | `admin`/`admin` | Auth basic (local) |
| `MGMT_API_TOKEN` | — | PAT, prioritaire (requis sur le hosté) |
| `LLM_BACKEND_TARGET` / `OCR_BACKEND_TARGET` | conteneurs locaux | Backends des APIs créées |
| `LLM_API_PATH` / `OCR_API_PATH` | `/llm` / `/ocr` | Context paths des APIs |

### Cloud (`.env` TF → `TF_VAR_*`)

`TF_VAR_llm_gateway_url`, `TF_VAR_llm_gateway_upstream`, `TF_VAR_ocr_gateway_upstream`,
`TF_VAR_llm_gateway_path`, `TF_VAR_ocr_gateway_path` — mêmes sémantiques, propagées par
`variables.tf` → `main.tf` (templatefile) → `cloud-init.yml` → `.env` du serveur.
Vides par défaut : le serveur cloud n'ayant pas de Gravitee local, **il faut** y mettre
l'URL du Gravitee hosté (cf. tuto migration).

## 6. Licence : Community vs Enterprise (vérifié sur APIM 4.12, 2026-07)

| Fonctionnalité | CE | EE |
|---|---|---|
| Proxy HTTP v4 devant Ollama (ce que fait le bootstrap) | ✅ | ✅ |
| Plans keyless / API key, Policy Studio, analytics, rate limit standard | ✅ | ✅ |
| **Wizard LLM Proxy** (traduction OpenAI ↔ Gemini/Bedrock…) | ❌ | ✅ |
| **Token Rate Limit** (quota en tokens, pas en requêtes) | ❌ | ✅ |
| **Guardrails, semantic cache, model routing, MCP/A2A proxy** | ❌ | ✅ |

L'image Docker est identique CE/EE : la bascule se fait **uniquement** par le fichier
`gravitee/license.key` (vide = CE ; clé d'entreprise = EE). Sources :
[Proxy your LLMs](https://documentation.gravitee.io/apim/agent-mesh/llm-proxy/proxy-your-llms),
[Enterprise Edition](https://documentation.gravitee.io/apim/readme/enterprise-edition).

## 7. Exploitation

```bash
make gravitee-start       # démarre la stack (vérifie le réseau, crée license.key vide si absent)
make gravitee-bootstrap   # (re)crée les APIs — idempotent
make gravitee-status      # docker compose ps
make gravitee-logs        # logs de la gateway en continu
make gravitee-stop        # arrêt (les données restent dans gravitee/data/)
```

Compter ~2 min de démarrage (le Management API attend Elasticsearch). RAM totale de la
stack : ~3 Go (dont 512 Mo de heap Elasticsearch).

## 8. Dépannage

| Symptôme | Cause probable | Remède |
|---|---|---|
| `make gravitee-start` : « le réseau n'existe pas » | Stack LLM arrêtée | `make start` d'abord |
| `404` sur `http://localhost:8082/llm/...` | APIs non créées ou non déployées | `make gravitee-bootstrap`, puis Console → APIs → vérifier « Deployed » |
| `502` de la gateway | Backend down ou gateway pas sur `llm-provider-network` | `make status` ; `docker network inspect llm-provider-network` doit lister `gravitee-gateway` |
| Bootstrap : « Management API injoignable » | Control plane pas encore prêt (démarrage lent) | Attendre 1-2 min, relancer ; `docker logs gravitee-management-api` |
| Elasticsearch unhealthy | RAM insuffisante / vm.max_map_count trop bas (Linux) | `sysctl -w vm.max_map_count=262144` ; augmenter la RAM Docker |
| Console : pas de menu AI / wizard LLM Proxy absent | Licence CE | Déposer la licence EE dans `license.key`, `make gravitee-stop && make gravitee-start` |
| Réponses LLM tronquées à ~10 s | API recréée à la main sans timeouts | Le bootstrap fixe `readTimeout=600000` ; reporter cette valeur sur toute API créée en console |
| Open WebUI ne liste aucun modèle | Gateway down ou API `/llm` absente | `curl http://localhost:8082/llm/api/tags` pour isoler la panne |

## 9. Limites connues et choix assumés

- **Plans keyless** en interne : l'auth reste portée par Caddy (`X-API-Key`). Passer sur
  des plans API-key Gravitee est un chantier EE/hosté (les consommateurs devront alors
  envoyer une clé Gravitee).
- **Un seul point de sortie Caddy → gateway** : si le Gravitee hosté termine le TLS avec
  un certificat privé, ajouter la config `transport http { tls }` adéquate dans le
  Caddyfile.
- **Le bootstrap parse le JSON au `grep`** (pas de dépendance à `jq`) : suffisant pour
  ces deux APIs, à durcir si le provisioning devient plus riche (ou passer au
  [Terraform provider Gravitee](https://registry.terraform.io/providers/gravitee-io/apim/latest)).
- Le serveur cloud exécutant ce qui est **poussé sur GitHub**, la branche
  `feature/gravitee-ai-gateway` ne doit pas être déployée en l'état (elle n'est pas pushée).
