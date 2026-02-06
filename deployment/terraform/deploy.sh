#!/bin/bash
set -e

# ============================================
# LLM Provider - Terraform Deploy Script
# Private Network Architecture with Bastion + Load Balancer
# ============================================

CERT_RESOURCE="upcloud_loadbalancer_dynamic_certificate_bundle.main"

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

show_architecture() {
    echo ""
    echo "============================================"
    echo "Network Architecture"
    echo "============================================"
    echo ""
    echo "  Internet"
    echo "     │"
    echo "     └──→ Load Balancer (HTTPS:443) ──→ [Private Network] ──→ LLM Server"
    echo "            │"
    echo "            └── TLS termination (lb-llm-certs)"
    echo ""
    echo "     Bastion (SSH:22) ──→ [Private Network] ──→ LLM Server"
    echo ""
    echo "Security:"
    echo "  - LLM Server: No public IP, private network only"
    echo "  - Bastion: SSH only (port 22), fail2ban protection"
    echo "  - Load Balancer: HTTPS only, TLS certificate"
    echo "  - Caddy: API key authentication (X-API-Key header)"
    echo ""
    echo "============================================"
    echo ""
}

import_certificate() {
    CERT_UUID="${TF_VAR_lb_certificate_uuid:-0a2766b9-d622-4483-ba96-e020a32ba45a}"

    if terraform state list 2>/dev/null | grep -q "$CERT_RESOURCE"; then
        echo "✓ Certificate already in state"
    else
        echo "→ Importing existing certificate $CERT_UUID..."
        terraform import "$CERT_RESOURCE" "$CERT_UUID" || {
            echo "⚠ Import failed (certificate may not exist yet or already managed)"
        }
    fi
}

remove_certificate_from_state() {
    if terraform state list 2>/dev/null | grep -q "$CERT_RESOURCE"; then
        echo "→ Removing certificate from state (preserving in UpCloud)..."
        terraform state rm "$CERT_RESOURCE"
        echo "✓ Certificate removed from state (will persist in UpCloud)"
    fi
}

case "$1" in
    init)
        show_architecture
        terraform init
        ;;
    plan)
        show_architecture
        import_certificate
        terraform plan
        ;;
    apply)
        show_architecture
        import_certificate
        terraform apply
        ;;
    destroy)
        show_architecture
        echo "⚠️  Destroying infrastructure..."
        echo ""
        remove_certificate_from_state
        terraform destroy
        echo ""
        echo "✅ Infrastructure destroyed (certificate preserved)"
        echo "   To recreate: ./deploy.sh apply"
        ;;
    output)
        terraform output
        ;;
    ssh-bastion)
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
    state-list)
        terraform state list
        ;;
    import-cert)
        import_certificate
        ;;
    *)
        echo "Usage: ./deploy.sh {init|plan|apply|destroy|output|ssh-bastion|ssh-llm|state-list|import-cert}"
        echo ""
        echo "Commands:"
        echo "  init        Initialize Terraform"
        echo "  plan        Show execution plan (imports certificate if needed)"
        echo "  apply       Create/update infrastructure (imports certificate if needed)"
        echo "  destroy     Destroy infrastructure (preserves certificate)"
        echo "  output      Show infrastructure details"
        echo "  ssh-bastion Connect to bastion server"
        echo "  ssh-llm     Connect to LLM server via bastion"
        echo "  state-list  List resources in Terraform state"
        echo "  import-cert Manually import the certificate"
        exit 1
        ;;
esac
