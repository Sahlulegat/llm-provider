terraform {
  required_providers {
    upcloud = {
      source  = "UpCloudLtd/upcloud"
      version = "~> 5.0"
    }
  }
}

provider "upcloud" {}

# ============================================
# Router & NAT Gateway (UpCloud Managed)
# ============================================

resource "upcloud_router" "main" {
  name = "${var.hostname}-router"

  # UpCloud NAT Gateway adds static routes automatically
  # Note: If Terraform tries to remove routes on subsequent applies,
  # you may need to add: lifecycle { ignore_changes = [static_routes] }
  # depending on your provider version
}

resource "upcloud_gateway" "nat" {
  name     = "${var.hostname}-nat-gateway"
  zone     = var.zone
  features = ["nat"]

  router {
    id = upcloud_router.main.id
  }

  labels = {
    managed-by = "terraform"
  }
}

# ============================================
# Private Network (SDN)
# ============================================

resource "upcloud_network" "private" {
  name = "${var.hostname}-private-network"
  zone = var.zone

  ip_network {
    address            = var.private_network_cidr
    dhcp               = true
    dhcp_default_route = true  # Gateway provides default route
    family             = "IPv4"
    gateway            = cidrhost(var.private_network_cidr, 1)
  }

  # Attach network to router for NAT gateway
  router = upcloud_router.main.id
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

# Bastion firewall - SSH only (NAT handled by UpCloud managed gateway)
resource "upcloud_firewall_rules" "bastion" {
  server_id = upcloud_server.bastion.id

  # Allow SSH from anywhere
  firewall_rule {
    action                 = "accept"
    comment                = "Allow SSH"
    destination_port_end   = "22"
    destination_port_start = "22"
    direction              = "in"
    family                 = "IPv4"
    protocol               = "tcp"
  }

  # Drop all other incoming traffic from internet
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
  firewall = false  # Disabled - server is on private network only, no public IP
  metadata = true

  login {
    user            = "llmadmin"
    keys            = var.ssh_public_keys
    create_password = false
  }

  user_data = templatefile("${path.module}/../upcloud/cloud-init.yml", {
    ollama_port              = var.ollama_port
    ollama_origins           = var.ollama_origins
    ollama_keep_alive        = var.ollama_keep_alive
    ollama_max_loaded_models = var.ollama_max_loaded_models
    ollama_load_timeout      = var.ollama_load_timeout
    model_name               = var.model_name
    model_pull_on_start      = var.model_pull_on_start
    api_timeout              = var.api_timeout
    log_level                = var.log_level
    webui_port               = var.webui_port
    webui_name               = var.webui_name
    enable_signup            = var.enable_signup
    default_user_role        = var.default_user_role
    webui_auth               = var.webui_auth
    domain_name              = var.domain_name
    acme_email               = var.acme_email
    llm_gateway_url          = var.llm_gateway_url
    llm_gateway_upstream     = var.llm_gateway_upstream
    llm_gateway_path         = var.llm_gateway_path
    ocr_gateway_path         = var.ocr_gateway_path
    inactivity_timeout       = var.inactivity_timeout
    allowed_ips              = var.allowed_ips
    caddy_api_key            = var.caddy_api_key
    crowdsec_bouncer_key     = var.crowdsec_bouncer_key
    crowdsec_enroll_key      = var.crowdsec_enroll_key
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

  # Wait for NAT gateway to be ready before creating server
  # This ensures internet access is available during cloud-init
  depends_on = [upcloud_network.private, upcloud_gateway.nat]
}

# LLM Server firewall is DISABLED (firewall = false)
# The server is on a private network with no public IP, so:
# - Inbound traffic only comes from bastion (SSH) or load balancer (HTTP/S)
# - Internet access is provided by UpCloud Managed NAT Gateway
# Security is provided by network isolation, not firewall rules

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

resource "upcloud_loadbalancer_backend" "http" {
  loadbalancer = upcloud_loadbalancer.main.id
  name         = "http-backend"

  properties {
    timeout_server = 600
    timeout_tunnel = 600
  }
}

resource "upcloud_loadbalancer_static_backend_member" "llm_http" {
  backend      = upcloud_loadbalancer_backend.http.id
  name         = "llm-server-http"
  ip           = var.llm_server_private_ip
  port         = 80
  weight       = 100
  max_sessions = 1000
  enabled      = true
}

resource "upcloud_loadbalancer_frontend" "https" {
  loadbalancer         = upcloud_loadbalancer.main.id
  name                 = "https-frontend"
  mode                 = "http"
  port                 = 443
  default_backend_name = upcloud_loadbalancer_backend.http.name

  networks {
    name = "Public"
  }
}

resource "upcloud_loadbalancer_frontend_rule" "forwarded_headers" {
  frontend = upcloud_loadbalancer_frontend.https.id
  name     = "set-forwarded-headers"
  priority = 10

  matchers {
    num_members_up {
      backend_name = upcloud_loadbalancer_backend.http.name
      method       = "equal"
      value        = 1
    }
  }

  actions {
    set_forwarded_headers {
      active = true
    }
  }
}

resource "upcloud_loadbalancer_dynamic_certificate_bundle" "main" {
  name      = var.lb_certificate_name
  hostnames = [var.domain_name]
  key_type  = "rsa"

  lifecycle {
    ignore_changes = [hostnames, key_type]
  }
}

resource "upcloud_loadbalancer_frontend_tls_config" "main" {
  frontend           = upcloud_loadbalancer_frontend.https.id
  name               = "tls-config"
  certificate_bundle = upcloud_loadbalancer_dynamic_certificate_bundle.main.id
}
