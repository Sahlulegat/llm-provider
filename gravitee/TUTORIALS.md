# Gravitee AI Gateway — Tutoriels

Pas-à-pas pratiques. Référence complète dans [DOCUMENTATION.md](DOCUMENTATION.md).

- [Tuto 1 — Démarrer et vérifier que tout passe par la gateway](#tuto-1)
- [Tuto 2 — Observer le trafic et ajouter une policy (CE)](#tuto-2)
- [Tuto 3 — Activer la licence Enterprise et tester les fonctionnalités IA](#tuto-3)
- [Tuto 4 — Migrer vers le Gravitee Enterprise hosté](#tuto-4)

---

<a id="tuto-1"></a>
## Tuto 1 — Démarrer et vérifier que tout passe par la gateway

**Objectif** : stack complète opérationnelle, preuve que le trafic LLM transite par Gravitee.
**Durée** : ~10 min (hors téléchargement des images).

### 1. Démarrer les deux stacks

```bash
make start
```

```bash
make gravitee-start
```

Attendre ~2 min que le control plane s'initialise, puis :

```bash
make gravitee-bootstrap
```

Sortie attendue : `API 'LLM Proxy' créée, plan publié, démarrée et déployée...` (idem OCR).
Rejouer la commande doit afficher `déjà présente — ignorée` (idempotence).

### 2. Tester la gateway en direct

Lister les modèles Ollama **via Gravitee** :

```bash
curl http://localhost:8082/llm/api/tags
```

Génération complète (adapter le nom du modèle à `MODEL_NAME` du `.env`) :

```bash
curl http://localhost:8082/llm/api/generate -d '{"model":"gpt-oss:120b","prompt":"Dis bonjour","stream":false}'
```

L'API OpenAI-compatible d'Ollama passe aussi :

```bash
curl http://localhost:8082/llm/v1/chat/completions -H "Content-Type: application/json" -d '{"model":"gpt-oss:120b","messages":[{"role":"user","content":"Dis bonjour"}]}'
```

### 3. Prouver que la gateway est bien en coupure

```bash
make gravitee-stop
```

Open WebUI ne liste plus aucun modèle et `curl http://localhost:8082/llm/api/tags`
échoue : plus rien ne passe sans Gravitee. Relancer :

```bash
make gravitee-start
```

### 4. Vérifier le chemin Caddy (si `DOMAIN_NAME` configuré)

```bash
curl -H "X-API-Key: $CADDY_API_KEY" http://api.localhost/api/tags
```

Le chemin public n'a pas changé (`/api/tags`, pas `/llm/api/tags`) : le rewrite Caddy
et le context path Gravitee s'annulent — les clients existants ne voient aucune différence.

---

<a id="tuto-2"></a>
## Tuto 2 — Observer le trafic et ajouter une policy (CE)

**Objectif** : prendre en main la console, activer les logs, poser un rate limit
classique — tout ce qui est déjà possible sans licence.

### 1. Explorer la console

Ouvrir `http://localhost:8084` (admin/admin) → **APIs** → **LLM Proxy** :

- **Info** : définition v4, context path `/llm`.
- **Backend services** : l'endpoint `http://ollama:11434` avec ses timeouts (600 s).
- **Plans** : le plan Keyless publié.
- **Analytics** : après quelques requêtes du Tuto 1, le trafic apparaît (latences, statuts).

### 2. Activer les logs détaillés

API **LLM Proxy** → **Analytics → Logs** → **Configure the Logging** : cocher
Entrypoint + Endpoint, mode Request/Response, sauvegarder, puis **Deploy API** (bandeau
orange). Chaque requête devient inspectable (headers, payloads) — précieux pour déboguer
les intégrations, à désactiver ensuite (coût en perfs/stockage).

### 3. Ajouter une policy Rate Limit (requêtes/seconde, dispo en CE)

1. API **LLM Proxy** → **Policies** (Policy Studio).
2. Sur le flow par défaut, phase **Request**, cliquer **+** → chercher **Rate Limit**.
3. Configurer par ex. `2` requêtes / `1` seconde, sauvegarder, **Deploy API**.
4. Vérifier :

```bash
for i in 1 2 3 4; do curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8082/llm/api/tags; done
```

Attendu : `200 200 429 429`. Supprimer ensuite la policy (ou la garder : elle protège
le GPU d'un client fou, mais compte en **requêtes**, pas en tokens — le comptage en
tokens est la version EE, cf. Tuto 3).

---

<a id="tuto-3"></a>
## Tuto 3 — Activer la licence Enterprise et tester les fonctionnalités IA

**Objectif** : débloquer le vrai périmètre « AI gateway » (LLM proxy natif, token rate
limit, guardrails) avec la licence de l'entreprise.
**Prérequis** : une clé de licence EE (demander une clé de dev/test au TAM Gravitee de
l'entreprise — elle paie déjà).

### 1. Installer la licence

```bash
cp /chemin/vers/license.key gravitee/license.key
```

```bash
make gravitee-stop && make gravitee-start
```

Vérifier dans les logs que la licence est chargée :

```bash
docker logs gravitee-gateway 2>&1 | grep -i license
```

### 2. Créer un LLM Proxy natif (wizard EE)

Console → **APIs** → **+ Add API** → **Create V4 API** : un type d'API **LLM Proxy**
apparaît (absent en CE). Le wizard demande :

- le **provider** (OpenAI API, Gemini, Bedrock, ou tout endpoint OpenAI-compatible) ;
- Ollama exposant une API OpenAI-compatible sur `/v1`, utiliser
  `http://ollama:11434/v1` comme endpoint OpenAI-compatible ;
- un context path, par ex. `/ai`.

Résultat : la gateway expose une API OpenAI-compatible avec traduction de format,
token tracking dans les analytics, et les policies IA activables dessus.

### 3. Token Rate Limit (quota en tokens)

API LLM Proxy (celle du wizard) → **Policies** → phase Request → **Token Rate Limit** :
définir un budget de tokens par consommateur et par fenêtre de temps. Tester en
enchaînant des prompts longs : la 429 tombe quand le budget de **tokens** (pas de
requêtes) est épuisé — c'est la différence clé avec le Rate Limit du Tuto 2.

### 4. Aller plus loin

Sur le même principe : **AI Prompt Guard Rails** (filtrage de prompts),
**semantic caching**, model routing multi-providers. Suivre
[la doc Agent Mesh](https://documentation.gravitee.io/apim/agent-mesh/llm-proxy) —
chaque page indique son niveau de licence.

> Note : notre API `/llm` du bootstrap (proxy HTTP brut) reste utile même en EE — Open
> WebUI parle le protocole Ollama natif (`/api/chat`…), que le wizard LLM Proxy ne
> traduit pas. Cible recommandée : `/llm` pour Open WebUI, `/ai` (LLM Proxy EE) pour les
> clients OpenAI-compatibles.

---

<a id="tuto-4"></a>
## Tuto 4 — Migrer vers le Gravitee Enterprise hosté

**Objectif** : basculer la stack (locale ou cloud) du Gravitee de test vers celui de
l'entreprise, **sans modifier le code** — uniquement des variables.

### 1. Recréer les APIs sur le Gravitee hosté

Le Gravitee hosté n'atteint pas `ollama:11434` (réseau Docker local) : les backends
doivent être les URLs **publiques** de la stack, et porter la clé Caddy.

Dans `gravitee/.env` :

```bash
MGMT_API_URL=https://mgmt.gravitee.entreprise.com
MGMT_API_TOKEN=<PAT généré dans la console hostée (Organization → Users → Tokens)>
LLM_BACKEND_TARGET=https://api.sahlu.dev
OCR_BACKEND_TARGET=https://ocr.sahlu.dev
```

Puis :

```bash
make gravitee-bootstrap
```

⚠️ **Auth backend** : les routes Caddy exigent `X-API-Key`. Sur les APIs créées côté
hosté, ajouter une policy **Transform Headers** (phase Request) qui pose
`X-API-Key: <CADDY_API_KEY>`, puis Deploy. Sans cela : 401 du Caddy. (Alternative :
whitelister les IPs de la gateway hostée dans `ALLOWED_IPS`.)

### 2. Basculer les consommateurs

`.env` racine (stack locale) ou `.env` TF (cloud) :

```bash
# local
LLM_GATEWAY_URL=https://gw.gravitee.entreprise.com/llm
LLM_GATEWAY_UPSTREAM=https://gw.gravitee.entreprise.com
OCR_GATEWAY_UPSTREAM=https://gw.gravitee.entreprise.com
```

```bash
# cloud (.env TF) — puis ./deploy.sh apply
TF_VAR_llm_gateway_url="https://gw.gravitee.entreprise.com/llm"
TF_VAR_llm_gateway_upstream="https://gw.gravitee.entreprise.com"
TF_VAR_ocr_gateway_upstream="https://gw.gravitee.entreprise.com"
```

Appliquer en local : `docker compose up -d open-webui caddy`.

### 3. Éteindre le Gravitee local

```bash
make gravitee-stop
```

C'est tout l'intérêt de la stack séparée : rien d'autre à nettoyer.

### 4. Checklist de validation

- [ ] `curl https://gw.gravitee.entreprise.com/llm/api/tags` répond (les modèles Ollama).
- [ ] Open WebUI liste les modèles et répond en chat.
- [ ] `api.{DOMAIN}` répond toujours avec le header `X-API-Key` habituel.
- [ ] Les analytics du trafic apparaissent dans la console hostée.
- [ ] Le Gravitee local est arrêté et plus rien ne le référence (`grep -r gravitee-gateway .env`).

### Rollback (retour au Gravitee local ou bypass complet)

Retour au local : remettre les valeurs par défaut (ou vider les variables) et
`make gravitee-start && make gravitee-bootstrap`. Bypass d'urgence sans gateway du tout :
cf. [DOCUMENTATION.md §2](DOCUMENTATION.md#2-ce-qui-change-par-rapport-à-lancien-fonctionnement).
