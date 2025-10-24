#!/bin/bash
set -e

# Load UpCloud credentials from root .env
if [ -f "../../.env" ]; then
    export $(grep -E '^UPCLOUD_' ../../.env | xargs)
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

# Run terraform command
case "$1" in
    init)
        terraform init
        ;;
    plan)
        terraform plan
        ;;
    apply)
        terraform apply
        ;;
    destroy)
        terraform destroy
        ;;
    output)
        terraform output
        ;;
    *)
        echo "Usage: ./deploy.sh {init|plan|apply|destroy|output}"
        exit 1
        ;;
esac
