#!/bin/bash

# TODO: Consider breaking this into aws configure and bucket steps

# Exit on error
set -e

# Source environment variables from .env file
echo "Loading environment variables from .env file..."
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Check if required environment variables are set
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$BUCKET_REGION" ] || [ -z "$GUID" ]; then
    echo "Error: Required environment variables are not set"
    echo "Please make sure AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, BUCKET_REGION, and GUID are set in the .env file"
    exit 1
fi

echo "Using AWS credentials and region from environment variables..."
echo "AWS Region: $BUCKET_REGION"

# Setup aws configure with environment variables
aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws configure set region "$BUCKET_REGION"
aws configure set output "json"

# Create S3 bucket
BUCKET_NAME="grafana-${GUID}"
echo "Creating S3 bucket: $BUCKET_NAME"
aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$BUCKET_REGION" \
    --create-bucket-configuration LocationConstraint="$BUCKET_REGION" || {
        echo "Bucket creation failed. It might already exist or name is not available."
    }