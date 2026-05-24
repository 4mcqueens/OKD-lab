# ── OKD Lab — Environment Configuration ──────────────────────────────────────
# Cost-optimized for intermittent lab use. Everything is destroyed at rest.
# Run ../../../scripts/lab-up.sh and lab-down.sh to manage the cluster.

cluster_name = "okd-lab"
base_domain  = "example.com"      # ← Replace with your Route53 domain
environment  = "lab"

aws_region         = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
single_nat_gateway   = true        # Single NAT GW saves ~$65/mo vs 3×

# ── Compute ──────────────────────────────────────────────────────────────────
# m6a.xlarge = 4 vCPU / 16 GB — minimum viable for OKD compact lab
# Upgrade to m6a.2xlarge (8 vCPU / 32 GB) if workloads need more headroom
master_instance_type    = "m6a.xlarge"
bootstrap_instance_type = "m6a.large"   # Temporary only (~45 min per session)
master_root_volume_size = 100           # Single volume — OS + etcd, ephemeral

# ── Access ────────────────────────────────────────────────────────────────────
ssh_public_key = "ssh-rsa AAAA..."   # ← Replace with your public key

# installer_allowed_cidr controls which IP can reach the bootstrap node (ports 22, 19531).
# lab-up.sh auto-detects the Pi's current public IP at runtime and passes it as a
# -var override, so this fallback value is only used if auto-detection fails.
# Cloudflare DDNS keeps the Pi reachable by hostname; the script resolves it to an IP.
installer_allowed_cidr = "0.0.0.0/0"  # fallback — overridden automatically by lab-up.sh
