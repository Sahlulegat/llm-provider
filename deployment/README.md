# Déploiement UpCloud

Guide pour déployer LLM Provider sur UpCloud avec cloud-init.

## Prérequis

- Compte UpCloud actif
- Clé SSH publique

## Déploiement

### 1. Créer un serveur

Dans [UpCloud Control Panel](https://hub.upcloud.com/):

- Zone: `de-fra1` (ou autre)
- Plan: **16xCPU-64GB** minimum (pour gpt-oss:120b)
- OS: Ubuntu 24.04 LTS
- Storage: 250GB MaxIOPS
- Hostname: `llm-provider`

### 2. Configurer Cloud-Init

Dans la section "User data", copiez le contenu de [`upcloud/cloud-init.yml`](upcloud/cloud-init.yml).

**Important**: Mettez à jour votre clé SSH dans le fichier cloud-init.yml.

### 3. Déployer

Cliquez sur "Deploy". Le serveur va automatiquement:
- Installer Docker + NVIDIA Container Toolkit
- Cloner le repo GitHub
- Générer les clés de chiffrement
- Démarrer les services
- Télécharger le modèle (~65GB)

### 4. Monitoring

```bash
# Connexion SSH
ssh root@<IP_ADDRESS>

# Surveiller cloud-init
tail -f /var/log/cloud-init-output.log

# Vérifier le service
systemctl status llm-provider.service

# Logs Docker
docker logs -f ollama-provider
docker logs -f open-webui

# Tester l'API
curl http://localhost:11434/api/tags
```

## Tailles de serveur recommandées

| Plan | vCPU | RAM | Usage |
|------|------|-----|-------|
| 8xCPU-32GB | 8 | 32GB | Test/Dev |
| **16xCPU-64GB** | 16 | 64GB | **Production** |
| 20xCPU-96GB | 20 | 96GB | Haute performance |

**Recommandation**: 16xCPU-64GB + 250GB storage

## Sécurité

Configuration du firewall UpCloud:
- Port 22: SSH
- Port 11434: Ollama API
- Port 3000: Open WebUI
- Ports 80/443: HTTP/HTTPS (optionnel)

Best practices:
- Restreindre SSH à vos IPs
- Utiliser un reverse proxy avec HTTPS en production
- Activer les backups automatiques
- Monitorer l'utilisation des ressources

## Troubleshooting

```bash
# Service ne démarre pas
journalctl -u llm-provider.service -n 100
systemctl restart llm-provider.service

# Modèle ne se télécharge pas
docker exec ollama-provider ollama pull gpt-oss:120b

# Vérifier espace disque
df -h

# GPU status
nvidia-smi
```

## Backup

```bash
# Backup des données
ssh root@<IP> 'tar -czf backup.tar.gz /opt/llm-provider/data/'

# Télécharger
scp root@<IP>:~/backup.tar.gz ./

# Restaurer sur nouveau serveur
scp backup.tar.gz root@<NEW_IP>:~
ssh root@<NEW_IP> 'cd /opt/llm-provider && tar -xzf ~/backup.tar.gz'
```

## Coûts estimés

Pour 16xCPU-64GB + 250GB MaxIOPS:
- ~$380/mois

Optimisations:
- Arrêter le serveur quand inutilisé
- Utiliser HDD au lieu de MaxIOPS (plus lent)

## Ressources

- [Documentation UpCloud](https://upcloud.com/docs/)
- [Ollama Docs](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Open WebUI](https://github.com/open-webui/open-webui)
