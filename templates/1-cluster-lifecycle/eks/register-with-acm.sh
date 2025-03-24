#!/bin/bash

# ============================================================================
# register-with-acm.sh
# 
# Description: This script registers an EKS cluster with OpenShift Advanced Cluster Management (ACM)
#              by applying the register-cluster-acm.yaml configuration file and 
#              generating the required import commands for the EKS cluster.
# 
# Usage: ./register-with-acm.sh [kubeconfig-path]
# ============================================================================

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YAML_FILE="${SCRIPT_DIR}/register-cluster-acm.yaml"
CLUSTER_NAME="eks-cluster"
IMPORT_DIR="${SCRIPT_DIR}/import-manifests"
EKS_KUBECONFIG="${1:-$KUBECONFIG}"

# Text formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== EKS Cluster OpenShift ACM Registration ===${NC}"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in the PATH${NC}"
    echo "Please install kubectl before running this script"
    exit 1
fi

# Check if the YAML file exists
if [ ! -f "${YAML_FILE}" ]; then
    echo -e "${RED}Error: YAML file not found: ${YAML_FILE}${NC}"
    echo "Please ensure the register-cluster-acm.yaml file exists in the same directory as this script"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed or not in the PATH${NC}"
    echo "Please install AWS CLI before running this script"
    exit 1
fi
# Check if OpenShift CLI (oc) is installed
if ! command -v oc &> /dev/null; then
    echo -e "${YELLOW}Warning: OpenShift CLI (oc) is not installed or not in the PATH${NC}"
    echo "The script will continue with kubectl, but oc is recommended for OpenShift ACM operations"
fi

# Create directory for import manifests
mkdir -p "${IMPORT_DIR}"

echo -e "${YELLOW}Switching to OpenShift context and applying ACM registration YAML...${NC}"

# Apply the ManagedCluster YAML file to the OpenShift ACM hub
if kubectl apply -f "${YAML_FILE}"; then
    echo -e "${GREEN}Successfully applied ManagedCluster configuration to ACM!${NC}"
else
    echo -e "${RED}Failed to apply ManagedCluster configuration${NC}"
    echo "Please check the error message above and ensure you have access to the OpenShift cluster"
    exit 1
fi

echo -e "${YELLOW}Generating import manifests for the EKS cluster...${NC}"

# Check if the namespace already exists and wait for it to be created/active
echo "Checking if namespace ${CLUSTER_NAME} exists..."
if kubectl get namespace ${CLUSTER_NAME} &>/dev/null; then
    echo "Namespace ${CLUSTER_NAME} already exists. Checking status..."
else
    echo "Namespace ${CLUSTER_NAME} does not exist yet. Waiting for it to be created..."
fi

echo "Waiting for namespace ${CLUSTER_NAME} to be active (timeout: 120s)..."
MAX_RETRIES=12
RETRY_INTERVAL=10
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if kubectl get namespace ${CLUSTER_NAME} -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Active"; then
        echo -e "${GREEN}Namespace ${CLUSTER_NAME} is now active!${NC}"
        break
    else
        echo "Waiting for namespace ${CLUSTER_NAME} to become active... (Attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
        sleep $RETRY_INTERVAL
        RETRY_COUNT=$((RETRY_COUNT+1))
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}Timed out waiting for namespace ${CLUSTER_NAME} to become active.${NC}"
    echo "Current namespace status: $(kubectl get namespace ${CLUSTER_NAME} -o jsonpath='{.status.phase}' 2>/dev/null || echo "Not found")"
    echo "Check ACM hub logs for more information:"
    echo "  kubectl logs -n open-cluster-management deployment/cluster-manager --tail=100"
    exit 1
fi

# Generate the import command for the EKS cluster
echo "Generating cluster import manifests..."

# Check if there's any secret containing "import" in the eks-cluster namespace
# and wait if it's not found (ACM might still be creating it)
echo "Looking for import secret in namespace ${CLUSTER_NAME}..."
MAX_SECRET_RETRIES=12
SECRET_RETRY_INTERVAL=10
SECRET_RETRY_COUNT=0

while [ $SECRET_RETRY_COUNT -lt $MAX_SECRET_RETRIES ]; do
    if command -v oc &> /dev/null; then
        IMPORT_SECRET=$(oc get secret -n ${CLUSTER_NAME} 2>/dev/null | grep -i import | awk '{print $1}' | head -1)
    else
        IMPORT_SECRET=$(kubectl get secret -n ${CLUSTER_NAME} 2>/dev/null | grep -i import | awk '{print $1}' | head -1)
    fi
    
    if [ -n "$IMPORT_SECRET" ]; then
        echo -e "${GREEN}Found import secret: $IMPORT_SECRET${NC}"
        break
    else
        echo "Import secret not found yet... (Attempt $((SECRET_RETRY_COUNT+1))/$MAX_SECRET_RETRIES)"
        echo "Waiting ${SECRET_RETRY_INTERVAL} seconds for ACM to create the import secret..."
        sleep $SECRET_RETRY_INTERVAL
        SECRET_RETRY_COUNT=$((SECRET_RETRY_COUNT+1))
    fi
done

if [ $SECRET_RETRY_COUNT -eq $MAX_SECRET_RETRIES ]; then
    echo -e "${RED}Timed out waiting for import secret in namespace ${CLUSTER_NAME}.${NC}"
    echo "Please check if the ManagedCluster resource was properly created:"
    echo "  kubectl get managedcluster ${CLUSTER_NAME} -o yaml"
    echo "And check the ACM hub logs for more information:"
    echo "  kubectl logs -n open-cluster-management deployment/cluster-manager --tail=100"
    exit 1
fi

# Extract the import manifest with improved error handling
echo "Extracting import manifest from secret ${IMPORT_SECRET}..."
IMPORT_FILE="${IMPORT_DIR}/import.yaml"

if command -v oc &> /dev/null; then
    # Use OpenShift CLI if available
    if ! oc get secret -n ${CLUSTER_NAME} ${IMPORT_SECRET} -o jsonpath='{.data.import\.yaml}' 2>/dev/null | base64 -d > "${IMPORT_FILE}"; then
        # Try alternative key names if the standard one doesn't work
        if ! oc get secret -n ${CLUSTER_NAME} ${IMPORT_SECRET} -o jsonpath='{.data.crds\.yaml}' 2>/dev/null | base64 -d > "${IMPORT_FILE}"; then
            echo -e "${YELLOW}Couldn't find standard import data keys. Listing available keys in secret:${NC}"
            oc get secret -n ${CLUSTER_NAME} ${IMPORT_SECRET} -o jsonpath='{.data}' | jq
            exit 1
        fi
    fi
else
    # Fallback to kubectl
    if ! kubectl get secret -n ${CLUSTER_NAME} ${IMPORT_SECRET} -o jsonpath='{.data.import\.yaml}' 2>/dev/null | base64 -d > "${IMPORT_FILE}"; then
        # Try alternative key names if the standard one doesn't work
        if ! kubectl get secret -n ${CLUSTER_NAME} ${IMPORT_SECRET} -o jsonpath='{.data.crds\.yaml}' 2>/dev/null | base64 -d > "${IMPORT_FILE}"; then
            echo -e "${YELLOW}Couldn't find standard import data keys. Dumping secret structure:${NC}"
            kubectl get secret -n ${CLUSTER_NAME} ${IMPORT_SECRET} -o yaml
            exit 1
        fi
    fi
fi

# Check if the import manifest was generated successfully
if [ ! -s "${IMPORT_FILE}" ]; then
    echo -e "${RED}Failed to generate import manifest for the EKS cluster${NC}"
    echo "The import manifest file was created but is empty."
    echo "Please ensure ACM is properly configured and the cluster registration was successful"
    exit 1
fi

echo -e "${GREEN}Import manifest successfully extracted to ${IMPORT_FILE}${NC}"

echo -e "${GREEN}Successfully generated import manifest!${NC}"

# Apply the import manifest to the EKS cluster
echo -e "${YELLOW}Now applying the import manifest to the EKS cluster...${NC}"

# Save current context to return to it later
CURRENT_CONTEXT=$(kubectl config current-context)

if [ -n "${EKS_KUBECONFIG}" ]; then
    # Temporarily switch kubeconfig to EKS cluster
    echo "Switching to EKS cluster context..."
    if kubectl --kubeconfig="${EKS_KUBECONFIG}" apply -f "${IMPORT_DIR}/import.yaml"; then
        echo -e "${GREEN}Successfully applied import manifest to EKS cluster!${NC}"
    else
        echo -e "${RED}Failed to apply import manifest to EKS cluster${NC}"
        echo "Please check the error message above and ensure the EKS cluster is accessible"
        # Switch back to original context
        kubectl config use-context "${CURRENT_CONTEXT}"
        exit 1
    fi
    
    # Switch back to original context
    kubectl config use-context "${CURRENT_CONTEXT}"
else
    echo -e "${YELLOW}EKS kubeconfig not provided.${NC}"
    echo -e "To complete the registration, please manually apply the generated import manifest to your EKS cluster:"
    echo -e "kubectl apply -f ${IMPORT_DIR}/import.yaml"
fi

echo -e "${BLUE}=== Registration process complete ===${NC}"
echo -e "You can check the status of the registration by running:"
echo -e "  kubectl get managedclusters"
echo -e "  kubectl get managedclusteraddons -n ${CLUSTER_NAME}"
echo -e "\nThe import manifest has been saved to: ${IMPORT_DIR}/import.yaml"

exit 0
