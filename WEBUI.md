# LLM Provider - Interface Web (Open WebUI)

Guide pour utiliser l'interface graphique chatbot avec vos modèles Ollama.

## Qu'est-ce que Open WebUI?

**Open WebUI** est une interface web moderne de type ChatGPT pour Ollama. Elle offre:
- Interface de chat intuitive
- Support multi-modèles
- Authentification utilisateur
- Historique des conversations
- Markdown et code highlighting
- Upload de documents
- Génération d'images (avec modèles compatibles)

## Démarrage rapide (Local)

### 1. Lancer le service

```bash
cd /opt/projects/llm-provider
make start
```

Cela démarre:
- Ollama (backend IA)
- Open WebUI (interface web)

### 2. Accéder à l'interface

Ouvrez votre navigateur:
```
http://localhost:3000
```

### 3. Créer un compte admin

Lors de la première visite:
1. Cliquez sur "Sign up"
2. Créez un compte (email + mot de passe)
3. **Le premier utilisateur devient automatiquement admin**

### 4. Choisir un modèle

Dans l'interface:
1. Cliquez sur le sélecteur de modèle en haut
2. Sélectionnez `gpt-oss:120b` (ou autre modèle téléchargé)
3. Commencez à chatter!

## Configuration de sécurité

### Désactiver l'inscription après création admin

Une fois votre compte admin créé:

```bash
# Éditer .env
nano .env

# Changer:
ENABLE_SIGNUP=false
```

Puis redémarrer:
```bash
make restart
```

### Générer une clé secrète sécurisée

```bash
# Générer une clé
openssl rand -base64 32

# Copier le résultat dans .env
nano .env
# WEBUI_SECRET_KEY=<la-clé-générée>
```

## Accès depuis le Cloud (UpCloud)

### Option 1: IP publique + Port (Rapide mais moins sécurisé)

Si vous déployez sur UpCloud sans nom de domaine:

```bash
# Sur le serveur UpCloud
cd /opt/llm-provider
make start
```

Accédez via:
```
http://<IP-PUBLIQUE-SERVER>:3000
```

**Attention**: HTTP non chiffré, utilisez uniquement pour tests!

### Option 2: Tunnel SSH (Sécurisé sans domaine)

Pour un accès sécurisé sans nom de domaine:

```bash
# Depuis votre PC
ssh -L 3000:localhost:3000 root@<IP-SERVER>

# Dans un autre terminal/navigateur
http://localhost:3000
```

Le trafic est chiffré via SSH!

### Option 3: Nom de domaine + HTTPS (Recommandé pour production)

Pour un accès sécurisé avec HTTPS automatique:

#### A. Prérequis
1. Un nom de domaine (ex: `llm.votredomaine.com`)
2. DNS pointant vers l'IP de votre serveur UpCloud

#### B. Configuration

```bash
# Sur le serveur UpCloud, éditer .env
nano .env
```

Configurer:
```bash
DOMAIN_NAME=llm.votredomaine.com
ACME_EMAIL=votre@email.com
ENABLE_SIGNUP=false  # Désactiver après création compte
```

#### C. Démarrer avec production config

```bash
# Utiliser docker-compose.prod.yml
docker compose -f docker-compose.prod.yml up -d
```

Accédez via:
```
https://llm.votredomaine.com
```

HTTPS automatique avec Let's Encrypt!

## Utilisation de l'interface

### Créer une conversation

1. Cliquez sur "New Chat"
2. Tapez votre question
3. Appuyez sur Entrée ou cliquez sur Envoyer

### Changer de modèle

Cliquez sur le nom du modèle en haut pour voir tous les modèles disponibles.

### Paramètres avancés

Cliquez sur l'icône paramètres pour ajuster:
- **Temperature**: Créativité (0 = précis, 1 = créatif)
- **Top P**: Diversité des réponses
- **Max Tokens**: Longueur maximale de la réponse

### Upload de documents

1. Cliquez sur l'icône trombone
2. Sélectionnez un fichier (PDF, TXT, MD, etc.)
3. Posez des questions sur le document

### Historique

Toutes vos conversations sont sauvegardées dans la sidebar gauche.

## Gestion des utilisateurs (Admin)

En tant qu'admin:

1. Cliquez sur votre avatar (coin supérieur droit)
2. "Settings" → "Admin Panel"
3. Gérez les utilisateurs, modèles, etc.

### Approuver des utilisateurs

Si `DEFAULT_USER_ROLE=pending`:
1. Admin Panel → Users
2. Trouvez l'utilisateur en attente
3. Changez son rôle à "User" ou "Admin"

## Ports utilisés

| Service | Port | Description |
|---------|------|-------------|
| Open WebUI | 3000 | Interface web |
| Ollama API | 11434 | Backend IA (interne) |
| Traefik HTTP | 80 | Redirect vers HTTPS |
| Traefik HTTPS | 443 | Accès sécurisé |

## Architecture

```
┌─────────────────┐
│   Navigateur    │
│  (votre PC)     │
└────────┬────────┘
         │ HTTPS (port 443)
         ▼
┌─────────────────┐
│    Traefik      │ ← Reverse proxy + HTTPS
│  (Let's Encrypt)│
└────────┬────────┘
         │ HTTP (interne)
         ▼
┌─────────────────┐
│   Open WebUI    │ ← Interface web
│   (port 8080)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     Ollama      │ ← Moteur IA
│  (gpt-oss:120b) │
└─────────────────┘
```

## Troubleshooting

### L'interface ne charge pas

```bash
# Vérifier les containers
docker ps

# Vérifier les logs
docker logs open-webui

# Redémarrer
make restart
```

### "Cannot connect to Ollama"

```bash
# Vérifier qu'Ollama est démarré
docker logs ollama-provider

# Vérifier la connexion
docker exec open-webui curl http://ollama:11434/api/tags
```

### Certificat SSL ne se génère pas

Vérifications:
1. DNS pointe bien vers l'IP du serveur
2. Ports 80 et 443 ouverts dans le firewall
3. Email valide dans `ACME_EMAIL`

```bash
# Voir les logs Traefik
docker logs traefik

# Vérifier les certificats
docker exec traefik ls -la /letsencrypt/
```

### Réinitialiser le mot de passe admin

```bash
# Arrêter le service
docker compose down

# Supprimer la base de données
rm -rf data/open-webui/webui.db

# Redémarrer (vous pourrez recréer un compte)
make start
```

## Commandes utiles

```bash
# Lancer le service
make start

# Arrêter
make stop

# Redémarrer
make restart

# Voir les logs de l'interface
docker logs -f open-webui

# Voir les logs Ollama
docker logs -f ollama-provider

# Version production avec HTTPS
docker compose -f docker-compose.prod.yml up -d

# Arrêter production
docker compose -f docker-compose.prod.yml down
```

## Sauvegarder vos données

### Conversations et utilisateurs

```bash
# Backup
tar -czf backup-webui-$(date +%Y%m%d).tar.gz data/open-webui/

# Restaurer
tar -xzf backup-webui-YYYYMMDD.tar.gz
```

### Modèles

```bash
# Backup (attention, gros fichiers!)
tar -czf backup-ollama-$(date +%Y%m%d).tar.gz data/ollama/
```

## Fonctionnalités avancées

### API REST

Open WebUI expose aussi une API REST compatible OpenAI:

```bash
curl https://llm.votredomaine.com/api/chat \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-oss:120b",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Intégrations

Open WebUI supporte:
- OpenAI API compatibility
- RAG (Retrieval Augmented Generation)
- Plugins et extensions
- Thèmes personnalisés

Voir [Open WebUI Documentation](https://docs.openwebui.com/) pour plus de détails.

## Mise à jour

```bash
# Arrêter
make stop

# Mettre à jour l'image
docker pull ghcr.io/open-webui/open-webui:main

# Redémarrer
make start
```

## Sécurité Best Practices

1. **Toujours utiliser HTTPS en production** (option 3)
2. **Désactiver l'inscription après création admin** (`ENABLE_SIGNUP=false`)
3. **Utiliser une clé secrète forte** (`WEBUI_SECRET_KEY`)
4. **Firewall**: Limiter l'accès aux ports 80/443 uniquement
5. **Sauvegardes régulières** des données
6. **Mises à jour régulières** des images Docker
7. **Monitoring** des ressources (CPU, RAM, disque)

## Support

- Documentation Open WebUI: https://docs.openwebui.com/
- GitHub: https://github.com/open-webui/open-webui
- Discord: https://discord.gg/5rJgQTnV4s
