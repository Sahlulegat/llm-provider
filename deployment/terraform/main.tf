terraform {
  required_providers {
    upcloud = {
      source  = "UpCloudLtd/upcloud"
      version = "~> 2.0"
    }
  }
}

provider "upcloud" {}

# ============================================
# Private Network (SDN)
# ============================================

resource "upcloud_network" "private" {
  name = "${var.hostname}-private-network"
  zone = var.zone

  ip_network {
    address            = var.private_network_cidr
    dhcp               = true
    dhcp_default_route = false
    family             = "IPv4"
    gateway            = cidrhost(var.private_network_cidr, 1)
  }
}

# ============================================
# Bastion / Jump Server
# ============================================

resource "upcloud_server" "bastion" {
  hostname = "${var.hostname}-bastion"
  title    = "${var.hostname}-bastion"
  zone     = var.zone
  plan     = var.bastion_plan
  firewall = true
  metadata = true

  login {
    user            = "llmadmin"
    keys            = var.ssh_public_keys
    create_password = false
  }

  user_data = templatefile("${path.module}/../upcloud/cloud-init-bastion.yml", {
    llm_server_private_ip = var.llm_server_private_ip
  })

  template {
    storage = "Ubuntu Server 24.04 LTS (Noble Numbat)"
    size    = 25
  }

  # Public network for SSH access
  network_interface {
    type              = "public"
    ip_address_family = "IPv4"
  }

  # Utility network (UpCloud internal)
  network_interface {
    type              = "utility"
    ip_address_family = "IPv4"
  }

  # Private network to reach LLM server
  network_interface {
    type       = "private"
    network    = upcloud_network.private.id
    ip_address = var.bastion_private_ip
  }
}

# Bastion firewall - only SSH from anywhere
resource "upcloud_firewall_rules" "bastion" {
  server_id = upcloud_server.bastion.id

  firewall_rule {
    action                 = "accept"
    comment                = "Allow SSH"
    destination_port_end   = "22"
    destination_port_start = "22"
    direction              = "in"
    family                 = "IPv4"
    protocol               = "tcp"
  }

  # Drop all other incoming traffic
  firewall_rule {
    action    = "drop"
    comment   = "Drop all other incoming TCP (IPv4)"
    direction = "in"
    family    = "IPv4"
    protocol  = "tcp"
  }

  firewall_rule {
    action    = "drop"
    comment   = "Drop all other incoming UDP (IPv4)"
    direction = "in"
    family    = "IPv4"
    protocol  = "udp"
  }
}

# ============================================
# LLM Server (Private Network Only)
# ============================================

resource "upcloud_server" "main" {
  hostname = var.hostname
  title    = var.hostname
  zone     = var.zone
  plan     = var.plan
  firewall = true
  metadata = true

  login {
    user            = "llmadmin"
    keys            = var.ssh_public_keys
    create_password = false
  }

  user_data = templatefile("${path.module}/../upcloud/cloud-init.yml", {
    ollama_port               = var.ollama_port
    ollama_origins            = var.ollama_origins
    ollama_keep_alive         = var.ollama_keep_alive
    ollama_max_loaded_models  = var.ollama_max_loaded_models
    ollama_load_timeout       = var.ollama_load_timeout
    model_name                = var.model_name
    model_pull_on_start       = var.model_pull_on_start
    api_timeout               = var.api_timeout
    log_level                 = var.log_level
    webui_port                = var.webui_port
    webui_name                = var.webui_name
    enable_signup             = var.enable_signup
    default_user_role         = var.default_user_role
    webui_auth                = var.webui_auth
    domain_name               = var.domain_name
    acme_email                = var.acme_email
    inactivity_timeout        = var.inactivity_timeout
    allowed_ips               = var.allowed_ips
    bastion_private_ip        = var.bastion_private_ip
    private_network_cidr      = var.private_network_cidr
  })

  template {
    storage = "Ubuntu Server 24.04 LTS (with NVIDIA drivers & CUDA)"
    size    = var.storage_size
  }

  # Utility network (UpCloud internal) - required for metadata
  network_interface {
    type              = "utility"
    ip_address_family = "IPv4"
  }

  # Private network only - no public IP
  network_interface {
    type       = "private"
    network    = upcloud_network.private.id
    ip_address = var.llm_server_private_ip
  }

  simple_backup {
    plan = var.backup_plan
    time = var.backup_time
  }

  depends_on = [upcloud_network.private]
}

# LLM Server firewall - only allow traffic from private network
resource "upcloud_firewall_rules" "main" {
  server_id = upcloud_server.main.id

  # Allow SSH from bastion (private network)
  firewall_rule {
    action                 = "accept"
    comment                = "Allow SSH from private network"
    destination_port_end   = "22"
    destination_port_start = "22"
    direction              = "in"
    family                 = "IPv4"
    protocol               = "tcp"
    source_address_end     = cidrhost(var.private_network_cidr, 254)
    source_address_start   = cidrhost(var.private_network_cidr, 1)
  }

  # Allow HTTP from load balancer (private network)
  firewall_rule {
    action                 = "accept"
    comment                = "Allow HTTP from load balancer"
    destination_port_end   = "80"
    destination_port_start = "80"
    direction              = "in"
    family                 = "IPv4"
    protocol               = "tcp"
    source_address_end     = cidrhost(var.private_network_cidr, 254)
    source_address_start   = cidrhost(var.private_network_cidr, 1)
  }

  # Allow HTTPS from load balancer (private network)
  firewall_rule {
    action                 = "accept"
    comment                = "Allow HTTPS from load balancer"
    destination_port_end   = "443"
    destination_port_start = "443"
    direction              = "in"
    family                 = "IPv4"
    protocol               = "tcp"
    source_address_end     = cidrhost(var.private_network_cidr, 254)
    source_address_start   = cidrhost(var.private_network_cidr, 1)
  }

  # Drop all other incoming traffic
  firewall_rule {
    action    = "drop"
    comment   = "Drop all other incoming TCP (IPv4)"
    direction = "in"
    family    = "IPv4"
    protocol  = "tcp"
  }

  firewall_rule {
    action    = "drop"
    comment   = "Drop all other incoming UDP (IPv4)"
    direction = "in"
    family    = "IPv4"
    protocol  = "udp"
  }

  firewall_rule {
    action    = "drop"
    comment   = "Drop all other incoming TCP (IPv6)"
    direction = "in"
    family    = "IPv6"
    protocol  = "tcp"
  }

  firewall_rule {
    action    = "drop"
    comment   = "Drop all other incoming UDP (IPv6)"
    direction = "in"
    family    = "IPv6"
    protocol  = "udp"
  }
}

# ============================================
# Load Balancer
# ============================================

resource "upcloud_loadbalancer" "main" {
  name              = "${var.hostname}-lb"
  plan              = var.loadbalancer_plan
  zone              = var.zone
  configured_status = "started"

  networks {
    name   = "Public"
    type   = "public"
    family = "IPv4"
  }

  networks {
    name    = "Private"
    type    = "private"
    family  = "IPv4"
    network = upcloud_network.private.id
  }

}

# Frontend - HTTPS (port 443)
resource "upcloud_loadbalancer_frontend" "https" {
  loadbalancer         = upcloud_loadbalancer.main.id
  name                 = "https-frontend"
  mode                 = "tcp"
  port                 = 443
  default_backend_name = upcloud_loadbalancer_backend.https.name

  networks {
    name = "Public"
  }
}

# Frontend - HTTP (port 80) - redirect to HTTPS or direct access
resource "upcloud_loadbalancer_frontend" "http" {
  loadbalancer         = upcloud_loadbalancer.main.id
  name                 = "http-frontend"
  mode                 = "tcp"
  port                 = 80
  default_backend_name = upcloud_loadbalancer_backend.http.name

  networks {
    name = "Public"
  }
}

# Backend - HTTPS
resource "upcloud_loadbalancer_backend" "https" {
  loadbalancer = upcloud_loadbalancer.main.id
  name         = "https-backend"
}

# Backend - HTTP
resource "upcloud_loadbalancer_backend" "http" {
  loadbalancer = upcloud_loadbalancer.main.id
  name         = "http-backend"
}

# Backend member - LLM server HTTPS
resource "upcloud_loadbalancer_static_backend_member" "llm_https" {
  backend      = upcloud_loadbalancer_backend.https.id
  name         = "llm-server-https"
  ip           = var.llm_server_private_ip
  port         = 443
  weight       = 100
  max_sessions = 1000
  enabled      = true
}

# Backend member - LLM server HTTP
resource "upcloud_loadbalancer_static_backend_member" "llm_http" {
  backend      = upcloud_loadbalancer_backend.http.id
  name         = "llm-server-http"
  ip           = var.llm_server_private_ip
  port         = 80
  weight       = 100
  max_sessions = 1000
  enabled      = true
}

# ============================================
# DNS Configuration
# ============================================
#
# Use load balancer DNS name with CNAME:
#   llm.yourdomain.com  CNAME  <loadbalancer_dns_name>
