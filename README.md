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
SSH_PUBLIC_KEY # Make sure this is base64 encoded string
PULL_SECRET # Make sure this is base64 encoded string
OWNER_TAG
CLUSTER_NAME
CLUSTER_NAMESPACE
```


1. Run `./update-values.sh` first to set all of the template variables.
> NOTE: **Do not commit your updates to `values.yaml`!** Reset it with `git checkout values.yaml` before committing anything to your own fork.
2. Run `./aws-setup.sh` next to create the S3 bucket for Observability and an EKS cluster (comment this out if not needed)
> NOTE: For `1-cluster-lifecycle`, most names are managed through values.yaml file. If you are installing a SNO cluster, then you won't need to change anything, but if you are installing a different type of cluster, you will need to create a new install config secret file similar to `single-node-cluster-install-config.yaml` and reference that name in values.yaml instead.
3. Run `helm install --dry-run=server . --generate-name --debug > helm-crds/yamls.yaml` to generate the CRDs if you would like to check the output before applying it.
4. Run `helm upgrade --reuse-values <chart-name> .` to install the CRDs.
> NOTE: Use the .helmignore file to exclude certain sections of the demo that you don't want to install.