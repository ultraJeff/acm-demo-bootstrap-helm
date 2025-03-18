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
    local reading=false
    
    while IFS= read -r line; do
        if [[ $reading == true ]]; then
            # Stop if we hit the next key
            if [[ $line =~ ^[A-Z_]+=.*$ ]]; then
                break
            fi
            # Append the line
            value+="$line\n"
        elif [[ $line == "$key="* ]]; then
            # Start reading from the first line after the key
            reading=true
            value+="${line#*=}\n"
        fi
    done
    
    # Remove trailing newline
    value=${value%$'\n'}
    echo "$value"
}

# Process each key
while IFS='=' read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    
    # Get the key
    key=${line%%=*}
    [[ -z "$key" ]] && continue
    
    # Read the full value for this key
    value=$(read_value "$key" < .env)
    
    # Map .env keys to values.yaml paths
    case "$key" in
        "AWS_REGION")
            yq -i ".aws.region = \"$value\"" values.yaml
            ;;
        "AWS_ACCESS_KEY")
            yq -i ".aws.credentials.accessKey = \"$value\"" values.yaml
            ;;
        "AWS_SECRET_KEY")
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
            # Remove surrounding quotes if present
            value=${value#\"}
            value=${value%\"}
            value=${value#\'}
            value=${value%\'}
            echo "$value" | yq -i '.auth.pullSecret = load("/dev/stdin")' values.yaml
            ;;
        "SSH_PRIVATE_KEY")
            # Preserve newlines for SSH keys
            yq -i ".auth.sshPrivateKey = \"$value\"" values.yaml
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
