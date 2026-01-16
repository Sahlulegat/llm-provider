#!/bin/bash
set -e

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
    echo "Add them to /opt/projects/llm-provider/.env:"
    echo "  UPCLOUD_USERNAME=your-api-username"
    echo "  UPCLOUD_PASSWORD=your-api-password"
    exit 1
fi

echo "✓ UpCloud credentials configured"
echo ""

# Function to check and import floating IP if needed
check_floating_ip_import() {
    # Check if floating IP is configured
    if [ -z "$TF_VAR_floating_ip" ] || [ "$TF_VAR_floating_ip" == "" ]; then
        echo "ℹ No floating IP configured (TF_VAR_floating_ip is empty)"
        return 0
    fi

    echo "✓ Floating IP configured: $TF_VAR_floating_ip"

    # Check if terraform state exists
    if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
        echo "⚠ No terraform state found. Run './deploy.sh init' first."
        return 0
    fi

    # Check if floating IP is already in state
    if terraform state list 2>/dev/null | grep -q "upcloud_floating_ip_address.main"; then
        echo "✓ Floating IP already imported in Terraform state"
        return 0
    fi

    # Import floating IP
    echo ""
    echo "📥 Importing floating IP $TF_VAR_floating_ip into Terraform state..."
    echo "   This is required before first apply to attach the IP to the server."
    echo ""

    if terraform import "upcloud_floating_ip_address.main[0]" "$TF_VAR_floating_ip"; then
        echo "✓ Floating IP successfully imported"
        echo ""
    else
        echo "❌ Failed to import floating IP"
        echo "   Make sure the IP exists in UpCloud and is not already managed by another Terraform state."
        echo ""
        exit 1
    fi
}

# Run terraform command
case "$1" in
    init)
        terraform init
        ;;
    plan)
        check_floating_ip_import
        terraform plan
        ;;
    apply)
        check_floating_ip_import
        terraform apply
        ;;
    destroy)
        echo ""
        echo "⚠️  Destroying infrastructure (keeping floating IP)..."
        echo ""

        # Remove floating IP from Terraform state (prevents destroy attempt)
        if [ -n "$TF_VAR_floating_ip" ] && [ "$TF_VAR_floating_ip" != "" ]; then
            if terraform state list 2>/dev/null | grep -q "upcloud_floating_ip_address.main"; then
                echo "📤 Removing floating IP from Terraform state..."
                terraform state rm 'upcloud_floating_ip_address.main[0]'
                echo "✓ Floating IP $TF_VAR_floating_ip removed from state (will be re-imported on next apply)"
                echo ""
            fi
        fi

        # Now destroy all remaining resources
        terraform destroy

        echo ""
        echo "✅ Infrastructure destroyed"
        if [ -n "$TF_VAR_floating_ip" ] && [ "$TF_VAR_floating_ip" != "" ]; then
            echo "   Floating IP $TF_VAR_floating_ip preserved in UpCloud"
            echo "   (Will be automatically re-imported on next apply)"
        fi
        echo "   To recreate: ./deploy.sh apply"
        ;;
    output)
        terraform output
        ;;
    *)
        echo "Usage: ./deploy.sh {init|plan|apply|destroy|output}"
        exit 1
        ;;
esac