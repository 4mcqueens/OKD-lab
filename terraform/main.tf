locals {
  cluster_id = "${var.cluster_name}-${random_id.cluster.hex}"
}

resource "random_id" "cluster" {
  byte_length = 4
}

# ── VPC ─────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  cluster_name         = var.cluster_name
  cluster_id           = local.cluster_id
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
}

# ── Security Groups ──────────────────────────────────────────────────────────
module "security_groups" {
  source = "./modules/security-groups"

  cluster_name           = var.cluster_name
  cluster_id             = local.cluster_id
  vpc_id                 = module.vpc.vpc_id
  vpc_cidr               = var.vpc_cidr
  installer_allowed_cidr = var.installer_allowed_cidr
}

# ── IAM ─────────────────────────────────────────────────────────────────────
module "iam" {
  source = "./modules/iam"

  cluster_name = var.cluster_name
  cluster_id   = local.cluster_id
}

# ── S3 ──────────────────────────────────────────────────────────────────────
module "s3" {
  source = "./modules/s3"

  cluster_id = local.cluster_id
}

# ── Load Balancers ───────────────────────────────────────────────────────────
module "load_balancers" {
  source = "./modules/load-balancers"

  cluster_name       = var.cluster_name
  cluster_id         = local.cluster_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  vpc_id             = module.vpc.vpc_id
}

# ── DNS ─────────────────────────────────────────────────────────────────────
module "dns" {
  source = "./modules/dns"

  cluster_name         = var.cluster_name
  base_domain          = var.base_domain
  vpc_id               = module.vpc.vpc_id
  api_nlb_ext_dns_name = module.load_balancers.api_nlb_ext_dns_name
  api_nlb_ext_zone_id  = module.load_balancers.api_nlb_ext_zone_id
  api_nlb_int_dns_name = module.load_balancers.api_nlb_int_dns_name
  api_nlb_int_zone_id  = module.load_balancers.api_nlb_int_zone_id
  apps_nlb_dns_name    = module.load_balancers.apps_nlb_dns_name
  apps_nlb_zone_id     = module.load_balancers.apps_nlb_zone_id
}

# ── EC2 ─────────────────────────────────────────────────────────────────────
module "ec2" {
  source = "./modules/ec2"

  cluster_name              = var.cluster_name
  cluster_id                = local.cluster_id
  aws_region                = var.aws_region
  availability_zones        = var.availability_zones
  private_subnet_ids        = module.vpc.private_subnet_ids
  public_subnet_ids         = module.vpc.public_subnet_ids
  master_sg_id              = module.security_groups.master_sg_id
  bootstrap_sg_id           = module.security_groups.bootstrap_sg_id
  master_instance_profile   = module.iam.master_instance_profile
  master_instance_type      = var.master_instance_type
  bootstrap_instance_type   = var.bootstrap_instance_type
  master_root_volume_size   = var.master_root_volume_size
  ssh_public_key            = var.ssh_public_key
  bootstrap_ignition_bucket = module.s3.bootstrap_bucket_name
  api_nlb_ext_target_arn    = module.load_balancers.api_nlb_ext_target_arn
  api_nlb_int_target_arn    = module.load_balancers.api_nlb_int_target_arn
  mcs_nlb_int_target_arn    = module.load_balancers.mcs_nlb_int_target_arn
  apps_nlb_http_target_arn  = module.load_balancers.apps_nlb_http_target_arn
  apps_nlb_https_target_arn = module.load_balancers.apps_nlb_https_target_arn
}
