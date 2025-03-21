# ACM Demo Bootstrap

This repo contains everything needed to spin up the Red Hat ACM Demo. You will need to replace the template variables in various files with your own data!

> TODO: Add GitOps Applications and sync waves to deploy this stuff

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
SSH_PUBLIC_KEY
PULL_SECRET # Make sure this is base64 encoded string
OWNER_TAG
CLUSTER_NAME
CLUSTER_NAMESPACE
```


1. Run `./update-values.sh` first to set all of the template variables.
2. Run `./aws-setup.sh` next to create the S3 bucket for Observability and an EKS cluster (comment this out if not needed)
3. For `1-cluster-lifecycle`, most names are managed through values.yaml file. If you are installing a SNO cluster, then you won't need to change anything, but if you are installing a different type of cluster, you will need to create a new install config secret file similar to `single-node-cluster-install-config.yaml` and reference that name in values.yaml instead.
4. Run `helm install --dry-run=server . --generate-name --debug > helm-crds/yamls.yaml` to generate the CRDs that you can use to `oc apply` with. (Remove the variables section first TODO: Change this instruction to remove the variables section automatically)