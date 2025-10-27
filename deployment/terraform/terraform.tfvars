# UpCloud LLM Provider Configuration

# ============================================
# Infrastructure Configuration
# ============================================

hostname     = "llm-provider"
zone         = "fi-hel2"
plan         = "GPU-12xCPU-128GB-1xL40S"
storage_size = 200
storage_tier = "maxiops"
backup_plan  = "daily"
backup_time  = "0200"

# ============================================
# Application Configuration (.env variables)
# ============================================

# Ollama
ollama_port              = 11434
ollama_origins           = "*"
ollama_keep_alive        = "-1"
ollama_max_loaded_models = 1
ollama_load_timeout      = "10m"

# Model
model_name          = "gpt-oss:120b"
model_pull_on_start = true

# API
api_timeout = 600
log_level   = "info"

# Open WebUI
webui_port        = 3000
webui_name        = "LLM Chat"
enable_signup     = true
default_user_role = "pending"
webui_auth        = true

# HTTPS
domain_name = "sahlu.dev"
acme_email  = "pablo.mollier@gmail.com"
