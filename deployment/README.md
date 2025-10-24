# LLM Provider - Déploiement sur UpCloud

Guide complet pour déployer le LLM provider avec le modèle gpt-oss:120b sur UpCloud.

## Vue d'ensemble

Ce répertoire contient deux méthodes de déploiement:

1. **Cloud-Init** - Script d'initialisation automatique pour configuration manuelle
2. **Terraform** - Infrastructure as Code pour déploiement automatisé (recommandé)

## Prérequis

### Pour les deux méthodes
- Compte UpCloud actif
- Clé SSH publique configurée

### Pour Terraform (recommandé)
- Terraform >= 1.0 installé ([Installation](https://developer.hashicorp.com/terraform/downloads))
- Identifiants UpCloud API

## Méthode 1: Déploiement avec Cloud-Init (Manuel)

### Étapes

1. **Connexion à UpCloud**
   - Connectez-vous à [UpCloud Control Panel](https://hub.upcloud.com/)

2. **Créer un nouveau serveur**
   - Cliquez sur "Deploy a new server"
   - Sélectionnez la zone: `de-fra1` (Frankfurt) ou autre
   - Choisissez le plan: **16xCPU-64GB** minimum (recommandé pour 120B)
   - Sélectionnez Ubuntu 24.04 LTS

3. **Configuration**
   - **Hostname**: `llm-provider-01`
   - **Storage**: 250GB MaxIOPS
   - **SSH Keys**: Ajoutez votre clé publique

4. **Cloud-Init**
   - Dans la section "User data", copiez le contenu de [`upcloud/cloud-init.yml`](upcloud/cloud-init.yml)
   - **IMPORTANT**: Remplacez `ssh-rsa AAAAB3NzaC1yc2E...` par votre vraie clé SSH publique

5. **Déploiement**
   - Cliquez sur "Deploy"
   - Le serveur va démarrer et exécuter automatiquement:
     - Installation de Docker et dépendances
     - Configuration du service Ollama
     - Téléchargement du modèle gpt-oss:120b (~100GB)

6. **Monitoring**
   ```bash
   # Se connecter au serveur
   ssh root@<IP_ADDRESS>

   # Surveiller le cloud-init
   tail -f /var/log/cloud-init-output.log

   # Vérifier le service
   systemctl status llm-provider.service

   # Voir les logs Ollama
   docker logs -f ollama-provider
   ```

7. **Tester l'API**
   ```bash
   curl http://<IP_ADDRESS>:11434/api/tags
   ```

### Avantages
- Simple et direct
- Pas d'outils supplémentaires requis
- Bon pour tests rapides

### Inconvénients
- Configuration manuelle via l'interface web
- Pas de versioning de l'infrastructure
- Difficile à répliquer
- Pas d'automatisation complète

## Méthode 2: Déploiement avec Terraform (Recommandé)

### Pourquoi Terraform?

- **Infrastructure as Code**: Configuration versionnée dans Git
- **Reproductible**: Déploiement identique à chaque fois
- **Automatisé**: Un seul commande pour tout créer
- **Maintenable**: Facile à modifier et mettre à jour
- **Sécurisé**: Firewall et networking configurés automatiquement
- **Multi-environnement**: Dev, staging, prod avec la même config

### Installation de Terraform

#### Linux
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

#### macOS
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

#### Vérification
```bash
terraform version
```

### Configuration UpCloud API

1. **Créer un compte API dans UpCloud**
   - Allez sur [UpCloud Control Panel](https://hub.upcloud.com/)
   - Naviguez vers "People" → "Permissions" → "API Credentials"
   - Cliquez sur "Create API credentials"
   - Notez le username et password

2. **Configurer les credentials**
   ```bash
   # Option 1: Variables d'environnement (recommandé)
   export UPCLOUD_USERNAME="your-api-username"
   export UPCLOUD_PASSWORD="your-api-password"

   # Option 2: Dans le provider (moins sécurisé)
   # Voir terraform/main.tf
   ```

### Déploiement

1. **Naviguer vers le répertoire Terraform**
   ```bash
   cd terraform/
   ```

2. **Configurer les variables**
   ```bash
   # Copier le fichier exemple
   cp terraform.tfvars.example terraform.tfvars

   # Éditer avec vos valeurs
   nano terraform.tfvars
   ```

   **Minimum requis** dans `terraform.tfvars`:
   ```hcl
   server_hostname = "llm-provider-01"
   zone           = "de-fra1"
   server_plan    = "16xCPU-64GB"
   storage_size   = 250

   # Votre clé SSH publique
   ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E... your-email@example.com"
   ```

3. **Initialiser Terraform**
   ```bash
   terraform init
   ```

4. **Planifier le déploiement**
   ```bash
   terraform plan
   ```
   Cette commande affiche ce qui va être créé sans rien modifier.

5. **Appliquer le déploiement**
   ```bash
   terraform apply
   ```
   - Vérifiez le plan affiché
   - Tapez `yes` pour confirmer
   - Le déploiement prend 5-10 minutes

6. **Récupérer les informations**
   ```bash
   terraform output
   ```
   Vous obtiendrez:
   - L'adresse IP publique
   - L'endpoint de l'API
   - Les commandes de monitoring
   - La commande SSH

### Monitoring du déploiement

```bash
# IP du serveur
SERVER_IP=$(terraform output -raw public_ipv4)

# Surveiller cloud-init
ssh root@$SERVER_IP 'tail -f /var/log/cloud-init-output.log'

# Vérifier le service
ssh root@$SERVER_IP 'systemctl status llm-provider.service'

# Logs Docker
ssh root@$SERVER_IP 'docker logs -f ollama-provider'

# Tester l'API
curl http://$SERVER_IP:11434/api/tags
```

### Gestion de l'infrastructure

```bash
# Voir l'état actuel
terraform show

# Voir les outputs
terraform output

# Modifier la configuration
nano terraform.tfvars
terraform plan
terraform apply

# Détruire l'infrastructure (ATTENTION: irréversible!)
terraform destroy
```

### Script Helper

Un script helper est fourni pour simplifier les opérations communes:

```bash
# Initialiser
./deploy.sh init

# Déployer
./deploy.sh deploy

# Vérifier le statut
./deploy.sh status

# Détruire
./deploy.sh destroy
```

## Choix de la taille du serveur

### Pour gpt-oss:120b

| Plan | vCPU | RAM | Prix/mois* | Usage recommandé |
|------|------|-----|------------|------------------|
| 8xCPU-32GB | 8 | 32GB | ~$160 | Test/Dev uniquement |
| **16xCPU-64GB** | 16 | 64GB | ~$320 | **Production (recommandé)** |
| 20xCPU-96GB | 20 | 96GB | ~$480 | Production haute performance |
| 24xCPU-128GB | 24 | 128GB | ~$640 | Multiple modèles |

*Prix approximatifs, vérifier sur UpCloud

### Recommandations

- **Minimum absolu**: 8xCPU-32GB (peut être lent)
- **Recommandé**: 16xCPU-64GB (bon équilibre)
- **Optimal**: 20xCPU-96GB+ (meilleures performances)
- **Storage**: Minimum 250GB (le modèle fait ~100GB)
- **Type**: MaxIOPS pour meilleures performances

## Sécurité

### Firewall

Le Terraform configure automatiquement un firewall avec:
- Port 22 (SSH)
- Port 11434 (Ollama API)
- Ports 80/443 (HTTP/HTTPS pour reverse proxy)

### Restreindre l'accès

Dans `terraform.tfvars`:

```hcl
# Limiter SSH à votre IP
allowed_ssh_ips = ["1.2.3.4/32"]

# Limiter l'API à des IPs spécifiques
allowed_api_ips = ["1.2.3.4/32", "5.6.7.8/32"]
```

### Best Practices

1. **Ne jamais commiter** `terraform.tfvars` (contient des credentials)
2. **Utiliser un reverse proxy** (nginx/traefik) avec HTTPS en production
3. **Activer les backups** automatiques UpCloud
4. **Monitorer l'utilisation** des ressources
5. **Mettre à jour** régulièrement l'image Ollama

## Coûts estimés

### Serveur 16xCPU-64GB + 250GB MaxIOPS
- Compute: ~$320/mois
- Storage: ~$50/mois
- Traffic: ~$10/mois (estimé)
- **Total**: ~$380/mois

### Optimisations des coûts

1. **Start/Stop**: Arrêter le serveur quand inutilisé
2. **Scaling**: Utiliser un plan plus petit pour dev/test
3. **Storage**: Utiliser HDD au lieu de MaxIOPS (plus lent)
4. **Reserved instances**: Réductions pour engagement long terme

## Troubleshooting

### Le modèle ne se télécharge pas

```bash
# Se connecter au serveur
ssh root@$SERVER_IP

# Vérifier l'espace disque
df -h

# Télécharger manuellement
docker exec -it ollama-provider ollama pull gpt-oss:120b
```

### Service ne démarre pas

```bash
# Vérifier les logs
journalctl -u llm-provider.service -n 100

# Redémarrer
systemctl restart llm-provider.service
```

### Terraform errors

```bash
# Réinitialiser
terraform init -upgrade

# Voir l'état détaillé
terraform show

# Force unlock (si bloqué)
terraform force-unlock <LOCK_ID>
```

### Port non accessible

```bash
# Vérifier le firewall UpCloud
# Vérifier que l'IP est dans allowed_api_ips

# Tester depuis le serveur
ssh root@$SERVER_IP
curl http://localhost:11434/api/tags
```

## Mise à jour du modèle

```bash
# SSH sur le serveur
ssh root@$SERVER_IP

# Changer le modèle dans .env
cd /opt/llm-provider
nano .env
# Modifier MODEL_NAME=autre-modele:tag

# Redémarrer
systemctl restart llm-provider.service

# Ou pull manuellement
docker exec -it ollama-provider ollama pull autre-modele:tag
```

## Migration et Backup

### Backup des données

```bash
# SSH sur le serveur
ssh root@$SERVER_IP

# Backup du volume Ollama
tar -czf ollama-backup-$(date +%Y%m%d).tar.gz /opt/llm-provider/data/

# Télécharger localement
scp root@$SERVER_IP:/root/ollama-backup-*.tar.gz ./
```

### Restauration

```bash
# Sur le nouveau serveur
scp ollama-backup-*.tar.gz root@$NEW_SERVER_IP:/root/

# SSH et restaurer
ssh root@$NEW_SERVER_IP
cd /opt/llm-provider
tar -xzf /root/ollama-backup-*.tar.gz -C /
systemctl restart llm-provider.service
```

## Support

### Ressources
- [Documentation UpCloud](https://upcloud.com/docs/)
- [Terraform UpCloud Provider](https://registry.terraform.io/providers/UpCloudLtd/upcloud/latest/docs)
- [Documentation Ollama](https://github.com/ollama/ollama/blob/main/docs/api.md)

### Logs importants
- Cloud-init: `/var/log/cloud-init-output.log`
- Service: `journalctl -u llm-provider.service`
- Docker: `docker logs ollama-provider`
- Ollama: `/opt/llm-provider/logs/`

## Annexes

### Variables Terraform complètes

Voir [`terraform/variables.tf`](terraform/variables.tf) pour la liste complète.

### Configuration Cloud-Init

Voir [`upcloud/cloud-init.yml`](upcloud/cloud-init.yml) pour le détail.

### Checklist de déploiement

- [ ] Créer les credentials API UpCloud
- [ ] Installer Terraform
- [ ] Configurer les variables d'environnement
- [ ] Copier et éditer terraform.tfvars
- [ ] Vérifier la clé SSH
- [ ] Exécuter terraform plan
- [ ] Appliquer avec terraform apply
- [ ] Noter l'IP publique
- [ ] Monitorer cloud-init
- [ ] Tester l'API
- [ ] Configurer le DNS (optionnel)
- [ ] Setup reverse proxy (optionnel)
- [ ] Activer les backups

## Licence

MIT
