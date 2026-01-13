# ============================================
# Infrastructure Variables
# ============================================

variable "hostname" {
  description = "Server hostname"
  type        = string
  default     = "llm-provider"
}

variable "ssh_public_key" {
  description = "SSH public key for server access"
  type        = string
  sensitive   = true
}

variable "zone" {
  description = "UpCloud zone (e.g., fi-hel2, de-fra1)"
  type        = string
  default     = "fi-hel2"
}

variable "plan" {
  description = "Server plan (e.g., GPU-12xCPU-128GB-1xL40S)"
  type        = string
  default     = "GPU-12xCPU-128GB-1xL40S"
}

variable "storage_size" {
  description = "Storage size in GB"
  type        = number
  default     = 200
}

variable "storage_tier" {
  description = "Storage tier (maxiops, hdd)"
  type        = string
  default     = "maxiops"
}

variable "backup_plan" {
  description = "Backup plan (daily, weekly, none)"
  type        = string
  default     = "daily"
}

variable "backup_time" {
  description = "Backup time (HHMM format)"
  type        = string
  default     = "0200"
}

# ============================================
# Application Variables (.env)
# ============================================

variable "ollama_port" {
  description = "Ollama API port"
  type        = number
  default     = 11434
}

variable "ollama_origins" {
  description = "Allowed CORS origins for Ollama"
  type        = string
  default     = "*"
}

variable "ollama_keep_alive" {
  description = "Keep model loaded (-1 for indefinitely, or time like 30m)"
  type        = string
  default     = "-1"
}

variable "ollama_max_loaded_models" {
  description = "Maximum number of models to keep loaded"
  type        = number
  default     = 1
}

variable "ollama_load_timeout" {
  description = "Timeout for loading models"
  type        = string
  default     = "10m"
}

variable "model_name" {
  description = "LLM model to use"
  type        = string
  default     = "gpt-oss:120b"
}

variable "model_pull_on_start" {
  description = "Pull model on service start"
  type        = bool
  default     = true
}

variable "api_timeout" {
  description = "API timeout in seconds"
  type        = number
  default     = 600
}

variable "log_level" {
  description = "Logging level"
  type        = string
  default     = "info"
}

variable "webui_port" {
  description = "Open WebUI port"
  type        = number
  default     = 3000
}

variable "webui_name" {
  description = "Open WebUI application name"
  type        = string
  default     = "LLM Chat"
}

variable "enable_signup" {
  description = "Allow user signup (set to false after creating admin)"
  type        = bool
  default     = true
}

variable "default_user_role" {
  description = "Default role for new users (pending, user, admin)"
  type        = string
  default     = "pending"
}

variable "webui_auth" {
  description = "Enable authentication"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Domain name for HTTPS (leave empty for localhost)"
  type        = string
  default     = ""
}

variable "acme_email" {
  description = "Email for Let's Encrypt notifications"
  type        = string
  default     = ""
}
