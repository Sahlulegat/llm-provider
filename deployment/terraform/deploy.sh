#!/bin/bash
set -e

# ============================================
# LLM Provider - Terraform Deploy Script
# Private Network Architecture with Bastion + Load Balancer
# ============================================

# Load UpCloud credentials from root .env
if [ -f "../../.env" ]; then
    set -a
    source ../../.env
    set +a
    echo "✓ Loaded UpCloud credentials from .env"
else
    echo "⚠ Warning: ../../.env not found"
    echo "Please ensure UPCLOUD_USERNAME and UPCLOUD_PASSWORD are exported"
fi

# Check credentials are set
if [ -z "$UPCLOUD_USERNAME" ] || [ -z "$UPCLOUD_PASSWORD" ]; then
    echo "❌ Error: UPCLOUD_USERNAME and UPCLOUD_PASSWORD must be set"
    echo ""
    echo "Add them to your root .env file:"
    echo "  UPCLOUD_USERNAME=your-api-username"
    echo "  UPCLOUD_PASSWORD=your-api-password"
    exit 1
fi

echo "✓ UpCloud credentials configured"
echo ""

# Show architecture info
show_architecture() {
    echo ""
    echo "============================================"
    echo "Network Architecture"
    echo "============================================"
    echo ""
    echo "  Internet"
    echo "     │"
    echo "     ├──→ Load Balancer (HTTP/HTTPS) ──→ [Private Network] ──→ LLM Server"
    echo "     │"
    echo "     └──→ Bastion (SSH only) ──→ [Private Network] ──→ LLM Server"
    echo ""
    echo "Security:"
    echo "  - LLM Server: No public IP, only accessible via private network"
    echo "  - Bastion: SSH only (port 22), with fail2ban protection"
    echo "  - Load Balancer: HTTP (80) and HTTPS (443) only"
    echo "  - All other traffic blocked by firewall"
    echo ""
    echo "============================================"
    echo ""
}

# Run terraform command
case "$1" in
    init)
        show_architecture
        terraform init
        ;;
    plan)
        show_architecture
        terraform plan
        ;;
    apply)
        show_architecture
        terraform apply
        ;;
    destroy)
        show_architecture
        echo "⚠️  Destroying infrastructure..."
        echo ""
        terraform destroy
        echo ""
        echo "✅ Infrastructure destroyed"
        echo "   To recreate: ./deploy.sh apply"
        ;;
    output)
        terraform output
        ;;
    ssh-bastion)
        # Quick SSH to bastion
        BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null)
        if [ -n "$BASTION_IP" ]; then
            echo "Connecting to bastion at $BASTION_IP..."
            ssh llmadmin@$BASTION_IP
        else
            echo "❌ Could not get bastion IP. Run './deploy.sh output' to check."
            exit 1
        fi
        ;;
    ssh-llm)
        # Quick SSH to LLM server via bastion
        BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null)
        LLM_IP=$(terraform output -raw llm_server_private_ip 2>/dev/null)
        if [ -n "$BASTION_IP" ] && [ -n "$LLM_IP" ]; then
            echo "Connecting to LLM server at $LLM_IP via bastion $BASTION_IP..."
            ssh -J llmadmin@$BASTION_IP llmadmin@$LLM_IP
        else
            echo "❌ Could not get server IPs. Run './deploy.sh output' to check."
            exit 1
        fi
        ;;
    *)
        echo "Usage: ./deploy.sh {init|plan|apply|destroy|output|ssh-bastion|ssh-llm}"
        echo ""
        echo "Commands:"
        echo "  init        Initialize Terraform"
        echo "  plan        Show execution plan"
        echo "  apply       Create/update infrastructure"
        echo "  destroy     Destroy infrastructure"
        echo "  output      Show infrastructure details"
        echo "  ssh-bastion Connect to bastion server"
        echo "  ssh-llm     Connect to LLM server via bastion"
        exit 1
        ;;
esac
