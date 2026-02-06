# Guide de Connexion - LLM Provider

## Architecture Réseau

```
Internet
    │
    ├──→ Load Balancer (HTTP/HTTPS) ──→ [Réseau Privé 172.30.0.0/24] ──→ LLM Server (172.30.0.20)
    │
    ├──→ Bastion (SSH) ──→ [Réseau Privé] ──→ LLM Server
    │
    └──← NAT Gateway (UpCloud Managed) ←── [Réseau Privé] ←── LLM Server (accès internet sortant)
```

Le **NAT Gateway managé UpCloud** permet au serveur LLM d'accéder à internet (git clone, docker pull, etc.) sans avoir d'IP publique.

## 1. Accès Web (WebUI / API)

Après déploiement, récupère le DNS du load balancer :
```bash
cd deployment/terraform
./deploy.sh output | grep loadbalancer_dns_name
```

Accède à la WebUI via :
- **HTTP** : `http://<loadbalancer_dns_name>`
- **HTTPS** : `https://<ton-domaine>` (si configuré avec CNAME)

### Configuration DNS (OVH ou autre)

Configure un CNAME pointant vers le DNS du load balancer :
```
llm.tondomaine.com  CNAME  lb-xxxxxxxx.upcloud.host.
```

## 2. Accès SSH

### Méthode rapide (via deploy.sh)

```bash
# SSH au bastion
./deploy.sh ssh-bastion

# SSH au serveur LLM (via bastion)
./deploy.sh ssh-llm
```

### Méthode manuelle

```bash
# Récupérer les IPs
./deploy.sh output

# SSH au bastion
ssh llmadmin@<bastion_public_ip>

# SSH au LLM server via ProxyJump
ssh -J llmadmin@<bastion_public_ip> llmadmin@172.30.0.20
```

### Configuration SSH permanente

Ajoute dans `~/.ssh/config` :

```
Host llm-bastion
    HostName <bastion_public_ip>
    User llmadmin
    ForwardAgent yes

Host llm-server
    HostName 172.30.0.20
    User llmadmin
    ProxyJump llm-bastion
    ForwardAgent yes
```

Ensuite, simplement :
```bash
ssh llm-bastion  # bastion
ssh llm-server   # LLM server
```

## 3. Monitoring

### Logs cloud-init (pendant le déploiement)
```bash
ssh llm-server 'tail -f /var/log/cloud-init-output.log'
```

### Status des services
```bash
ssh llm-server 'systemctl status llm-provider'
```

### Logs des containers
```bash
ssh llm-server 'docker logs -f ollama-provider'
ssh llm-server 'docker logs -f open-webui'
```

### GPU
```bash
ssh llm-server 'nvidia-smi'
```

## 4. Ports et Sécurité

| Composant | Port | Accès |
|-----------|------|-------|
| Bastion | 22 (SSH) | Internet → Bastion |
| Load Balancer | 80, 443 | Internet → LB |
| LLM Server | 22 | Bastion → LLM (réseau privé) |
| LLM Server | 80, 443 | LB → LLM (réseau privé) |

Le LLM Server n'a **aucune IP publique**. Tout passe par le bastion (SSH) ou le load balancer (HTTP/S).
