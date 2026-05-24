# Backend configuration is declared in terraform/versions.tf
# This file is kept for reference only — it is NOT used by Terraform.
#
# The S3 backend uses native file locking (use_lockfile = true, Terraform >= 1.10).
# The DynamoDB table (okd-lab-tfstate-lock) was created in an earlier session but
# is no longer needed for locking; it can be safely deleted.
#
# Run Terraform from: /home/techsup/OKD-lab/terraform/
#   terraform init
#   terraform plan  -var-file=environments/okd-prod/terraform.tfvars
#   terraform apply -var-file=environments/okd-prod/terraform.tfvars
