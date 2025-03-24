# ACM Demo Bootstrap

This repo contains everything needed to spin up the Red Hat ACM Demo. You will need to replace the template variables in various files with your own data!

> TODO: Add GitOps Applications and sync waves to deploy this stuff

> TODO: Fix the EKS portion

> TODO: You can use `envsubst` to replace template variables in files. For example, `envsubst < values.yaml > values.yaml.new` will replace all template variables in `values.yaml` with their corresponding values from the environment variables.

First you will want to have a `.env` file in the root of this repo to follow the pattern I've set forth. You will need to replace the template variables in various files with your own data, but here is the list of keys that I used:

```bash
# .env
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
GUID
BUCKET_NAME
BUCKET_REGION
SSH_PRIVATE_KEY # Make sure this is base64 encoded string
SSH_PUBLIC_KEY # Make sure this is base64 encoded string
PULL_SECRET # Make sure this is base64 encoded string
OWNER_TAG
CLUSTER_NAME
CLUSTER_NAMESPACE
```

### Tools Used In This Repo

* [clusteradm](https://github.com/open-cluster-management-io/clusteradm)
* [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/)
* [aws](https://aws.amazon.com/cli/)

> TIP: Use the .helmignore file to exclude certain sections of the demo that you don't want to install.


1. Run `./update-values.sh` first to set all of the template variables.
> NOTE: **Do not commit your updates to `values.yaml`!** Reset it with `git checkout values.yaml` before committing anything to your own fork.
<!-- 2. Run `./aws-setup.sh` next to create the S3 bucket for Observability and an EKS cluster (comment this out if not needed) -->
2. Run `./s3-bucket-setup.sh` next to create the S3 bucket for Observability (this also sources `.env` that will be used by various shell scripts)
3. Run `./eks-setup.sh` next to create the EKS cluster
> NOTE: Use the provided `./kube-context-switch.sh` to switch your kubectl context between the new EKS cluster and the default OpenShift cluster
4. Run `helm upgrade --reuse-values <chart-name> ./templates/00-aws-creds` to install some bootstrapping and then patch the ACM instance with `oc patch multiclusterhub multiclusterhub -n open-cluster-management --type merge -p '{"spec":{"imagePullSecret":"eks-secret"}}'`

## Cluster Lifecycle

> NOTE: EKS might spin up a mix of amd64 and arm64 instances. If you are unable to import your cluster to ACM completely (e.g. not all addons are working, this is likely why!)

Fix might be patching `deployment/cert-policy-controller` in `open-cluster-management-agent` namespace like so (this won't stick, so please find a more permanent solution)

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/arch
          operator: NotIn
          values:
          - arm64
```

> NOTE: For `1-cluster-lifecycle`, most names are managed through values.yaml file. If you are installing a SNO cluster, then you won't need to change anything, but if you are installing a different type of cluster, you will need to create a new install config secret file similar to `single-node-cluster-install-config.yaml` and reference that name in values.yaml instead.

3. Run `helm install --dry-run=server . --generate-name --debug > helm-crds/yamls.yaml` to generate the CRDs if you would like to check the output before applying it.
4. Run `helm upgrade --reuse-values <chart-name> .` to install the CRDs.

## Application Lifecycle

1. Run `./setup-gitops.sh` to install the GitOps Operator and Instance.
2. Run `oc apply -f ./templates/2-application-lifecycle/argo-server` to set up the Argo Server.
3. Run `oc apply -f ./templates/2-application-lifecycle/rocket-chat` to set up the Rocket Chat application.
