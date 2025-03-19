# ACM Demo Bootstrap

This repo contains everything needed to spin up the Red Hat ACM Demo. You will need to replace the template variables in various files with your own data!

> TODO: Add GitOps Applications and sync waves to deploy this stuff

1. Run `./update-values.sh` first to set all of the template variables.
2. Run `./aws-setup.sh` next to create the S3 bucket for Observability and an EKS cluster (comment this out if not needed)
3. 