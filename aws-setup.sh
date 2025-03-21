#!/bin/bash

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

# if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_REGION" ] || [ -z "$GUID" ]; then
#     echo "Error: Required environment variables are not set"
#     echo "Please make sure AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, and GUID are set in the .env file"
#     exit 1
# fi
# Create EKS cluster
# CLUSTER_NAME="eks-cluster-${GUID}"
# echo "Creating EKS cluster: $CLUSTER_NAME (this may take several minutes)..."
# aws eks create-cluster \
#     --name "$CLUSTER_NAME" \
#     --region "$AWS_REGION" \
#     --role-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/eksClusterRole" \
#     --resources-vpc-config subnetIds="$(aws ec2 describe-subnets --filters "Name=default-for-az,Values=true" --query "Subnets[0:2].SubnetId" --output text | tr '\t' ',')",securityGroupIds="$(aws ec2 describe-security-groups --filters "Name=group-name,Values=default" --query "SecurityGroups[0].GroupId" --output text)" || {
#         echo "EKS cluster creation failed."
#         echo "Please make sure you have the necessary IAM roles and permissions."
#         echo "You may need to create an IAM role named 'eksClusterRole' with the 'AmazonEKSClusterPolicy' policy attached."
#         exit 1
#     }

# echo "Waiting for EKS cluster to be active..."
# aws eks wait cluster-active \
#     --name "$CLUSTER_NAME" \
#     --region "$AWS_REGION"

# echo "Setup completed successfully!"
# echo "S3 bucket created: $BUCKET_NAME"
# echo "EKS cluster created: $CLUSTER_NAME"

# # Configure kubectl to use the new cluster
# echo "Configuring kubectl to use the new cluster..."
# aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

# echo "You can now use kubectl to interact with your EKS cluster"

