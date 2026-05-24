#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# lab-down.sh — Tear down the entire OKD lab to zero cost
#
# Usage:  ./scripts/lab-down.sh [--force]
#
# Destroys: ALL AWS resources (EC2, NLBs, NAT GW, VPC, S3, DNS, IAM roles)
# Keeps:    S3 tfstate bucket (created once manually, holds Terraform state)
#           Your base Route53 hosted zone (pre-existing, not managed here)
#
# At-rest cost after this script: ~$2/mo (S3 tfstate only)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$REPO_ROOT/terraform"
TF_VARS="$TF_DIR/environments/okd-prod/terraform.tfvars"
CLUSTER_DIR="$REPO_ROOT/cluster-config"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[lab-down]${NC} $*"; }
warn() { echo -e "${YELLOW}[lab-down]${NC} ⚠️  $*"; }
die()  { echo -e "${RED}[lab-down] ERROR:${NC} $*" >&2; exit 1; }

FORCE=false
for arg in "$@"; do
  [[ "$arg" == "--force" ]] && FORCE=true
done

# ─────────────────────────────────────────────────────────────────────────────
# Confirm
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${RED}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║          OKD Lab — FULL TEARDOWN                 ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
warn "This will DESTROY all OKD lab AWS resources:"
echo "    • EC2 instances (master nodes + any running bootstrap)"
echo "    • All EBS volumes (all cluster data is lost)"
echo "    • NLBs, NAT Gateway, VPC, subnets"
echo "    • S3 ignition + image registry buckets"
echo "    • Route53 private hosted zone"
echo "    • IAM roles and instance profiles"
echo ""
warn "All in-cluster data (ArgoCD state, images, configs) will be gone."
warn "All persistent state should already be in GitHub — verify before proceeding."
echo ""

if ! $FORCE; then
  read -rp "Type 'destroy' to confirm teardown: " confirm
  [[ "$confirm" == "destroy" ]] || { log "Aborted — nothing destroyed."; exit 0; }
fi

# ─────────────────────────────────────────────────────────────────────────────
# Terraform destroy
# ─────────────────────────────────────────────────────────────────────────────
log "Running terraform destroy..."
cd "$TF_DIR"

terraform init -reconfigure \
  -input=false 2>/dev/null || warn "terraform init failed — attempting destroy anyway"

terraform destroy \
  -var-file="$TF_VARS" \
  -auto-approve \
  -input=false

# ─────────────────────────────────────────────────────────────────────────────
# Clean up local cluster-config (credentials are now invalid)
# ─────────────────────────────────────────────────────────────────────────────
if [[ -d "$CLUSTER_DIR" ]]; then
  log "Removing local cluster-config/ (credentials are no longer valid)..."
  rm -rf "$CLUSTER_DIR"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Lab torn down successfully ✓${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}At-rest cost${NC}   ~\$2/mo  (S3 tfstate bucket only)"
echo -e "  ${CYAN}Rebuild time${NC}   ~50 min (terraform apply + OKD install)"
echo ""
echo -e "  ${CYAN}Next session${NC}"
echo "    ./scripts/lab-up.sh"
echo ""
log "Done."
