output "server_id" {
  description = "Server UUID"
  value       = upcloud_server.main.id
}

output "hostname" {
  description = "Server hostname"
  value       = upcloud_server.main.hostname
}

output "ipv4_address" {
  description = "Public IPv4 address"
  value       = upcloud_server.main.network_interface[0].ip_address
}

output "ipv6_address" {
  description = "Public IPv6 address"
  value       = upcloud_server.main.network_interface[2].ip_address
}

output "ssh_command" {
  description = "SSH connection command"
  value       = "ssh root@${upcloud_server.main.network_interface[0].ip_address}"
}

output "ollama_api_url" {
  description = "Ollama API endpoint"
  value       = "http://${upcloud_server.main.network_interface[0].ip_address}:11434"
}

output "webui_url" {
  description = "Open WebUI URL"
  value       = "http://${upcloud_server.main.network_interface[0].ip_address}:3000"
}

output "monitor_command" {
  description = "Command to monitor cloud-init progress"
  value       = "ssh root@${upcloud_server.main.network_interface[0].ip_address} 'tail -f /var/log/cloud-init-output.log'"
}
