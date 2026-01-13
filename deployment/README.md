# Déploiement UpCloud

Deux méthodes pour déployer LLM Provider sur UpCloud.

## Méthode 1 : Terraform (Recommandé)

Infrastructure as Code - reproductible et automatisé.

### Quick Start

```bash
cd deployment/terraform

# Exporter les credentials UpCloud
export UPCLOUD_USERNAME="your-api-username"
export UPCLOUD_PASSWORD="your-api-password"

# Configurer
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars

# Déployer
terraform init
terraform plan
terraform apply
```

Voir [terraform/README.md](terraform/README.md) pour le guide complet.

### Avantages

- Infrastructure versionnée dans Git
- Déploiement reproductible
- Firewall configuré automatiquement
- Outputs avec URLs et commandes

## Méthode 2 : Cloud-Init Manuel

Configuration via l'interface web UpCloud.

### Étapes

1. **Créer un serveur** dans [UpCloud Control Panel](https://hub.upcloud.com/)

   - Zone: `fi-hel2` (Helsinki) ou autre
   - Plan: **GPU-12xCPU-128GB-1xL40S** (ou 16xCPU-64GB minimum)
   - OS: Ubuntu 24.04 LTS
   - Storage: 200GB MaxIOPS

2. **User Data**: dans [`upcloud/cloud-init.yml`](upcloud/cloud-init.yml)

   - Mettez à jour votre clé SSH dans le fichier
   - Les nouvelles variables d'environnement doivent également être ajoutées dans ce fichier dans le bloc correspondant, ainsi que dans les fichiers **variables.tf** et **main.tf**

3. **Deploy** et attendez (~10-15 minutes)

- Au premier lancement : 
```bash
./deploy.sh init
```
- Vérification du plan d'exécution : 
```bash
./deploy.sh plan
```
- Déploiement sur upcloud selon le plan précédent :
```bash
./deploy.sh deploy
```

### Monitoring

Le user accessible en ssh est **llmadmin** (défini dans le cloud.init)
```bash
ssh llmadmin@<IP>
tail -f /var/log/cloud-init-output.log
docker ps
htop
# etc.
```

## Plans recommandés

| Plan | vCPU | RAM | VRAM | Prix/mois* |
|------|------|-----|------|-----------|
| GPU-12xCPU-128GB-1xL40S | 12 | 128GB | 48GB L40S | ~€900 |

*Prix approximatifs

L'instance ne restera allumée qu'une fraction de chaque journée, et les coûts seront divisés en conséquence

## Ce qui est déployé

- Docker + NVIDIA Container Toolkit
- Ollama avec GPU support
- Open WebUI
- Caddy (reverse proxy HTTPS automatique)
- Systemd service (auto-start au boot)
- Model gpt-oss:120b (~65GB)
- Stack paddleOCR (API + moteur)
- Backups quotidiens

## Accès

Après déploiement :
- SSH: `ssh root@<IP>`
- Ollama API: `http://<IP>:11434` (ou `https://api.votre-domaine.com` si configuré)
- Open WebUI: `http://<IP>:3000` (ou `https://votre-domaine.com` si configuré)

Pour activer HTTPS avec domaine, configurez `DOMAIN_NAME` et `ACME_EMAIL` dans `.env` puis relancez :
```bash
make restart
```

Caddy détecte automatiquement le domaine et active HTTPS.

## Troubleshooting

```bash
# Service status
systemctl status llm-provider.service

# Logs
journalctl -u llm-provider.service -f
docker logs -f ollama-provider

# GPU
nvidia-smi

# Espace disque
df -h
```

## Sécurité

- Firewall activé (avec Terraform) : SSH (22), HTTP (80), HTTPS (443)
- Caddy gère automatiquement les certificats SSL Let's Encrypt
- Désactiver `ENABLE_SIGNUP=false` après création du premier compte admin
- Restreindre les IPs dans le firewall UpCloud pour limiter l'accès

## Backup

```bash
# Backup
ssh root@<IP> 'tar -czf backup.tar.gz /opt/llm-provider/data/'
scp root@<IP>:~/backup.tar.gz ./

# Restore
scp backup.tar.gz root@<NEW_IP>:~
ssh root@<NEW_IP> 'cd /opt/llm-provider && tar -xzf ~/backup.tar.gz'
```

## Ressources

- [Terraform Guide](terraform/README.md)
- [UpCloud Docs](https://upcloud.com/docs/)
- [Ollama Docs](https://github.com/ollama/ollama/blob/main/docs/api.md)
