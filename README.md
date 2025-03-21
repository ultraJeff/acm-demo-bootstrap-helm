# ACM Demo Bootstrap

This repo contains everything needed to spin up the Red Hat ACM Demo. You will need to replace the template variables in various files with your own data!

> TODO: Add GitOps Applications and sync waves to deploy this stuff

1. **WIP** Run `./update-values.sh` first to set all of the template variables.
2. Run `./aws-setup.sh` next to create the S3 bucket for Observability and an EKS cluster (comment this out if not needed)
3. For `1-cluster-lifecycle`, most names are managed through values.yaml file. If you are installing a SNO cluster, then you won't need to change anything, but if you are installing a different type of cluster, you will need to create a new install config secret file similar to `single-node-cluster-install-config.yaml` and reference that name in values.yaml instead.