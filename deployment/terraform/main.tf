terraform {
  required_version = ">= 1.0"

  required_providers {
    upcloud = {
      source  = "UpCloudLtd/upcloud"
      version = "~> 5.0"
    }
  }
}

# Configure the UpCloud Provider
provider "upcloud" {
  # You can set credentials via environment variables:
  # export UPCLOUD_USERNAME="your-username"
  # export UPCLOUD_PASSWORD="your-password"
}

# Variables
variable "server_hostname" {
  description = "Hostname for the LLM provider server"
  type        = string
  default     = "llm-provider-01"
}

variable "zone" {
  description = "UpCloud zone to deploy to"
  type        = string
  default     = "de-fra1" # Frankfurt
  # Other options: nl-ams1 (Amsterdam), uk-lon1 (London), us-nyc1 (New York), etc.
}

variable "ssh_public_key" {
  description = "SSH public key for server access"
  type        = string
  # Set via: export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_rsa.pub)"
}

variable "server_plan" {
  description = "Server plan (size)"
  type        = string
  default     = "16xCPU-64GB" # Recommended for 120B model
  # Options: 8xCPU-32GB, 16xCPU-64GB, 20xCPU-96GB, etc.
}

variable "storage_size" {
  description = "Storage size in GB"
  type        = number
  default     = 250 # 250GB for model + OS + logs
}

# Data source for Ubuntu image
data "upcloud_storage" "ubuntu" {
  type = "template"
  name = "Ubuntu Server 24.04 LTS (Noble Numbat)"
}

# Create SSH key resource
resource "upcloud_ssh_key" "llm_provider_key" {
  name       = "llm-provider-key"
  public_key = var.ssh_public_key
}

# Network configuration
resource "upcloud_network" "llm_network" {
  name = "llm-provider-network"
  zone = var.zone

  ip_network {
    address = "10.0.0.0/24"
    dhcp    = true
    family  = "IPv4"
  }
}

# Firewall rules
resource "upcloud_firewall_rules" "llm_provider_firewall" {
  server_id = upcloud_server.llm_provider.id

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
    comment                = "Allow HTTPS"
    destination_port_end   = "443"
    destination_port_start = "443"
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
    action   = "accept"
    comment  = "Allow outbound traffic"
    direction = "out"
    family   = "IPv4"
  }

  # Default deny
  firewall_rule {
    action    = "drop"
    comment   = "Deny all other traffic"
    direction = "in"
    family    = "IPv4"
  }
}

# Server resource
resource "upcloud_server" "llm_provider" {
  hostname = var.server_hostname
  zone     = var.zone
  plan     = var.server_plan

  # Cloud-init configuration
  user_data = file("${path.module}/../upcloud/cloud-init.yml")

  # Update the SSH key in cloud-init with the actual key
  metadata = true

  template {
    storage = data.upcloud_storage.ubuntu.id
    size    = var.storage_size

    # Use high-performance MaxIOPS storage
    tier = "maxiops"
  }

  # Network interface
  network_interface {
    type = "public"
  }

  network_interface {
    type              = "private"
    network           = upcloud_network.llm_network.id
    ip_address_family = "IPv4"
  }

  # Login configuration
  login {
    user = "root"
    keys = [
      upcloud_ssh_key.llm_provider_key.public_key
    ]
    create_password   = false
    password_delivery = "none"
  }

  # Labels for organization
  labels = {
    environment = "production"
    service     = "llm-provider"
    model       = "gpt-oss-120b"
    managed_by  = "terraform"
  }
}

# Outputs
output "server_id" {
  description = "The ID of the server"
  value       = upcloud_server.llm_provider.id
}

output "public_ipv4" {
  description = "The public IPv4 address"
  value       = upcloud_server.llm_provider.network_interface[0].ip_address
}

output "private_ipv4" {
  description = "The private IPv4 address"
  value       = upcloud_server.llm_provider.network_interface[1].ip_address
}

output "hostname" {
  description = "The hostname of the server"
  value       = upcloud_server.llm_provider.hostname
}

output "api_endpoint" {
  description = "The Ollama API endpoint"
  value       = "http://${upcloud_server.llm_provider.network_interface[0].ip_address}:11434"
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh root@${upcloud_server.llm_provider.network_interface[0].ip_address}"
}

output "monitoring_commands" {
  description = "Commands to monitor the deployment"
  value = <<-EOT
    # Monitor cloud-init progress:
    ssh root@${upcloud_server.llm_provider.network_interface[0].ip_address} 'tail -f /var/log/cloud-init-output.log'

    # Check service status:
    ssh root@${upcloud_server.llm_provider.network_interface[0].ip_address} 'systemctl status llm-provider.service'

    # View Ollama logs:
    ssh root@${upcloud_server.llm_provider.network_interface[0].ip_address} 'docker logs -f ollama-provider'

    # Test the API:
    curl http://${upcloud_server.llm_provider.network_interface[0].ip_address}:11434/api/tags
  EOT
}
