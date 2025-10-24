# LLM Provider

Infrastructure pour déployer Ollama avec GPT-OSS 120B et Open WebUI.

**Repository**: https://github.com/Sahlulegat/llm-provider

## Quick Start

```bash
git clone https://github.com/Sahlulegat/llm-provider.git
cd llm-provider
cp .env.example .env
# Générez une clé Fernet: python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
# Ajoutez-la dans .env comme WEBUI_SECRET_KEY
make start
```

Accédez à l'interface web : **http://localhost:3000**

## Architecture

```
llm-provider/
├── docker-compose.yml
├── docker-compose.prod.yml  # Production avec Traefik
├── .env                      # Variables (ne pas commiter)
├── .env.example
├── Makefile
├── deployment/
│   └── upcloud/
│       └── cloud-init.yml    # Déploiement automatique
└── scripts/
```

## Prérequis

- Docker + Docker Compose
- 100GB+ disque (pour le modèle)
- 32GB+ RAM recommandé
- GPU NVIDIA + Container Toolkit (activé par défaut)

## Commandes

```bash
make start     # Démarrer
make stop      # Arrêter
make restart   # Redémarrer
make status    # Statut
make logs      # Logs
make test      # Tester le modèle
```

## Open WebUI

Interface web type ChatGPT incluse sur http://localhost:3000

Premier démarrage :
1. Sign up (premier utilisateur = admin)
2. Sélectionnez `gpt-oss:120b`
3. Commencez à chatter

## API REST

L'API Ollama est disponible sur http://localhost:11434

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "gpt-oss:120b",
  "prompt": "Hello!",
  "stream": false
}'
```

## Configuration

Variables principales dans `.env`:

- `OLLAMA_KEEP_ALIVE=-1` : Modèle toujours chargé
- `OLLAMA_PORT=11434` : Port API
- `WEBUI_PORT=3000` : Port interface web
- `MODEL_NAME=gpt-oss:120b` : Modèle à utiliser
- `WEBUI_SECRET_KEY` : Clé de chiffrement Fernet (obligatoire)

## Déploiement UpCloud

Le fichier `deployment/upcloud/cloud-init.yml` déploie automatiquement tout :
- Clone le repo GitHub
- Install Docker + NVIDIA Toolkit
- Génère les clés
- Lance les services au boot

## Performance

- **GPU** : 26/37 couches sur NVIDIA L40S (42.4 GiB VRAM)
- **CPU** : 18.5 GiB pour les couches restantes
- **Keep Alive** : -1 (jamais déchargé)

## Troubleshooting

```bash
make logs              # Voir les logs
docker ps -a           # État des conteneurs
df -h                  # Espace disque
nvidia-smi             # GPU status
```

## Docs

- [Ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Open WebUI](https://github.com/open-webui/open-webui)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)
