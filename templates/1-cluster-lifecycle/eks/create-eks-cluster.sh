#!/bin/bash

# Script to create a minimal EKS cluster named eks-cluster
# This script checks if the cluster already exists before attempting to create it

set -e

CLUSTER_NAME="eks-cluster"
REGION=$(aws configure get region || echo "us-east-1")
NODEGROUP_NAME="ng-1"

echo "=== EKS Cluster Creation Script ==="
echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $REGION"

# Check if cluster already exists
echo "Checking if cluster already exists..."
if eksctl get cluster --name $CLUSTER_NAME --region $REGION 2>/dev/null; then
    echo "Cluster '$CLUSTER_NAME' already exists. Skipping creation."
    exit 0
else
    echo "Cluster doesn't exist. Proceeding with creation..."
fi

# Create a minimal EKS cluster
echo "Creating EKS cluster '$CLUSTER_NAME'..."
eksctl create cluster \
    --name $CLUSTER_NAME \
    --region $REGION \
    --node-type t3.medium \
    --nodes 2 \
    --nodes-min 1 \
    --nodes-max 3 \
    --managed \
    --nodegroup-name $NODEGROUP_NAME

# Verify the cluster was created successfully
echo "Verifying cluster..."
if eksctl get cluster --name $CLUSTER_NAME --region $REGION 2>/dev/null; then
    echo "✅ Cluster '$CLUSTER_NAME' has been successfully created!"
    # Update kubeconfig to interact with the cluster
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
    echo "Kubeconfig updated. You can now use 'kubectl' to interact with your cluster."
else
    echo "❌ Failed to create cluster or verify its existence."
    exit 1
fi

echo "Done!"

