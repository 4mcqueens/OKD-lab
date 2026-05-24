# ── Cluster Identity ────────────────────────────────────────────────────────
variable "cluster_name" {
  description = "OKD cluster name (used in DNS and resource naming)"
  type        = string
  default     = "okd-lab"
}

variable "base_domain" {
  description = "Base DNS domain for the cluster (e.g. example.com)"
  type        = string
}

variable "environment" {
  description = "Environment label"
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
  description = "List of 3 AZs to spread nodes across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# ── VPC Networking ───────────────────────────────────────────────────────────
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
}

variable "single_nat_gateway" {
  description = "Use one NAT Gateway instead of one per AZ (lab cost saving)"
  type        = bool
  default     = true
}

# ── EC2 ─────────────────────────────────────────────────────────────────────
variable "master_instance_type" {
  description = "EC2 instance type for master+worker nodes — m6a.xlarge is minimum viable for lab"
  type        = string
  default     = "m6a.xlarge"
}

variable "bootstrap_instance_type" {
  description = "EC2 instance type for the temporary bootstrap node"
  type        = string
  default     = "m6a.large"
}

variable "master_root_volume_size" {
  description = "Root EBS volume size (GB) per master node — includes etcd for lab use"
  type        = number
  default     = 100
}

# ── SSH / Access ─────────────────────────────────────────────────────────────
variable "ssh_public_key" {
  description = "SSH public key embedded in ignition config (for core user on FCOS nodes)"
  type        = string
}

variable "installer_allowed_cidr" {
  description = "CIDR of the machine running openshift-install (needs bootstrap API access)"
  type        = string
  default     = "0.0.0.0/0"
}
