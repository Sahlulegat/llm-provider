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