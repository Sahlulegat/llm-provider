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

2. **User Data**: Copiez [`upcloud/cloud-init.yml`](upcloud/cloud-init.yml)

   **Important**: Mettez à jour votre clé SSH dans le fichier

3. **Deploy** et attendez (~10-15 minutes)

### Monitoring

```bash
ssh root@<IP>
tail -f /var/log/cloud-init-output.log
```

## Plans recommandés

| Plan | vCPU | RAM | VRAM | Prix/mois* |
|------|------|-----|------|-----------|
| GPU-12xCPU-128GB-1xL40S | 12 | 128GB | 48GB L40S | ~€450 |
| 16xCPU-64GB | 16 | 64GB | - | ~€320 |
| 8xCPU-32GB | 8 | 32GB | - | ~€160 |

*Prix approximatifs

## Ce qui est déployé

- Docker + NVIDIA Container Toolkit
- Ollama avec GPU support
- Open WebUI
- Systemd service (auto-start au boot)
- Model gpt-oss:120b (~65GB)
- Backups quotidiens

## Accès

Après déploiement :
- SSH: `ssh root@<IP>`
- Ollama API: `http://<IP>:11434`
- Open WebUI: `http://<IP>:3000`

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

- Firewall activé (avec Terraform)
- SSH, Ollama API (11434), WebUI (3000), HTTP/HTTPS
- Restreindre les IPs dans le firewall UpCloud
- Utiliser un reverse proxy HTTPS en production

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
