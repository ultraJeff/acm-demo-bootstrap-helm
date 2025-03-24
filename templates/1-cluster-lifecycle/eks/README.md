# EKS Cluster Creation and OpenShift ACM Registration

> NOTE: Make sure to have eks-secret set up first. `oc create secret generic eks-secret --from-file=.dockerconfigjson=pull-secret.txt --type=kubernetes.io/dockerconfigjson`

This directory contains scripts and configuration files needed to create a minimal Amazon EKS (Elastic Kubernetes Service) cluster and register it with OpenShift Advanced Cluster Management (ACM) for centralized management.

## Purpose

The purpose of these scripts is to automate the process of:
1. Creating a minimal EKS cluster in AWS
2. Registering the newly created EKS cluster with OpenShift Advanced Cluster Management
3. Enabling necessary add-ons for cluster management

This setup provides a foundation for multi-cluster management using OpenShift ACM, allowing for centralized governance, application deployment, and monitoring across multiple Kubernetes clusters.

## Prerequisites

Before using these scripts, ensure you have the following installed and configured:

- AWS CLI (with appropriate credentials configured)
- `eksctl` command-line tool
- `kubectl` command-line tool
- Access to an AWS account with permissions to create EKS clusters
- Access to an OpenShift cluster with Advanced Cluster Management (ACM) installed
- `oc` command-line tool (OpenShift CLI)

## Files in this Directory

### 1. `create-eks-cluster.sh`

A bash script that creates a minimal EKS cluster named "eks-cluster".

**Key features:**
- Checks if the cluster already exists before attempting creation
- Creates a minimal cluster with 2 t3.medium nodes (min 1, max 3)
- Updates kubeconfig for immediate kubectl access
- Uses the AWS region from your AWS CLI configuration (defaults to us-east-1)

### 2. `register-cluster-acm.yaml`

A YAML configuration file that defines the necessary Kubernetes resources to register the EKS cluster with OpenShift ACM.

**Contains:**
- `ManagedCluster` resource defining the cluster to be registered
- Labels and annotations for proper integration with OpenShift ACM
- Configuration for enabling various ACM features like:
  - Application lifecycle management
  - Policy enforcement
  - Search capabilities
  - Observability
  - Governance and risk

### 3. `register-with-acm.sh`

A bash script that applies the `register-cluster-acm.yaml` configuration to register the EKS cluster with OpenShift ACM, generating the necessary manifests to connect the EKS cluster back to the OpenShift ACM hub.

**Key features:**
- Validates prerequisites (kubectl, oc, AWS CLI)
- Switches between OpenShift context (for ACM hub operations) and EKS context (for agent installation)
- Creates the necessary resources in the OpenShift ACM hub
- Generates a unique registration command to be executed on the EKS cluster
- Applies the agent manifests to the EKS cluster to complete the registration
- Provides verification commands and next steps

## Step-by-Step Usage Instructions

### Creating the EKS Cluster

1. Ensure you have AWS credentials configured:
   ```bash
   aws configure
   ```

2. Make the script executable (if not already):
   ```bash
   chmod +x create-eks-cluster.sh
   ```

3. Run the cluster creation script:
   ```bash
   ./create-eks-cluster.sh
   ```

4. Wait for the cluster creation to complete (this may take 15-20 minutes).

5. Verify the cluster was created successfully:
   ```bash
   eksctl get cluster
   kubectl get nodes
   ```

### Registering the Cluster with OpenShift ACM

1. First, ensure you have access to both your OpenShift cluster (with ACM installed) and your EKS cluster:
   ```bash
   # List available contexts
   kubectl config get-contexts
   
   # Ensure you can switch between contexts
   kubectl config use-context <your-openshift-context>
   kubectl config use-context <your-eks-context>
   ```

2. Make the registration script executable (if not already):
   ```bash
   chmod +x register-with-acm.sh
   ```

3. Run the registration script which will:
   - Create resources in the OpenShift ACM hub
   - Generate registration manifests
   - Apply the manifests to the EKS cluster
   ```bash
   ./register-with-acm.sh
   ```

4. Verify the registration process from the OpenShift ACM hub:
   ```bash
   # Switch to OpenShift context if not already there
   kubectl config use-context <your-openshift-context>
   
   # Check if the managed cluster is registered
   oc get managedclusters
   
   # Check cluster status
   oc get managedclusters eks-cluster -o jsonpath='{.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status}'
   ```

5. Log in to the OpenShift web console and navigate to the ACM dashboard to confirm the EKS cluster appears and is properly connected.

## Troubleshooting

### EKS Cluster Creation Issues

- If cluster creation fails with permission errors, verify your AWS credentials have the necessary permissions.
- If you encounter networking errors, check your VPC and subnet configurations.
- For other errors, check the eksctl logs for detailed information.

### OpenShift ACM Registration Issues

- If registration fails, ensure the EKS cluster is running and accessible via kubectl.
- Check that your kubeconfig entries for both OpenShift and EKS contexts are valid.
- Verify the OpenShift ACM operator is properly installed and running:
  ```bash
  oc get pods -n open-cluster-management
  ```
- Check that your user has sufficient permissions in both clusters.
- If needed, check the logs of the registration process:
  ```bash
  # On the EKS cluster
  kubectl logs -n open-cluster-management-agent deploy/klusterlet
  
  # On the OpenShift cluster
  oc logs -n open-cluster-management deploy/multicluster-operators-hub-controller
  ```
- If the cluster shows as "Pending" in ACM, verify that the klusterlet agent was successfully deployed on the EKS cluster:
  ```bash
  kubectl get pods -n open-cluster-management-agent
  ```

## Cleanup

To properly clean up the resources:

1. First, detach the EKS cluster from OpenShift ACM:
   ```bash
   # Switch to OpenShift context
   kubectl config use-context <your-openshift-context>
   
   # Delete the managed cluster from ACM
   oc delete managedcluster eks-cluster
   ```

2. Then delete the EKS cluster:
   ```bash
   eksctl delete cluster --name eks-cluster
   ```

Note: This will delete the entire EKS cluster and all workloads running on it. Make sure to back up any important data before proceeding.
