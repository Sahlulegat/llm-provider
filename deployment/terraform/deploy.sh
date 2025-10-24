#!/bin/bash

# LLM Provider - Terraform Deployment Helper Script
# This script simplifies common Terraform operations

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

check_terraform() {
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed!"
        echo "Install it from: https://developer.hashicorp.com/terraform/downloads"
        exit 1
    fi
    log_info "Terraform version: $(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)"
}

check_credentials() {
    if [ -z "$UPCLOUD_USERNAME" ] || [ -z "$UPCLOUD_PASSWORD" ]; then
        log_warn "UpCloud credentials not found in environment!"
        echo ""
        echo "Please set:"
        echo "  export UPCLOUD_USERNAME=\"your-username\""
        echo "  export UPCLOUD_PASSWORD=\"your-password\""
        echo ""
        read -p "Do you want to continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_info "UpCloud credentials found"
    fi
}

check_tfvars() {
    if [ ! -f "terraform.tfvars" ]; then
        log_warn "terraform.tfvars not found!"
        if [ -f "terraform.tfvars.example" ]; then
            read -p "Copy from terraform.tfvars.example? [Y/n] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                cp terraform.tfvars.example terraform.tfvars
                log_info "Created terraform.tfvars - please edit it before continuing"
                ${EDITOR:-nano} terraform.tfvars
            fi
        fi
    fi
}

show_help() {
    cat << EOF
${GREEN}LLM Provider - Terraform Deployment Helper${NC}

${BLUE}Usage:${NC}
  $0 [command]

${BLUE}Commands:${NC}
  ${GREEN}init${NC}       Initialize Terraform (first time setup)
  ${GREEN}plan${NC}       Show what will be created/changed
  ${GREEN}deploy${NC}     Deploy the infrastructure
  ${GREEN}status${NC}     Show current infrastructure status
  ${GREEN}output${NC}     Show outputs (IP, endpoints, etc.)
  ${GREEN}destroy${NC}    Destroy the infrastructure (CAUTION!)
  ${GREEN}ssh${NC}        SSH into the server
  ${GREEN}logs${NC}       View server logs
  ${GREEN}test${NC}       Test the API endpoint
  ${GREEN}update${NC}     Update the infrastructure
  ${GREEN}validate${NC}   Validate Terraform configuration
  ${GREEN}help${NC}       Show this help message

${BLUE}Examples:${NC}
  # First time deployment
  $0 init
  $0 plan
  $0 deploy

  # Check status
  $0 status
  $0 output

  # Connect to server
  $0 ssh

  # Update configuration
  nano terraform.tfvars
  $0 update

  # Destroy everything
  $0 destroy

${BLUE}Environment Variables:${NC}
  ${YELLOW}UPCLOUD_USERNAME${NC}  UpCloud API username
  ${YELLOW}UPCLOUD_PASSWORD${NC}  UpCloud API password

${BLUE}Documentation:${NC}
  See ../README.md for full documentation

EOF
}

cmd_init() {
    log_step "Initializing Terraform..."
    check_terraform
    check_credentials
    check_tfvars

    log_info "Running terraform init..."
    terraform init

    log_info "Validating configuration..."
    terraform validate

    echo ""
    log_info "Initialization complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Edit terraform.tfvars with your configuration"
    echo "  2. Run: $0 plan"
    echo "  3. Run: $0 deploy"
}

cmd_plan() {
    log_step "Planning deployment..."
    check_terraform
    check_credentials

    terraform plan

    echo ""
    log_info "Plan complete!"
    echo "To apply this plan, run: $0 deploy"
}

cmd_deploy() {
    log_step "Deploying infrastructure..."
    check_terraform
    check_credentials

    log_warn "This will create real infrastructure and incur costs!"
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi

    log_info "Running terraform apply..."
    terraform apply

    echo ""
    log_info "Deployment complete!"
    echo ""
    echo "View details: $0 output"
    echo "SSH to server: $0 ssh"
    echo "View logs: $0 logs"
    echo "Test API: $0 test"
}

cmd_status() {
    log_step "Checking infrastructure status..."
    check_terraform

    terraform show
}

cmd_output() {
    log_step "Showing outputs..."
    check_terraform

    if terraform output &> /dev/null; then
        terraform output

        echo ""
        log_info "Quick commands:"
        if terraform output -raw public_ipv4 &> /dev/null; then
            IP=$(terraform output -raw public_ipv4)
            echo "  SSH: ssh root@$IP"
            echo "  API: curl http://$IP:11434/api/tags"
        fi
    else
        log_warn "No infrastructure deployed yet"
        echo "Run: $0 deploy"
    fi
}

cmd_destroy() {
    log_step "Destroying infrastructure..."
    check_terraform

    log_error "WARNING: This will permanently delete all infrastructure!"
    log_error "This includes the server, data, and all configurations!"
    echo ""
    read -p "Type 'yes' to confirm destruction: " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Destruction cancelled"
        exit 0
    fi

    log_info "Running terraform destroy..."
    terraform destroy

    log_info "Infrastructure destroyed"
}

cmd_ssh() {
    log_step "Connecting via SSH..."
    check_terraform

    if ! terraform output -raw public_ipv4 &> /dev/null; then
        log_error "No infrastructure deployed"
        exit 1
    fi

    IP=$(terraform output -raw public_ipv4)
    log_info "Connecting to root@$IP..."
    ssh root@$IP
}

cmd_logs() {
    log_step "Viewing server logs..."
    check_terraform

    if ! terraform output -raw public_ipv4 &> /dev/null; then
        log_error "No infrastructure deployed"
        exit 1
    fi

    IP=$(terraform output -raw public_ipv4)

    echo "Which logs to view?"
    echo "  1) Cloud-init logs"
    echo "  2) Service logs (systemd)"
    echo "  3) Docker logs"
    echo "  4) All logs"
    read -p "Choice [1-4]: " choice

    case $choice in
        1)
            log_info "Cloud-init logs:"
            ssh root@$IP 'tail -f /var/log/cloud-init-output.log'
            ;;
        2)
            log_info "Service logs:"
            ssh root@$IP 'journalctl -u llm-provider.service -f'
            ;;
        3)
            log_info "Docker logs:"
            ssh root@$IP 'docker logs -f ollama-provider'
            ;;
        4)
            log_info "Opening multiple log streams..."
            ssh root@$IP 'tail -f /var/log/cloud-init-output.log & journalctl -u llm-provider.service -f & docker logs -f ollama-provider'
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

cmd_test() {
    log_step "Testing API endpoint..."
    check_terraform

    if ! terraform output -raw public_ipv4 &> /dev/null; then
        log_error "No infrastructure deployed"
        exit 1
    fi

    IP=$(terraform output -raw public_ipv4)
    ENDPOINT="http://$IP:11434"

    log_info "Testing connection to $ENDPOINT..."

    # Test health
    log_info "Checking health..."
    if curl -s -f "$ENDPOINT/api/tags" > /dev/null; then
        log_info "✓ API is responding"

        log_info "Available models:"
        curl -s "$ENDPOINT/api/tags" | grep -o '"name":"[^"]*' | cut -d'"' -f4

        echo ""
        log_info "Test generation? [y/N]"
        read -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Generating text..."
            curl -s "$ENDPOINT/api/generate" -d '{
              "model": "gpt-oss:120b",
              "prompt": "Hello!",
              "stream": false
            }' | grep -o '"response":"[^"]*' | cut -d'"' -f4
        fi
    else
        log_error "✗ API is not responding"
        log_warn "The service might still be starting up"
        echo "Check logs with: $0 logs"
    fi
}

cmd_update() {
    log_step "Updating infrastructure..."
    check_terraform
    check_credentials

    log_info "Checking for changes..."
    terraform plan

    echo ""
    read -p "Apply these changes? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply
        log_info "Update complete!"
    else
        log_info "Update cancelled"
    fi
}

cmd_validate() {
    log_step "Validating Terraform configuration..."
    check_terraform

    terraform fmt -check
    terraform validate

    log_info "Configuration is valid!"
}

# Main command dispatcher
case "${1:-}" in
    init)
        cmd_init
        ;;
    plan)
        cmd_plan
        ;;
    deploy)
        cmd_deploy
        ;;
    status)
        cmd_status
        ;;
    output)
        cmd_output
        ;;
    destroy)
        cmd_destroy
        ;;
    ssh)
        cmd_ssh
        ;;
    logs)
        cmd_logs
        ;;
    test)
        cmd_test
        ;;
    update)
        cmd_update
        ;;
    validate)
        cmd_validate
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
