# UpCloud Credentials
# Set these via environment variables:
# export UPCLOUD_USERNAME="your-username"
# export UPCLOUD_PASSWORD="your-password"

# Or use a terraform.tfvars file (DO NOT commit this file!)

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "llm-provider"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "production"
}

variable "enable_monitoring" {
  description = "Enable monitoring and alerting"
  type        = bool
  default     = true
}

variable "enable_backups" {
  description = "Enable automatic backups"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "allowed_ssh_ips" {
  description = "List of IP addresses allowed to SSH (empty means all)"
  type        = list(string)
  default     = []
  # Example: ["1.2.3.4/32", "5.6.7.8/32"]
}

variable "allowed_api_ips" {
  description = "List of IP addresses allowed to access the API (empty means all)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
