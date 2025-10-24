# Terraform Deployment

Déploiement automatisé sur UpCloud avec Terraform.

## Prérequis

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- Credentials API UpCloud

## Configuration

### 1. Créer les credentials API UpCloud

Dans [UpCloud Control Panel](https://hub.upcloud.com/):
- People → Permissions → API Credentials
- Create API credentials
- Notez le username et password

### 2. Configurer les credentials

**Option A - Via .env (Recommandé)**

Ajoutez dans `/opt/projects/llm-provider/.env`:
```bash
UPCLOUD_USERNAME=your-api-username
UPCLOUD_PASSWORD=your-api-password
```

Puis utilisez le script wrapper:
```bash
./deploy.sh plan
./deploy.sh apply
```

**Option B - Export manuel**
```bash
export UPCLOUD_USERNAME="your-api-username"
export UPCLOUD_PASSWORD="your-api-password"
terraform plan
```

### 3. Configurer les variables

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

## Déploiement

**Option A - Avec script wrapper (Simple)**

```bash
./deploy.sh init
./deploy.sh plan
./deploy.sh apply
```

Le script charge automatiquement les credentials depuis `../../.env`

**Option B - Manuel**

```bash
export UPCLOUD_USERNAME="..."
export UPCLOUD_PASSWORD="..."
terraform init
terraform plan
terraform apply
```

## Outputs

Après déploiement, récupérez les informations :

```bash
terraform output
```

Vous obtiendrez :
- IPv4 et IPv6 du serveur
- Commande SSH
- URLs API Ollama et WebUI
- Commande de monitoring cloud-init

## Gestion

```bash
# Voir l'état
terraform show

# Détruire (ATTENTION: irréversible!)
terraform destroy
```

## Variables disponibles

| Variable | Description | Défaut |
|----------|-------------|---------|
| `hostname` | Nom du serveur | `llm-provider` |
| `zone` | Zone UpCloud | `fi-hel2` |
| `plan` | Plan serveur | `GPU-12xCPU-128GB-1xL40S` |
| `storage_size` | Taille disque (GB) | `200` |
| `storage_tier` | Tier storage | `maxiops` |
| `backup_plan` | Plan backup | `daily` |
| `backup_time` | Heure backup | `0200` |

## Firewall

Le firewall est activé avec les règles :
- SSH (22)
- Ollama API (11434)
- Open WebUI (3000)
- HTTP/HTTPS (80/443)
