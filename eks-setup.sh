#!/bin/bash

# =====================================================
# EKS Cluster Creation Script
# =====================================================
# This script creates an Amazon EKS cluster with proper 
# node group configuration using environment variables.
# 
# It includes:
# - VPC and networking setup
# - IAM role creation
# - EKS cluster deployment
# - Node group configuration
# - Validation and error handling
# =====================================================

set -e

# -----------------------------------------------------
# Color definitions for better readability
# -----------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------
# Load environment variables
# -----------------------------------------------------
function load_environment() {
  echo -e "${BLUE}Loading environment variables...${NC}"

  if [ -f .env ]; then
    echo -e "${GREEN}Found .env file, loading variables${NC}"
    source .env
  else
    echo -e "${RED}No .env file found. Please create one based on .env.example${NC}"
    exit 1
  fi

  # Required variables check
  required_vars=(
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "BUCKET_REGION"
    "GUID"
  )

  for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
      echo -e "${RED}Error: Required environment variable $var is not set.${NC}"
      exit 1
    fi
  done
  
  # Set default values if not provided
  CLUSTER_NAME=${CLUSTER_NAME:-"eks-cluster-${GUID}"}
  AWS_REGION=${BUCKET_REGION}
  KUBERNETES_VERSION=${KUBERNETES_VERSION:-"1.28"}
  NODE_TYPE=${NODE_TYPE:-"t3.medium"}
  NODE_COUNT=${NODE_COUNT:-2}
  NODE_COUNT_MIN=${NODE_COUNT_MIN:-2}
  NODE_COUNT_MAX=${NODE_COUNT_MAX:-4}
  
  echo -e "${GREEN}Environment variables loaded successfully${NC}"
  echo -e "Using cluster name: ${CLUSTER_NAME}"
  echo -e "Using AWS region: ${AWS_REGION}"
}

# -----------------------------------------------------
# Check prerequisites
# -----------------------------------------------------
function check_prerequisites() {
  echo -e "${BLUE}Checking prerequisites...${NC}"
  
  # Check AWS CLI
  if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI is not installed. Please install it first.${NC}"
    exit 1
  fi
  
  # Check eksctl
  if ! command -v eksctl &> /dev/null; then
    echo -e "${RED}eksctl is not installed. Please install it first.${NC}"
    exit 1
  fi
  
  # Check kubectl
  if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}Warning: kubectl is not installed. You will need it to interact with your cluster.${NC}"
  fi
  
  # Verify AWS credentials
  echo -e "Verifying AWS credentials..."
  if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Invalid AWS credentials. Please check your AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}All prerequisites checked successfully${NC}"
}

# -----------------------------------------------------
# Create VPC for EKS if needed
# -----------------------------------------------------
function create_vpc() {
  echo -e "${BLUE}Setting up networking...${NC}"
  
  # Check if we want to use an existing VPC or create a new one
  if [ -n "$VPC_ID" ]; then
    echo -e "Using existing VPC: $VPC_ID"
    
    # Validate the VPC exists
    if ! aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $AWS_REGION &> /dev/null; then
      echo -e "${RED}VPC $VPC_ID does not exist in region $AWS_REGION.${NC}"
      exit 1
    fi
    
    # Get subnet IDs if not provided
    if [ -z "$SUBNET_IDS" ]; then
      echo -e "Getting subnet IDs for VPC $VPC_ID"
      SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text --region $AWS_REGION)
      
      if [ -z "$SUBNET_IDS" ]; then
        echo -e "${RED}No subnets found for VPC $VPC_ID${NC}"
        exit 1
      fi
    fi
  else
    echo -e "No VPC ID provided. Using eksctl to create new VPC."
    # eksctl will create the VPC automatically
  fi
}

# -----------------------------------------------------
# Create IAM roles for EKS
# -----------------------------------------------------
function create_iam_roles() {
  echo -e "${BLUE}Setting up IAM roles...${NC}"
  
  # Create EKS cluster role if not exists
  CLUSTER_ROLE_NAME="eksClusterRole-${GUID}"
  
  # Check if role already exists
  if aws iam get-role --role-name $CLUSTER_ROLE_NAME 2>/dev/null; then
    echo -e "IAM role $CLUSTER_ROLE_NAME already exists. Skipping creation."
  else
    echo -e "Creating IAM role for EKS cluster: $CLUSTER_ROLE_NAME"
    
    # Create trust policy document
    cat > eks-cluster-role-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
    
    # Create the role
    aws iam create-role \
      --role-name $CLUSTER_ROLE_NAME \
      --assume-role-policy-document file://eks-cluster-role-trust-policy.json \
      --region $AWS_REGION
    
    # Attach required policies
    aws iam attach-role-policy \
      --role-name $CLUSTER_ROLE_NAME \
      --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy \
      --region $AWS_REGION
      
    echo -e "${GREEN}Successfully created IAM role for EKS cluster${NC}"
  fi
  
  # Create node group role if not exists
  NODE_ROLE_NAME="eksNodeRole-${GUID}"
  
  # Check if role already exists
  if aws iam get-role --role-name $NODE_ROLE_NAME 2>/dev/null; then
    echo -e "IAM role $NODE_ROLE_NAME already exists. Skipping creation."
  else
    echo -e "Creating IAM role for EKS node group: $NODE_ROLE_NAME"
    
    # Create trust policy document
    cat > eks-node-role-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
    
    # Create the role
    aws iam create-role \
      --role-name $NODE_ROLE_NAME \
      --assume-role-policy-document file://eks-node-role-trust-policy.json \
      --region $AWS_REGION
    
    # Attach required policies
    aws iam attach-role-policy \
      --role-name $NODE_ROLE_NAME \
      --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy \
      --region $AWS_REGION
      
    aws iam attach-role-policy \
      --role-name $NODE_ROLE_NAME \
      --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly \
      --region $AWS_REGION
      
    aws iam attach-role-policy \
      --role-name $NODE_ROLE_NAME \
      --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy \
      --region $AWS_REGION
      
    echo -e "${GREEN}Successfully created IAM role for EKS node group${NC}"
  fi
}

# -----------------------------------------------------
# Create EKS cluster
# -----------------------------------------------------
function create_eks_cluster() {
  echo -e "${BLUE}Creating EKS cluster...${NC}"
  
  # Check if the cluster already exists
  if aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION &>/dev/null; then
    echo -e "${YELLOW}EKS cluster $CLUSTER_NAME already exists.${NC}"
    return 0
  fi
  
  echo -e "Creating new EKS cluster: $CLUSTER_NAME"
  
  # Create cluster configuration file
  cat > eks-cluster-config.yaml << EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_REGION}
  version: "${KUBERNETES_VERSION}"
  tags:
    environment: development
    project: eks-demo
    creator: eks-setup-script
    created-by: eks-setup-script
    guid: ${GUID}

# IAM configuration
iam:
  withOIDC: true
  serviceRoleARN: arn:aws:iam::$(aws sts get-caller-identity --query "Account" --output text):role/${CLUSTER_ROLE_NAME}

# VPC configuration
EOF

  # Add VPC config if using existing VPC
  if [ -n "$VPC_ID" ] && [ -n "$SUBNET_IDS" ]; then
    # Convert space-separated subnet list to YAML array format
    SUBNET_YAML=""
    for subnet in $SUBNET_IDS; do
      SUBNET_YAML+="    - $subnet"$'\n'
    done

    cat >> eks-cluster-config.yaml << EOF
vpc:
  id: "${VPC_ID}"
  subnets:
    private:
${SUBNET_YAML}
EOF
  fi

  # Add node group configuration
  cat >> eks-cluster-config.yaml << EOF
# Node group configuration
nodeGroups:
  - name: ng-1
    instanceType: ${NODE_TYPE}
    desiredCapacity: ${NODE_COUNT}
    minSize: ${NODE_COUNT_MIN}
    maxSize: ${NODE_COUNT_MAX}
    tags:
      nodegroup-role: worker
    iam:
      instanceRoleARN: arn:aws:iam::$(aws sts get-caller-identity --query "Account" --output text):role/${NODE_ROLE_NAME}
    ssh:
      allow: false
    privateNetworking: true
    labels: 
      role: worker
    securityGroups:
      withShared: true
      withLocal: true
    volumeSize: 50
    volumeType: gp3
    updateConfig:
      maxUnavailable: 1

# Enable AWS managed addons
addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
  - name: aws-ebs-csi-driver
    version: latest
EOF

  # Create the cluster using eksctl
  eksctl create cluster -f eks-cluster-config.yaml
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}EKS cluster $CLUSTER_NAME created successfully!${NC}"
  else
    echo -e "${RED}Failed to create EKS cluster $CLUSTER_NAME.${NC}"
    exit 1
  fi
}

# -----------------------------------------------------
# Configure kubectl
# -----------------------------------------------------
function configure_kubectl() {
  echo -e "${BLUE}Configuring kubectl...${NC}"
  
  if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}kubectl not found, skipping configuration...${NC}"
    return
  fi
  
  # Update kubeconfig for the new cluster
  aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}kubectl configured successfully to use $CLUSTER_NAME${NC}"
    
    # Test the connection
    echo -e "Testing connection to the cluster..."
    if kubectl get nodes &> /dev/null; then
      echo -e "${GREEN}Successfully connected to EKS cluster. Current nodes:${NC}"
      kubectl get nodes
    else
      echo -e "${YELLOW}Could not connect to the cluster. You may need to check your AWS IAM permissions.${NC}"
    fi
  else
    echo -e "${YELLOW}Failed to configure kubectl${NC}"
  fi
}

# -----------------------------------------------------
# Clean up temporary files
# -----------------------------------------------------
function cleanup() {
  echo -e "${BLUE}Cleaning up temporary files...${NC}"
  
  rm -f eks-cluster-role-trust-policy.json eks-node-role-trust-policy.json eks-cluster-config.yaml
  
  echo -e "${GREEN}Cleanup complete${NC}"
}

# -----------------------------------------------------
# Main function
# -----------------------------------------------------
function main() {
  echo -e "${BLUE}=========================================${NC}"
  echo -e "${BLUE}   EKS Cluster Setup Script   ${NC}"
  echo -e "${BLUE}=========================================${NC}"
  
  # Execute steps
  load_environment
  check_prerequisites
  create_vpc
  create_iam_roles
  create_eks_cluster
  configure_kubectl
  cleanup
  
  echo -e "${GREEN}=========================================${NC}"
  echo -e "${GREEN}   EKS Cluster Setup Complete!   ${NC}"
  echo -e "${GREEN}=========================================${NC}"
  echo -e "Cluster Name: ${CLUSTER_NAME}"
  echo -e "Region: ${AWS_REGION}"
  echo -e "To interact with your cluster, use: kubectl get nodes"
  echo -e "${GREEN}=========================================${NC}"
}

# Run the script
main "$@"

