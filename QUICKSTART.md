# LLM Provider - Guide de démarrage rapide

## Installation

### 1. Clonez le projet depuis GitHub

```bash
git clone https://github.com/Sahlulegat/llm-provider.git
cd llm-provider
```

### 2. Configurez l'environnement

```bash
# Copiez le fichier d'exemple
cp .env.example .env

# Générez une clé Fernet pour Open WebUI
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"

# Éditez .env et ajoutez la clé générée à WEBUI_SECRET_KEY
nano .env
```

## Lancement du service

### 1. Assurez-vous d'être dans le bon répertoire

```bash
pwd
# Doit afficher le chemin vers llm-provider
```

**IMPORTANT**: Vous DEVEZ être dans ce répertoire pour que `make` fonctionne!

### 2. Lancez le service

```bash
make start
```

## Si vous obtenez "No rule to make target start"

Cela signifie que vous n'êtes PAS dans le répertoire du projet. Solution:

```bash
# Vérifiez où vous êtes
pwd

# Allez dans le répertoire du projet
cd llm-provider  # ou le chemin complet

# Relancez
make start
```

## Commandes disponibles

```bash
# Démarrer
make start

# Arrêter
make stop

# Redémarrer
make restart

# Voir le statut
make status

# Voir les logs
make logs

# Tester l'API
make test

# Aide
make help
```

## Test rapide

Une fois démarré, testez:

```bash
# Vérifier que l'API répond
curl http://localhost:11434/api/tags

# Lister les modèles téléchargés
curl http://localhost:11434/api/tags | python3 -m json.tool
```

## Note sur le téléchargement du modèle

Au premier démarrage avec `MODEL_PULL_ON_START=true`:
- Le modèle gpt-oss:120b (~65GB) sera téléchargé
- Cela peut prendre **5-10 minutes** selon votre connexion
- Vous verrez une barre de progression dans les logs

## Troubleshooting

### "No rule to make target start"
→ Vous n'êtes pas dans le répertoire du projet `llm-provider`

### "Permission denied"
```bash
chmod +x scripts/*.sh
```

### "Port already in use"
```bash
# Arrêter les containers existants
docker compose down

# Ou changer le port dans .env
nano .env
# Modifier OLLAMA_PORT=11435
```

### Le service ne démarre pas
```bash
# Vérifier les logs
docker logs ollama-provider

# Vérifier l'espace disque (besoin de 100GB+)
df -h
```

## Déploiement automatique sur UpCloud

Le projet inclut un fichier `cloud-init.yml` pour déployer automatiquement tout le stack:
- Clone automatique depuis GitHub
- Installation de Docker + NVIDIA Container Toolkit
- Configuration automatique avec clé Fernet générée
- Démarrage automatique du service au boot
- Le modèle reste chargé indéfiniment en mémoire (OLLAMA_KEEP_ALIVE=-1)

Voir [`deployment/README.md`](deployment/README.md) et [`deployment/upcloud/cloud-init.yml`](deployment/upcloud/cloud-init.yml)
