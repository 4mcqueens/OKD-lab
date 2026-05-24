#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# lab-up.sh — Bring the OKD lab cluster up from scratch
#
# Usage:  ./scripts/lab-up.sh [--skip-infra] [--skip-ignition]
#
# Phases:
#   1. Validate prerequisites
#   2. Apply core AWS infrastructure (VPC, SGs, IAM, S3, NLBs, DNS)
#   3. Generate OKD ignition configs and upload to S3
#   4. Launch EC2 nodes (bootstrap + 3× master)
#   5. Wait for bootstrap to complete, then destroy bootstrap node
#   6. Wait for full cluster install to complete
#   7. Print access summary
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$REPO_ROOT/terraform"
TF_VARS="$TF_DIR/environments/okd-prod/terraform.tfvars"
CLUSTER_DIR="$REPO_ROOT/cluster-config"
INSTALL_CONFIG_TEMPLATE="$SCRIPT_DIR/install-config-template.yaml"

# ── Flags ────────────────────────────────────────────────────────────────────
SKIP_INFRA=false
SKIP_IGNITION=false
for arg in "$@"; do
  case $arg in
    --skip-infra)    SKIP_INFRA=true ;;
    --skip-ignition) SKIP_IGNITION=true ;;
  esac
done

# ── Colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[lab-up]${NC} $*"; }
info() { echo -e "${CYAN}[lab-up]${NC} $*"; }
warn() { echo -e "${YELLOW}[lab-up]${NC} ⚠️  $*"; }
die()  { echo -e "${RED}[lab-up] ERROR:${NC} $*" >&2; exit 1; }

# ─────────────────────────────────────────────────────────────────────────────
# Phase 0 — Prerequisites
# ─────────────────────────────────────────────────────────────────────────────
check_prereqs() {
  log "Checking prerequisites..."

  for cmd in terraform aws openshift-install oc envsubst; do
    command -v "$cmd" &>/dev/null || die "'$cmd' not found in PATH.
    Install guide:
      terraform:         https://developer.hashicorp.com/terraform/install
      aws:               https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
      openshift-install: https://github.com/okd-project/okd/releases
      oc:                https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/
      envsubst:          part of gettext — brew install gettext / apt install gettext"
  done

  aws sts get-caller-identity &>/dev/null \
    || die "AWS credentials not configured. Run: aws configure"

  [[ -f "$INSTALL_CONFIG_TEMPLATE" ]] \
    || die "Missing install-config-template.yaml — copy and customise scripts/install-config-template.yaml"

  [[ -f "$TF_VARS" ]] \
    || die "Missing terraform.tfvars — copy and fill in terraform/environments/okd-prod/terraform.tfvars"

  log "Prerequisites OK ✓"
}

# ─────────────────────────────────────────────────────────────────────────────
# Phase 1 — Core infrastructure
# ─────────────────────────────────────────────────────────────────────────────
apply_infra() {
  if $SKIP_INFRA; then
    warn "Skipping infra apply (--skip-infra)"
    return
  fi

  log "Phase 1: Applying core infrastructure..."
  cd "$TF_DIR"

  terraform init -reconfigure \
    -backend-config="environments/okd-prod/backend.tf" \
    -input=false

  terraform apply \
    -var-file="$TF_VARS" \
    -target=module.vpc \
    -target=module.security_groups \
    -target=module.iam \
    -target=module.s3 \
    -target=module.load_balancers \
    -target=module.dns \
    -auto-approve \
    -input=false

  log "Core infrastructure ready ✓"
}

# ─────────────────────────────────────────────────────────────────────────────
# Phase 2 — Generate & upload ignition configs
# ─────────────────────────────────────────────────────────────────────────────
generate_ignition() {
  if $SKIP_IGNITION; then
    warn "Skipping ignition generation (--skip-ignition)"
    return
  fi

  log "Phase 2: Generating OKD ignition configs..."

  # Pull values from Terraform outputs
  cd "$TF_DIR"
  BOOTSTRAP_BUCKET=$(terraform output -raw bootstrap_bucket_name)
  PRIVATE_SUBNETS=$(terraform output -json private_subnet_ids)
  PRIVATE_SUBNET_1=$(echo "$PRIVATE_SUBNETS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0])")
  PRIVATE_SUBNET_2=$(echo "$PRIVATE_SUBNETS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[1])")
  PRIVATE_SUBNET_3=$(echo "$PRIVATE_SUBNETS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[2])")

  # Read values from tfvars (simple grep — no extra tooling needed)
  BASE_DOMAIN=$(grep 'base_domain' "$TF_VARS" | awk -F'"' '{print $2}')
  CLUSTER_NAME=$(grep 'cluster_name' "$TF_VARS" | awk -F'"' '{print $2}')
  AWS_REGION=$(grep 'aws_region' "$TF_VARS" | awk -F'"' '{print $2}')
  MASTER_INSTANCE_TYPE=$(grep 'master_instance_type' "$TF_VARS" | awk -F'"' '{print $2}')
  AZ_JSON=$(grep 'availability_zones' "$TF_VARS" | grep -oP '"[^"]*"' | tr '\n' ',' | sed 's/,$//')
  AZ_1=$(echo "$AZ_JSON" | awk -F'"' '{print $2}')
  AZ_2=$(echo "$AZ_JSON" | awk -F'"' '{print $4}')
  AZ_3=$(echo "$AZ_JSON" | awk -F'"' '{print $6}')
  SSH_PUBLIC_KEY=$(grep 'ssh_public_key' "$TF_VARS" | awk -F'"' '{print $2}')

  export BASE_DOMAIN CLUSTER_NAME AWS_REGION MASTER_INSTANCE_TYPE
  export AZ_1 AZ_2 AZ_3 SSH_PUBLIC_KEY
  export PRIVATE_SUBNET_1 PRIVATE_SUBNET_2 PRIVATE_SUBNET_3

  # Render install-config from template
  rm -rf "$CLUSTER_DIR"
  mkdir -p "$CLUSTER_DIR"
  envsubst < "$INSTALL_CONFIG_TEMPLATE" > "$CLUSTER_DIR/install-config.yaml"

  info "install-config.yaml rendered:"
  grep -E 'name:|baseDomain:|type:|region:' "$CLUSTER_DIR/install-config.yaml" | head -10

  # Generate ignition configs (consumes install-config.yaml)
  openshift-install create ignition-configs --dir="$CLUSTER_DIR"

  # Upload ignition files to S3
  log "Uploading ignition configs to s3://$BOOTSTRAP_BUCKET/ ..."
  aws s3 cp "$CLUSTER_DIR/bootstrap.ign" "s3://$BOOTSTRAP_BUCKET/bootstrap.ign" --no-progress
  aws s3 cp "$CLUSTER_DIR/master.ign"    "s3://$BOOTSTRAP_BUCKET/master.ign"    --no-progress
  aws s3 cp "$CLUSTER_DIR/worker.ign"    "s3://$BOOTSTRAP_BUCKET/worker.ign"    --no-progress

  log "Ignition configs uploaded ✓"
}

# ─────────────────────────────────────────────────────────────────────────────
# Phase 3 — Launch EC2 nodes
# ─────────────────────────────────────────────────────────────────────────────
launch_nodes() {
  log "Phase 3: Launching bootstrap + master nodes..."
  cd "$TF_DIR"

  terraform apply \
    -var-file="$TF_VARS" \
    -target=module.ec2 \
    -auto-approve \
    -input=false

  log "Nodes launched ✓"
  info "Bootstrap public IP: $(terraform output -raw bootstrap_public_ip 2>/dev/null || echo 'N/A')"
  info "Master private IPs:  $(terraform output -json master_private_ips 2>/dev/null | tr -d '[]"' | tr ',' ' ')"
}

# ─────────────────────────────────────────────────────────────────────────────
# Phase 4 — Wait for bootstrap, then tear it down
# ─────────────────────────────────────────────────────────────────────────────
wait_bootstrap() {
  log "Phase 4: Waiting for bootstrap to complete (typically 30–45 min)..."
  export KUBECONFIG="$CLUSTER_DIR/auth/kubeconfig"
  openshift-install wait-for bootstrap-complete \
    --dir="$CLUSTER_DIR" \
    --log-level=info

  log "Bootstrap complete. Destroying bootstrap node..."
  cd "$TF_DIR"
  # Remove bootstrap from NLB target groups first, then terminate the instance
  terraform destroy \
    -var-file="$TF_VARS" \
    -target=module.ec2.aws_lb_target_group_attachment.bootstrap_api_ext \
    -target=module.ec2.aws_lb_target_group_attachment.bootstrap_api_int \
    -target=module.ec2.aws_lb_target_group_attachment.bootstrap_mcs_int \
    -target=module.ec2.aws_instance.bootstrap \
    -auto-approve \
    -input=false

  log "Bootstrap node destroyed ✓  (saving ~\$0.10/hr)"
}

# ─────────────────────────────────────────────────────────────────────────────
# Phase 5 — Wait for full install
# ─────────────────────────────────────────────────────────────────────────────
wait_install() {
  log "Phase 5: Waiting for all cluster operators to be available (~15–20 min)..."
  export KUBECONFIG="$CLUSTER_DIR/auth/kubeconfig"
  openshift-install wait-for install-complete \
    --dir="$CLUSTER_DIR" \
    --log-level=info
}

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
print_summary() {
  cd "$TF_DIR"
  API_URL=$(terraform output -raw api_url     2>/dev/null || echo "N/A")
  CON_URL=$(terraform output -raw console_url 2>/dev/null || echo "N/A")
  ACD_URL=$(terraform output -raw argocd_url  2>/dev/null || echo "N/A")
  KA_PW=$(cat "$CLUSTER_DIR/auth/kubeadmin-password" 2>/dev/null || echo "see cluster-config/auth/kubeadmin-password")

  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║          OKD Lab is Ready! 🚀                    ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${CYAN}Console  ${NC} $CON_URL"
  echo -e "  ${CYAN}API      ${NC} $API_URL"
  echo -e "  ${CYAN}ArgoCD   ${NC} $ACD_URL  (after GitOps operator install)"
  echo -e "  ${CYAN}User     ${NC} kubeadmin"
  echo -e "  ${CYAN}Password ${NC} $KA_PW"
  echo ""
  echo -e "  ${CYAN}kubeconfig${NC}"
  echo "    export KUBECONFIG=$CLUSTER_DIR/auth/kubeconfig"
  echo ""
  echo -e "  ${CYAN}Node access (no SSH needed)${NC}"
  echo "    oc debug node/<node-name>"
  echo ""
  echo -e "  ${YELLOW}When done testing, run:${NC}"
  echo "    ./scripts/lab-down.sh"
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  OKD Lab — Cluster Bring-Up                       ${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  check_prereqs
  apply_infra
  generate_ignition
  launch_nodes
  wait_bootstrap
  wait_install
  print_summary
}

main "$@"
