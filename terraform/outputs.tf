# ── Cluster Identity ─────────────────────────────────────────────────────────
output "cluster_id" {
  description = "Unique cluster identifier"
  value       = local.cluster_id
}

# ── Networking ───────────────────────────────────────────────────────────────
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

# ── Load Balancers ───────────────────────────────────────────────────────────
output "api_nlb_ext_dns_name" {
  value = module.load_balancers.api_nlb_ext_dns_name
}

output "apps_nlb_dns_name" {
  value = module.load_balancers.apps_nlb_dns_name
}

# ── URLs ─────────────────────────────────────────────────────────────────────
output "api_url" {
  description = "OKD API endpoint"
  value       = "https://api.${var.cluster_name}.${var.base_domain}:6443"
}

output "console_url" {
  description = "OKD web console"
  value       = "https://console.apps.${var.cluster_name}.${var.base_domain}"
}

output "argocd_url" {
  description = "ArgoCD UI (available after GitOps operator install)"
  value       = "https://openshift-gitops-server-openshift-gitops.apps.${var.cluster_name}.${var.base_domain}"
}

# ── Nodes ────────────────────────────────────────────────────────────────────
output "master_private_ips" {
  value = module.ec2.master_private_ips
}

output "master_instance_ids" {
  value = module.ec2.master_instance_ids
}

# ── S3 ───────────────────────────────────────────────────────────────────────
output "bootstrap_bucket_name" {
  value = module.s3.bootstrap_bucket_name
}

output "image_registry_bucket_name" {
  value = module.s3.image_registry_bucket_name
}
