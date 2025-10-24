terraform {
  required_version = ">= 1.0"

  required_providers {
    upcloud = {
      source  = "UpCloudLtd/upcloud"
      version = "~> 5.0"
    }
  }

  # Optional: Configure remote backend for state management
  # Uncomment and configure for production use
  # backend "s3" {
  #   bucket = "my-terraform-state"
  #   key    = "llm-provider/terraform.tfstate"
  #   region = "us-east-1"
  # }

  # Or use UpCloud Object Storage
  # backend "s3" {
  #   bucket                      = "my-terraform-state"
  #   key                         = "llm-provider/terraform.tfstate"
  #   endpoint                    = "s3-eu-west-1.upcloud.com"
  #   region                      = "eu-west-1"
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  # }
}
