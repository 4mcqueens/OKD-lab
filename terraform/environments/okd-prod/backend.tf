# Remote state — store in S3 so the team shares state
# Create this bucket manually BEFORE running terraform init
terraform {
  backend "s3" {
    bucket         = "okd-lab-tfstate"          # Create this bucket first
    key            = "okd-prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "okd-lab-tfstate-lock"     # For state locking
  }
}
