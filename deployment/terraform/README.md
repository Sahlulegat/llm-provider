# Terraform Deployment

Déploiement automatisé sur UpCloud avec Terraform.

## Prérequis

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- Credentials API UpCloud
- **Fichier `.env` configuré** à la racine du projet

## Configuration

### 0. Configurer .env local

**Terraform va copier votre `.env` local** vers le serveur cloud automatiquement.

```bash
# Retour à la racine du projet
cd ../../

# Créer votre .env depuis l'exemple
cp .env.example .env
nano .env
```

**Variables importantes à configurer** :

```bash
# Production HTTPS (optionnel, laissez vide pour localhost)
DOMAIN_NAME="chat.exemple.com"
ACME_EMAIL="votre@email.com"

# Autres variables selon vos besoins
OLLAMA_KEEP_ALIVE=-1
MODEL_NAME=gpt-oss:120b
# etc.
```

**Note sur WEBUI_SECRET_KEY** :
- Laissez cette valeur **vide** (`WEBUI_SECRET_KEY=""`)
- Elle sera **automatiquement générée de façon sécurisée** sur le serveur
- Pas besoin de la générer localement !

### 1. Configurer les credentials

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

### 2. Configurer les variables

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Normalement, tout peut être laissé par défaut

## Déploiement

**Avant de déployer** : Vérifiez que votre `.env` à la racine du projet est bien configuré (étape 0).

**Option A - Avec script wrapper (Simple)**

```bash
./deploy.sh init
./deploy.sh plan
./deploy.sh apply
```

Le script :
- Charge automatiquement les credentials depuis `../../.env`
- Copie tout le contenu de `../../.env` vers le serveur cloud
- Génère automatiquement une `WEBUI_SECRET_KEY` sécurisée sur le serveur
- Caddy active automatiquement HTTPS si `DOMAIN_NAME` est configuré

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

Le firewall est activé avec les règles (en cours de configuration, les valeurs ci-dessous sont à vérifier):
- SSH (22)
- Ollama API (11434)
- Open WebUI (3000)
- HTTP/HTTPS (80/443)

## Sécurité

### Protection des secrets

Le .env n'est pas commit, mais est recréé côté serveur via transmission des variables (.env => Variable d'env TF_VAR_ => Variable terraform => Création du .env via cloud init)

### Après déploiement

```bash
# 1. Connectez-vous au serveur
ssh root@<IP>

# 2. Vérifiez l'état des conteneurs
docker ps
```
