# LLM Provider - Guide de démarrage rapide

## Lancement du service

### 1. Allez dans le bon répertoire

```bash
cd /opt/projects/llm-provider
```

**IMPORTANT**: Vous DEVEZ être dans ce répertoire pour que `make` fonctionne!

### 2. Vérifiez que vous êtes au bon endroit

```bash
pwd
# Doit afficher: /opt/projects/llm-provider

ls Makefile
# Doit afficher: Makefile
```

### 3. Lancez le service

```bash
make start
```

## Si vous obtenez "No rule to make target start"

Cela signifie que vous n'êtes PAS dans le bon répertoire. Solution:

```bash
# Vérifiez où vous êtes
pwd

# Allez dans le bon répertoire
cd /opt/projects/llm-provider

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
→ Vous n'êtes pas dans `/opt/projects/llm-provider`

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

## Pour le déploiement UpCloud

Voir [`deployment/README.md`](deployment/README.md) pour:
- Déploiement avec Terraform
- Déploiement avec Cloud-Init
- Configuration production
- Sécurité et monitoring
