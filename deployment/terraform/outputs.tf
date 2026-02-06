# ============================================
# Network Outputs
# ============================================

output "private_network_id" {
  description = "Private network UUID"
  value       = upcloud_network.private.id
}

output "private_network_cidr" {
  description = "Private network CIDR"
  value       = var.private_network_cidr
}

output "router_id" {
  description = "Router UUID"
  value       = upcloud_router.main.id
}

output "nat_gateway_id" {
  description = "NAT Gateway UUID (provides internet access to private network)"
  value       = upcloud_gateway.nat.id
}

# ============================================
# Bastion Server Outputs
# ============================================

output "bastion_id" {
  description = "Bastion server UUID"
  value       = upcloud_server.bastion.id
}

output "bastion_hostname" {
  description = "Bastion server hostname"
  value       = upcloud_server.bastion.hostname
}

output "bastion_public_ip" {
  description = "Bastion public IPv4 address (for SSH access)"
  value       = upcloud_server.bastion.network_interface[0].ip_address
}

output "bastion_private_ip" {
  description = "Bastion private IP address"
  value       = var.bastion_private_ip
}

# ============================================
# LLM Server Outputs
# ============================================

output "llm_server_id" {
  description = "LLM Server UUID"
  value       = upcloud_server.main.id
}

output "llm_server_hostname" {
  description = "LLM Server hostname"
  value       = upcloud_server.main.hostname
}

output "llm_server_private_ip" {
  description = "LLM Server private IP address"
  value       = var.llm_server_private_ip
}

# ============================================
# Load Balancer Outputs
# ============================================

output "loadbalancer_id" {
  description = "Load balancer UUID"
  value       = upcloud_loadbalancer.main.id
}

output "loadbalancer_dns_name" {
  description = "Load balancer DNS name (use for CNAME)"
  value       = upcloud_loadbalancer.main.dns_name
}

output "loadbalancer_frontend" {
  description = "Load balancer HTTPS frontend"
  value       = "https://${upcloud_loadbalancer.main.dns_name}"
}

# ============================================
# Connection Commands
# ============================================

output "ssh_bastion_command" {
  description = "SSH command to connect to bastion"
  value       = "ssh llmadmin@${upcloud_server.bastion.network_interface[0].ip_address}"
}

output "zz_ssh_to_llm_server" {
  description = "SSH command to connect to LLM server via bastion (ProxyJump)"
  value       = "ssh -J llmadmin@${upcloud_server.bastion.network_interface[0].ip_address} llmadmin@${var.llm_server_private_ip}"
}

output "ssh_config_entry" {
  description = "SSH config entry for easy access"
  value       = <<-EOT

    # Add this to your ~/.ssh/config for easy access:

    Host llm-bastion
        HostName ${upcloud_server.bastion.network_interface[0].ip_address}
        User llmadmin
        ForwardAgent yes

    Host llm-server
        HostName ${var.llm_server_private_ip}
        User llmadmin
        ProxyJump llm-bastion
        ForwardAgent yes

    # Then simply use: ssh llm-server
  EOT
}

# ============================================
# Service URLs
# ============================================

output "webui_url" {
  description = "Open WebUI URL (via load balancer)"
  value       = "https://${var.domain_name}"
}

# ============================================
# Monitoring Commands
# ============================================

output "monitor_cloud_init_command" {
  description = "Command to monitor cloud-init progress on LLM server"
  value       = "ssh -J llmadmin@${upcloud_server.bastion.network_interface[0].ip_address} llmadmin@${var.llm_server_private_ip} 'tail -f /var/log/cloud-init-output.log'"
}

output "monitor_services_command" {
  description = "Command to monitor services on LLM server"
  value       = "ssh -J llmadmin@${upcloud_server.bastion.network_interface[0].ip_address} llmadmin@${var.llm_server_private_ip} 'journalctl -u llm-provider.service -f'"
}
