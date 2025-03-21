#!/bin/bash

# Check if .env exists
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    exit 1
fi

# Function to read a key's value until the next key or EOF
read_value() {
    local key=$1
    local value=""
    local line
    local first=true
    local reading=false
    
    while IFS= read -r line; do
        if [[ $reading == true ]]; then
            # Stop if we hit the next key
            if [[ $line =~ ^[A-Z_]+=.*$ ]]; then
                break
            fi
            # Add newline before appending if not the first line
            if [[ $first == false ]]; then
                value+=$'\n'
            fi
            value+="$line"
            first=false
        elif [[ $line == "$key="* ]]; then
            # Start reading from the first line after the key
            reading=true
            value+="${line#*=}"
            first=false
        fi
    done
    
    echo "$value"
}

# Process each key
while IFS='=' read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    # Get the key
    key=${line%%=*}
    key=${key%%[[:space:]]}  # Remove trailing spaces
    [[ -z "$key" ]] && continue
    
    # Read the full value for this key
    value=$(read_value "$key" < .env)
    
    # Remove quotes if present
    value=${value#\"}
    value=${value%\"}
    value=${value#\'}
    value=${value%\'}
    
    # Map .env keys to values.yaml paths
    case "$key" in
        "GUID")
            yq -i ".global.guid = \"$value\"" values.yaml
            ;;
        "BUCKET_NAME")
            yq -i ".aws.bucket.name = \"$value\"" values.yaml
            ;;
        "AWS_ACCESS_KEY_ID")
            yq -i ".aws.credentials.accessKey = \"$value\"" values.yaml
            ;;
        "AWS_SECRET_ACCESS_KEY")
            yq -i ".aws.credentials.secretKey = \"$value\"" values.yaml
            ;;
        "AWS_BASE_DOMAIN")
            yq -i ".aws.baseDomain = \"$value\"" values.yaml
            ;;
        "CLUSTER_NAME")
            yq -i ".cluster.name = \"$value\"" values.yaml
            ;;
        "CLUSTER_NAMESPACE")
            yq -i ".cluster.namespace = \"$value\"" values.yaml
            ;;
        "PULL_SECRET")
            # Handle JSON pull secret
            echo "$value" | yq -i '.auth.pullSecret = load("/dev/stdin")' values.yaml
            ;;
        "SSH_PRIVATE_KEY")
            # Handle base64 encoded SSH private key
            echo "$value" | base64 -d | yq -i '.auth.sshPrivateKey = load("/dev/stdin")' values.yaml
            ;;
        "SSH_PUBLIC_KEY")
            yq -i ".auth.sshPublicKey = \"$value\"" values.yaml
            ;;
        "OWNER_TAG")
            yq -i ".tags.owner = \"$value\"" values.yaml
            ;;
    esac
done < .env

echo "Values updated successfully!"
