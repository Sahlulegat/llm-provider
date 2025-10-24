# LLM Provider - Ollama Setup

Infrastructure-as-Code pour déployer un provider LLM basé sur Ollama avec le modèle GPT-OSS 120B.

## Interface Web Incluse!

Ce setup inclut **Open WebUI**, une interface web moderne type ChatGPT pour interagir avec vos modèles.

Après démarrage, accédez à: **http://localhost:3000**

Voir [WEBUI.md](WEBUI.md) pour le guide complet de l'interface web.

## Architecture

```
llm-provider/
├── docker-compose.yml      # Configuration Docker Compose
├── .env                    # Variables d'environnement (ne pas commiter)
├── .env.example            # Template des variables d'environnement
├── Makefile               # Commandes simplifiées
├── config/                # Configuration additionnelle
├── data/                  # Données persistantes (modèles)
├── logs/                  # Logs applicatifs
└── scripts/               # Scripts utilitaires
    ├── start.sh           # Démarrage du service
    ├── stop.sh            # Arrêt du service
    ├── status.sh          # Vérification du statut
    ├── logs.sh            # Consultation des logs
    ├── test-model.sh      # Test du modèle
    └── manage-models.sh   # Gestion des modèles
```

## Prérequis

- Docker (v20.10+)
- Docker Compose (v2.0+)
- Au moins 100GB d'espace disque (pour le modèle 120B)
- Minimum 32GB RAM recommandé
- GPU NVIDIA (optionnel mais fortement recommandé)

### Support GPU (NVIDIA)

Pour activer le support GPU, décommentez la section `deploy` dans [docker-compose.yml](docker-compose.yml):

```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]
```

Assurez-vous d'avoir le [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) installé.

## Démarrage rapide

### 1. Configuration

Copier le fichier d'exemple et ajuster les variables:

```bash
cp .env.example .env
# Éditez .env selon vos besoins
```

### 2. Lancement

Option A - Avec Make (recommandé):
```bash
make start
```

Option B - Avec les scripts:
```bash
./scripts/start.sh
```

Option C - Direct Docker Compose:
```bash
docker compose up -d
```

### 3. Accéder à l'interface web

Ouvrez votre navigateur:
```
http://localhost:3000
```

**Premier démarrage:**
1. Cliquez sur "Sign up"
2. Créez un compte (le premier devient admin)
3. Sélectionnez le modèle `gpt-oss:120b`
4. Commencez à chatter!

Voir [WEBUI.md](WEBUI.md) pour plus de détails.

### 4. Vérification

```bash
make status
# ou
./scripts/status.sh
```

## Utilisation

### Commandes principales

```bash
# Démarrer le service
make start

# Arrêter le service
make stop

# Redémarrer le service
make restart

# Voir le statut
make status

# Voir les logs
make logs

# Tester le modèle
make test

# Télécharger le modèle configuré
make pull-model
```

### Gestion des modèles

```bash
# Lister les modèles disponibles
./scripts/manage-models.sh list

# Télécharger un modèle spécifique
./scripts/manage-models.sh pull gpt-oss:120b

# Voir les détails d'un modèle
./scripts/manage-models.sh show gpt-oss:120b

# Supprimer un modèle
./scripts/manage-models.sh remove gpt-oss:120b
```

### API REST

Une fois le service démarré, l'API Ollama est disponible sur `http://localhost:11434`

#### Exemple d'utilisation

```bash
# Générer du texte
curl http://localhost:11434/api/generate -d '{
  "model": "gpt-oss:120b",
  "prompt": "Why is the sky blue?",
  "stream": false
}'

# Chat
curl http://localhost:11434/api/chat -d '{
  "model": "gpt-oss:120b",
  "messages": [
    {"role": "user", "content": "Hello!"}
  ],
  "stream": false
}'

# Lister les modèles
curl http://localhost:11434/api/tags
```

## Configuration

### Variables d'environnement

| Variable | Description | Défaut |
|----------|-------------|---------|
| `OLLAMA_PORT` | Port d'écoute de l'API | `11434` |
| `OLLAMA_ORIGINS` | CORS origins autorisées | `*` |
| `OLLAMA_KEEP_ALIVE` | Durée de rétention du modèle en mémoire | `5m` |
| `OLLAMA_MAX_LOADED_MODELS` | Nombre max de modèles chargés | `1` |
| `MODEL_NAME` | Nom du modèle à utiliser | `gpt-oss:120b` |
| `MODEL_PULL_ON_START` | Télécharger le modèle au démarrage | `true` |

### Personnalisation

Vous pouvez modifier [docker-compose.yml](docker-compose.yml) pour ajuster:
- Les limites de ressources
- Les volumes montés
- Le réseau
- Les options de healthcheck

## Migration vers une autre machine

### Export

```bash
# Créer une archive du setup
tar -czf llm-provider.tar.gz llm-provider/

# Si vous voulez inclure les modèles téléchargés (lourd)
tar -czf llm-provider-with-models.tar.gz llm-provider/
```

### Import

```bash
# Sur la nouvelle machine
tar -xzf llm-provider.tar.gz
cd llm-provider
make start
```

Pour une portabilité optimale sans les modèles (recommandé):
1. Copier seulement les fichiers de configuration
2. Les modèles seront téléchargés automatiquement au premier démarrage

## Troubleshooting

### Le service ne démarre pas

```bash
# Vérifier les logs
make logs

# Vérifier Docker
docker ps -a

# Vérifier l'espace disque
df -h
```

### Le modèle ne se charge pas

- Vérifier l'espace disque disponible (120B nécessite ~100GB)
- Vérifier la RAM disponible
- Consulter les logs: `make logs`

### Erreur de permission

```bash
# Rendre les scripts exécutables
chmod +x scripts/*.sh
```

### Port déjà utilisé

Modifier `OLLAMA_PORT` dans [.env](.env)

## Maintenance

### Nettoyer l'espace disque

```bash
# Supprimer les modèles inutilisés
./scripts/manage-models.sh list
./scripts/manage-models.sh remove <model-name>

# Nettoyer Docker
docker system prune -a
```

### Mise à jour

```bash
# Mettre à jour l'image Ollama
docker compose pull
make restart
```

### Backup

```bash
# Sauvegarder les modèles et la config
tar -czf backup-$(date +%Y%m%d).tar.gz data/ .env config/
```

## Sécurité

- Ne pas commiter le fichier `.env` (il est dans `.gitignore`)
- En production, restreindre `OLLAMA_ORIGINS` aux domaines autorisés
- Utiliser un reverse proxy (nginx/traefik) pour l'exposition publique
- Activer HTTPS via le reverse proxy
- Considérer l'authentification pour l'accès à l'API

## Performance

### Optimisations recommandées

1. **GPU**: Activer le support NVIDIA pour de meilleures performances
2. **RAM**: Plus de RAM permet de charger des modèles plus grands
3. **SSD**: Utiliser un SSD pour le stockage des modèles
4. **KEEP_ALIVE**: Ajuster selon votre usage (plus long = modèle reste en mémoire)

## Documentation Ollama

- [Documentation officielle Ollama](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Liste des modèles disponibles](https://ollama.com/library)
- [Guide d'optimisation](https://github.com/ollama/ollama/blob/main/docs/faq.md)

## Licence

MIT

## Support

Pour toute question ou problème:
1. Vérifier les logs: `make logs`
2. Consulter le status: `make status`
3. Consulter la documentation Ollama
