terraform {
  required_providers {
    upcloud = {
      source  = "UpCloudLtd/upcloud"
      version = "~> 2.0"
    }
  }
}

provider "upcloud" {}

resource "upcloud_server" "main" {
  hostname = var.hostname
  title    = var.hostname
  zone     = var.zone
  plan     = var.plan
  firewall = true
  metadata = true

  # Configure llmadmin user with SSH keys
  login {
    user            = "llmadmin"
    keys            = var.ssh_public_keys
    create_password = false
  }

  # Pass all variables to cloud-init template
  user_data = templatefile("${path.module}/../upcloud/cloud-init.yml", {
    # Application variables for .env file
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
  })
  template {
    storage = "Ubuntu Server 24.04 LTS (with NVIDIA drivers & CUDA)"
    size    = var.storage_size
  }

  network_interface {
    type              = "public"
    ip_address_family = "IPv4"
  }

  network_interface {
    type              = "utility"
    ip_address_family = "IPv4"
  }

  network_interface {
    type              = "public"
    ip_address_family = "IPv6"
  }

  simple_backup {
    plan = var.backup_plan
    time = var.backup_time
  }
}

resource "upcloud_firewall_rules" "main" {
  server_id = upcloud_server.main.id

  firewall_rule {
    action                 = "accept"
    comment                = "Allow SSH"
    destination_port_end   = "22"
    destination_port_start = "22"
    direction              = "in"
    family                 = "IPv4"
    protocol               = "tcp"
  }

  firewall_rule {
    action                 = "accept"
    comment                = "Allow Ollama API"
    destination_port_end   = "11434"
    destination_port_start = "11434"
    direction              = "in"
    family                 = "IPv4"
    protocol               = "tcp"
  }

  firewall_rule {
    action                 = "accept"
    comment                = "Allow Open WebUI"
    destination_port_end   = "3000"
    destination_port_start = "3000"
    direction              = "in"
    family                 = "IPv4"
    protocol               = "tcp"
  }

  firewall_rule {
    action                 = "accept"
    comment                = "Allow HTTP"
    destination_port_end   = "80"
    destination_port_start = "80"
    direction              = "in"
    family                 = "IPv4"
    protocol               = "tcp"
  }

  firewall_rule {
    action                 = "accept"
    comment                = "Allow HTTPS"
    destination_port_end   = "443"
    destination_port_start = "443"
    direction              = "in"
    family                 = "IPv4"
    protocol               = "tcp"
  }
}