variable "hostname" {
  description = "Server hostname"
  type        = string
  default     = "llm-provider"
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
