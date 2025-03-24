#!/bin/bash

# kube-context-switch.sh
# A script to easily switch between Kubernetes contexts, specifically
# between OpenShift and EKS clusters

# Define colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# OpenShift context
# TODO: Add context to .env
OPENSHIFT_CONTEXT="default/api-cluster-574pr-574pr-sandbox1390-opentlc-com:6443/admin"

# Function to display script usage
show_usage() {
  echo -e "${BLUE}USAGE:${NC}"
  echo -e "  ${CYAN}./kube-context-switch.sh${NC} [command]"
  echo
  echo -e "${BLUE}COMMANDS:${NC}"
  echo -e "  ${CYAN}list${NC}           List all available contexts"
  echo -e "  ${CYAN}current${NC}        Show current active context"
  echo -e "  ${CYAN}use-eks${NC}        Switch to EKS cluster context"
  echo -e "  ${CYAN}use-openshift${NC}  Switch to OpenShift cluster context"
  echo -e "  ${CYAN}help${NC}           Show this help message"
  echo
  echo -e "${BLUE}EXAMPLES:${NC}"
  echo -e "  ${CYAN}./kube-context-switch.sh list${NC}"
  echo -e "  ${CYAN}./kube-context-switch.sh use-eks${NC}"
}

# Function to list all available contexts
list_contexts() {
  echo -e "${BLUE}Available Kubernetes contexts:${NC}"
  echo

  # Get current context for highlighting
  CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null)
  
  # List all contexts with proper formatting
  kubectl config get-contexts | while read -r line; do
    if [[ $line == *"$CURRENT_CONTEXT"* ]] && [[ $line != *"CURRENT"* ]]; then
      echo -e "${GREEN}$line${NC} ${YELLOW}(current)${NC}"
    else
      echo "$line"
    fi
  done
}

# Function to show current context
show_current_context() {
  CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null)
  
  if [ -z "$CURRENT_CONTEXT" ]; then
    echo -e "${RED}No active Kubernetes context found.${NC}"
    exit 1
  fi
  
  echo -e "${BLUE}Current context:${NC} ${GREEN}$CURRENT_CONTEXT${NC}"
  
  # Determine if it's OpenShift or EKS
  if [[ "$CURRENT_CONTEXT" == *"$OPENSHIFT_CONTEXT"* ]]; then
    echo -e "${PURPLE}Type:${NC} OpenShift"
  elif [[ "$CURRENT_CONTEXT" == *"eks"* ]]; then
    echo -e "${PURPLE}Type:${NC} EKS"
  else
    echo -e "${PURPLE}Type:${NC} Other Kubernetes cluster"
  fi
}

# Function to switch to EKS context
use_eks_context() {
  echo -e "${BLUE}Searching for EKS contexts...${NC}"
  
  # Find EKS contexts
  EKS_CONTEXTS=($(kubectl config get-contexts -o name | grep -i eks))
  
  if [ ${#EKS_CONTEXTS[@]} -eq 0 ]; then
    echo -e "${RED}No EKS contexts found.${NC}"
    echo -e "Please make sure you have configured access to an EKS cluster."
    exit 1
  elif [ ${#EKS_CONTEXTS[@]} -eq 1 ]; then
    # If only one EKS context is found, use it
    EKS_CONTEXT=${EKS_CONTEXTS[0]}
    echo -e "${BLUE}Switching to EKS context:${NC} ${GREEN}$EKS_CONTEXT${NC}"
    kubectl config use-context "$EKS_CONTEXT"
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Successfully switched to EKS context.${NC}"
    else
      echo -e "${RED}Failed to switch to EKS context.${NC}"
      exit 1
    fi
  else
    # If multiple EKS contexts are found, list them and ask the user to specify
    echo -e "${YELLOW}Multiple EKS contexts found:${NC}"
    for i in "${!EKS_CONTEXTS[@]}"; do
      echo -e "${CYAN}$((i+1)).${NC} ${EKS_CONTEXTS[$i]}"
    done
    
    echo -e "${YELLOW}Please run the command with the specific context:${NC}"
    echo -e "${CYAN}kubectl config use-context <context-name>${NC}"
  fi
}

# Function to switch to OpenShift context
use_openshift_context() {
  echo -e "${BLUE}Switching to OpenShift context:${NC} ${GREEN}$OPENSHIFT_CONTEXT${NC}"
  
  # Check if the OpenShift context exists
  if ! kubectl config get-contexts -o name | grep -q "$OPENSHIFT_CONTEXT"; then
    echo -e "${RED}OpenShift context not found.${NC}"
    echo -e "Please make sure you are logged into OpenShift using 'oc login'."
    exit 1
  fi
  
  # Switch to OpenShift context
  kubectl config use-context "$OPENSHIFT_CONTEXT"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully switched to OpenShift context.${NC}"
  else
    echo -e "${RED}Failed to switch to OpenShift context.${NC}"
    exit 1
  fi
}

# Main script logic
case "$1" in
  "list")
    list_contexts
    ;;
  "current")
    show_current_context
    ;;
  "use-eks")
    use_eks_context
    ;;
  "use-openshift")
    use_openshift_context
    ;;
  "help")
    show_usage
    ;;
  *)
    if [ -z "$1" ]; then
      echo -e "${YELLOW}No command provided.${NC}"
    else
      echo -e "${RED}Unknown command:${NC} $1"
    fi
    show_usage
    exit 1
    ;;
esac

exit 0

