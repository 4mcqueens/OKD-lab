# ── Cluster Identity ────────────────────────────────────────────────────────
variable "cluster_name" {
  description = "OKD cluster name (used in DNS and resource naming)"
  type        = string
  default     = "okd-prod"
}

variable "base_domain" {
  description = "Base DNS domain for the cluster (e.g. example.com)"
  type        = string
}

variable "environment" {
  description = "Environment label (e.g. lab, prod)"
  type        = string
  default     = "lab"
}

# ── AWS Region / AZs ────────────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "List of AZs to spread nodes across (must be 3)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# ── VPC Networking ───────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (LBs, NAT GWs, bastion)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets (OKD nodes)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway instead of one per AZ (reduces cost for lab use)"
  type        = bool
  default     = true
}

# ── EC2 Instance Types ───────────────────────────────────────────────────────
variable "master_instance_type" {
  description = "EC2 instance type for master+worker nodes"
  type        = string
  default     = "m5.2xlarge"
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
  default     = "t3.small"
}

variable "bootstrap_instance_type" {
  description = "EC2 instance type for the bootstrap node (temporary)"
  type        = string
  default     = "m5.large"
}

# ── Storage ──────────────────────────────────────────────────────────────────
variable "master_root_volume_size" {
  description = "Root EBS volume size (GB) for master nodes"
  type        = number
  default     = 120
}

variable "master_etcd_volume_size" {
  description = "Dedicated etcd EBS volume size (GB) for master nodes"
  type        = number
  default     = 100
}

# ── SSH Access ───────────────────────────────────────────────────────────────
variable "ssh_public_key" {
  description = "SSH public key to install on the bastion host"
  type        = string
}

variable "bastion_allowed_cidr" {
  description = "CIDR block allowed to SSH to the bastion host"
  type        = string
  default     = "0.0.0.0/0" # Restrict this to your IP in production
}
