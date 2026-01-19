# Wireguard VPN - Guide de connexion

## Vue d'ensemble

Le VPN Wireguard permet de créer un tunnel chiffré entre votre machine locale et le serveur cloud. Une fois connecté, vous avez accès direct à tous les services internes sans passer par les endpoints publics.

## Configuration dans .env

```bash
# Nombre de configurations client à générer
TF_VAR_wireguard_peers=1

# Adresse publique du serveur VPN (utilisez votre floating IP)
TF_VAR_wireguard_serverurl="94.237.10.48"

# Port UDP pour Wireguard (par défaut 51820)
TF_VAR_wireguard_serverport=51820

# Serveur DNS pour les clients VPN
TF_VAR_wireguard_peerdns="1.1.1.1"

# Subnet interne du VPN (plage d'IPs privées)
TF_VAR_wireguard_internal_subnet="10.13.13.0"
```

### Description des variables

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `wireguard_peers` | Nombre de configurations client (peer1, peer2, etc.) | 1 |
| `wireguard_serverurl` | IP publique du serveur VPN | auto (détection) |
| `wireguard_serverport` | Port UDP pour Wireguard | 51820 |
| `wireguard_peerdns` | DNS utilisé par les clients VPN | 1.1.1.1 |
| `wireguard_internal_subnet` | Subnet privé du VPN (format: x.x.x.0) | 10.13.13.0 |

## Déploiement

Tout est géré dans la stack, et avec terraform :

```bash
set -a && source .env && set +a
cd deployment/terraform
terraform plan
terraform apply
```

Le firewall UpCloud sera automatiquement configuré pour autoriser le port UDP 51820.

## Récupération de la configuration client

Une fois le serveur déployé, connectez-vous en SSH pour récupérer votre configuration:

```bash
ssh llmadmin@94.237.10.48
```

### Méthode 1: Via les logs (QR Code + Config)

```bash
docker logs wireguard-vpn
```

Vous verrez:
- Un **QR code** à scanner avec l'app mobile
- La **configuration complète** en texte brut

### Méthode 2: Fichier de configuration

```bash
# Afficher la config
cat /opt/llm-provider/data/wireguard/peer1/peer1.conf

# Télécharger le fichier sur votre machine locale (ou copier coller)
scp llmadmin@94.237.10.48:/opt/llm-provider/data/wireguard/peer1/peer1.conf ~/wireguard-llm.conf
```

## Installation du client Wireguard

### Windows

1. Téléchargez: https://www.wireguard.com/install/
2. Installez l'application
3. Cliquez sur "Importer un tunnel depuis un fichier"
4. Sélectionnez `wireguard-llm.conf`
5. Activez le tunnel

Chez PS il faut lancer wireguard en admin, puis dans un powershell admin exécuter : 

```bash
& "C:\Program Files\WireGuard\wireguard.exe" /installtunnelservice "D:\wireguard-llm.conf"
# Arrêt et reboot
net stop 'WireGuardTunnel$wg0'
net start 'WireGuardTunnel$wg0'
```

(Mettre le bon chemin de fichier téléchargé dans les étapes précédentes pour **wireguard-llm.conf**)

## Utilisation du VPN

### Vérifier la connexion

```bash
# Votre nouvelle IP VPN (devrait être 10.13.13.2)
ipconfig                  # Windows

# Tester la connectivité
ping 10.13.13.1
```

### Accès aux services internes

Une fois connecté, accédez directement aux conteneurs:

```bash
# Ollama API (port interne 11434)
curl http://10.13.13.1:11434/api/tags
# ou via l'IP flottante de la machine upcloud : 
curl http://94.237.10.48:11434/api/tags

# Open WebUI (port interne 3000)
# Ouvrez dans le navigateur: http://10.13.13.1:3000
# ou http://94.237.10.48:3000/

# API OCR PaddleOCR (si activée)
curl http://10.13.13.1:8080/health
```

## Ajouter un nouveau peer

Pour ajouter un appareil supplémentaire:

```bash
# Dans .env
TF_VAR_wireguard_peers=2  # ou 3, 4, etc.

# Redéployer
set -a && source .env && set +a
cd deployment/terraform && terraform apply
```

Récupérez ensuite la config du nouveau peer:

```bash
ssh llmadmin@94.237.10.48 "cat /opt/llm-provider/data/wireguard/peer2/peer2.conf"
```

## Architecture réseau

```
Internet
    |
    | Port UDP 51820
    |
[Serveur Cloud - 94.237.10.48]
    |
    | VPN Wireguard
    |
[Subnet VPN - 10.13.13.0/24]
    |
    +-- 10.13.13.1 (Serveur VPN)
    +-- 10.13.13.2 (Votre machine)
    +-- 10.13.13.3 (Autre peer)
    |
[Réseau Docker - llm-network]
    |
    +-- ollama:11434
    +-- open-webui:8080
    +-- caddy:80/443
    +-- paddleocr-vl-api:8080
```

## Logs et monitoring

```bash
# Logs du conteneur Wireguard
docker logs -f wireguard-vpn

# Statistiques en temps réel
docker exec wireguard-vpn wg show

# Voir les peers connectés
docker exec wireguard-vpn wg show wg0 peers
```
