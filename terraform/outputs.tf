# ── Cluster Identity ─────────────────────────────────────────────────────────
output "cluster_id" {
  description = "Unique cluster identifier"
  value       = local.cluster_id
}

# ── VPC ──────────────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# ── Load Balancers ───────────────────────────────────────────────────────────
output "api_nlb_ext_dns_name" {
  description = "External API NLB DNS name"
  value       = module.load_balancers.api_nlb_ext_dns_name
}

output "apps_nlb_dns_name" {
  description = "Apps NLB DNS name"
  value       = module.load_balancers.apps_nlb_dns_name
}

# ── DNS ──────────────────────────────────────────────────────────────────────
output "api_url" {
  description = "OKD API endpoint URL"
  value       = "https://api.${var.cluster_name}.${var.base_domain}:6443"
}

output "console_url" {
  description = "OKD web console URL (available after install)"
  value       = "https://console.apps.${var.cluster_name}.${var.base_domain}"
}

output "argocd_url" {
  description = "ArgoCD UI URL (available after GitOps operator install)"
  value       = "https://openshift-gitops-server-openshift-gitops.apps.${var.cluster_name}.${var.base_domain}"
}

# ── EC2 ──────────────────────────────────────────────────────────────────────
output "bastion_public_ip" {
  description = "Bastion host public IP"
  value       = module.ec2.bastion_public_ip
}

output "master_private_ips" {
  description = "Private IPs of master nodes"
  value       = module.ec2.master_private_ips
}

# ── S3 ───────────────────────────────────────────────────────────────────────
output "bootstrap_bucket_name" {
  description = "S3 bucket for bootstrap ignition file"
  value       = module.s3.bootstrap_bucket_name
}

output "image_registry_bucket_name" {
  description = "S3 bucket for OKD image registry"
  value       = module.s3.image_registry_bucket_name
}
