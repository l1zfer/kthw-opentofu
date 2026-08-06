#!/bin/bash
set -euo pipefail

REPO_ROOT="/root/kthw-opentofu"
TF_DIR="$REPO_ROOT/opentofu"
INVENTORY_FILE="$REPO_ROOT/ansible/inventory/hosts.ini"
STATE_TMP="/tmp/kthw-state.tfstate"

cd "$TF_DIR"

# Get the state in JSON once
STATE_JSON=$(tofu state pull 2>/dev/null || echo "")

if [ -n "$STATE_JSON" ] && [ "$STATE_JSON" != "null" ]; then
    # Extract the backend from the state
    BACKEND_BUCKET=$(echo "$STATE_JSON" | jq -r '.backend.config.bucket // ""')
    BACKEND_KEY=$(echo "$STATE_JSON" | jq -r '.backend.config.key // ""')
    REGION=$(echo "$STATE_JSON" | jq -r '.backend.config.region // ""')
fi

# Fallback to the backend.tf file if the backend is not found in the state
if [ -z "$BACKEND_BUCKET" ] || [ "$BACKEND_BUCKET" = "null" ]; then
    echo "State is empty or no backend configured. Reading from backend.tf..."
    BACKEND_BUCKET=$(grep -E 'bucket\s*=\s*"[^"]+"' backend.tf | head -1 | cut -d'"' -f2)
    BACKEND_KEY=$(grep -E 'key\s*=\s*"[^"]+"' backend.tf | head -1 | cut -d'"' -f2)
    REGION=$(grep -E 'region\s*=\s*"[^"]+"' backend.tf | head -1 | cut -d'"' -f2)
fi

# Information checks
if [ -z "$BACKEND_BUCKET" ] || [ -z "$BACKEND_KEY" ] || [ -z "$REGION" ]; then
    echo "Error: Unable to determine the S3 backend. Check backend.tf."
    exit 1
fi

# Downloads state from S3
if ! aws s3 cp "s3://$BACKEND_BUCKET/$BACKEND_KEY" "$STATE_TMP" --region "$REGION" 2>/dev/null; then
    echo "Unable to download state from S3. Using local state (if it exists)."
    if [ -f "$TF_DIR/terraform.tfstate" ]; then
        cp "$TF_DIR/terraform.tfstate" "$STATE_TMP"
    else
        echo "Error: No state available (local or remote). Run 'tofu apply' first."
        exit 1
    fi
fi

# Generate the inventory
cat > "$INVENTORY_FILE" << EOF
[all:vars]
ansible_user=admin
ansible_ssh_private_key_file=/root/.ssh/kthw_key.pem

[k8s_nodes]
$(jq -r '.resources[] | select(.type=="aws_instance") | .instances[].attributes.tags.Name as $name | .instances[].attributes.private_ip as $ip | "\($name) ansible_host=\($ip)"' "$STATE_TMP")

[control_plane]
server

[workers]
node-0
node-1
EOF

echo "Inventory generated in $INVENTORY_FILE"