# OKD Lab

> 3-node OKD compact cluster on AWS · GitOps with ArgoCD · Cost-optimised for intermittent lab use

## Cost Model

| State | Monthly Cost | Notes |
|-------|-------------|-------|
| **At rest** | ~$2/mo | S3 tfstate bucket only — everything else destroyed |
| **Running** (est. 10 hrs/wk) | ~$40/mo | On-demand compute + ephemeral infra |
| **Running** (est. 40 hrs/wk) | ~$110/mo | |

All AWS infrastructure is **created on demand and destroyed after each session**. No data persists between sessions — all state lives in this GitHub repo.

## Architecture

| Component | Details |
|-----------|---------|
| **Cluster** | OKD 4.x, compact topology (3× master+worker) |
| **Cloud** | AWS us-east-1, multi-AZ |
| **Nodes** | 3× `m6a.xlarge` (4 vCPU / 16 GB) on Fedora CoreOS |
| **Node access** | `oc debug node/<name>` — no bastion, no SSH needed |
| **GitOps** | ArgoCD via OpenShift GitOps Operator |
| **IaC** | Terraform (modular) |
| **Lifecycle** | `lab-up.sh` → test → `lab-down.sh` |

📄 Full architecture reference: [`docs/architecture-reference.html`](docs/architecture-reference.html)

## Repository Structure

```
OKD-lab/
├── docs/
│   └── architecture-reference.html   # Full AWS architecture reference
├── scripts/
│   ├── lab-up.sh                     # Full cluster bring-up (~50 min)
│   ├── lab-down.sh                   # Full teardown → ~$2/mo at rest
│   └── install-config-template.yaml  # OKD install config (envsubst rendered)
├── terraform/
│   ├── main.tf / variables.tf / outputs.tf / versions.tf
│   ├── modules/
│   │   ├── vpc/                       # VPC, subnets, IGW, single NAT GW
│   │   ├── security-groups/           # Master SG + bootstrap SG (no bastion)
│   │   ├── iam/                       # IAM roles + SSM access
│   │   ├── load-balancers/            # 3× NLBs (API ext, API int, Apps)
│   │   ├── dns/                       # Route53 public + private zones
│   │   ├── s3/                        # Ephemeral ignition + image registry buckets
│   │   └── ec2/                       # Bootstrap + 3× master nodes
│   └── environments/
│       └── okd-prod/
│           ├── terraform.tfvars       # Cluster configuration ← edit this
│           └── backend.tf             # S3 remote state (one-time setup)
└── gitops/
    ├── apps/                          # ArgoCD Application manifests
    ├── infrastructure/                # Cluster-level infra (cert-manager, etc.)
    └── services/                      # Application manifests
```

## Quick Start

### Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| `aws` CLI | AWS access | [docs](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) |
| `terraform` ≥ 1.6 | Infrastructure | [docs](https://developer.hashicorp.com/terraform/install) |
| `openshift-install` | OKD installer | [releases](https://github.com/okd-project/okd/releases) |
| `oc` | OKD CLI | [mirror](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/) |
| `envsubst` | Config rendering | `brew install gettext` / `apt install gettext` |

You also need a domain managed in Route53 (any domain you own).

### One-time Setup

#### 1. Create Terraform state backend

```bash
# Create once — never destroyed by lab-down.sh
aws s3 mb s3://okd-lab-tfstate --region us-east-1

aws dynamodb create-table \
  --table-name okd-lab-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

#### 2. Configure your environment

Edit `terraform/environments/okd-prod/terraform.tfvars`:

```hcl
cluster_name = "okd-lab"
base_domain  = "yourdomain.com"          # Must be in Route53
ssh_public_key = "ssh-rsa AAAA..."       # Your public SSH key
installer_allowed_cidr = "1.2.3.4/32"   # Your IP (for bootstrap log access)
```

### Every Session

#### Start the lab

```bash
./scripts/lab-up.sh
# ~50 minutes total:
#   Phase 1 — Terraform apply (VPC, NLBs, DNS, etc.)    ~5 min
#   Phase 2 — Generate & upload ignition configs          ~1 min
#   Phase 3 — Launch EC2 nodes                           ~2 min
#   Phase 4 — Bootstrap (bootstrap node destroyed after)  ~35 min
#   Phase 5 — Cluster operators stabilise                 ~10 min
```

#### Access the cluster

```bash
export KUBECONFIG=./cluster-config/auth/kubeconfig
oc get nodes
oc get clusteroperators

# Node shell access (no SSH / no bastion needed)
oc debug node/<node-name>

# Web console URL printed by lab-up.sh
# Default user: kubeadmin / password in cluster-config/auth/kubeadmin-password
```

#### Install ArgoCD (OpenShift GitOps Operator)

```bash
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: latest
  name: openshift-gitops-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
EOF

# Wait for operator, then get ArgoCD password
oc wait --for=condition=Available deployment/openshift-gitops-server \
  -n openshift-gitops --timeout=5m
oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=-
```

#### Tear down when done

```bash
./scripts/lab-down.sh
# Destroys all AWS resources
# At-rest cost: ~$2/mo (S3 tfstate only)
```

### Resuming a Partially Failed Session

```bash
# If infra already exists but ignition wasn't generated yet:
./scripts/lab-up.sh --skip-infra

# If infra + ignition exist but EC2 wasn't launched:
./scripts/lab-up.sh --skip-infra --skip-ignition
```

## Cost Breakdown (us-east-1 On-Demand)

| Resource | Per Hour | Notes |
|----------|---------|-------|
| 3× m6a.xlarge | $0.52 | Compute — only charged while running |
| 3× NLB | $0.024 | Only charged while running (created/destroyed each session) |
| 1× NAT GW | $0.045 | Only charged while running |
| EBS (300 GB gp3) | ~$0.033 | Only charged while running |
| Route53 | $0.001 | Negligible |
| **Total while running** | **~$0.62/hr** | |
| **At rest (all destroyed)** | **~$0.003/hr** | S3 tfstate — nearly zero |

## Design Decisions

| Decision | Reason |
|----------|--------|
| `m6a.xlarge` not `m6a.2xlarge` | Cost — min viable spec for OKD lab |
| Single root volume, no dedicated etcd | Simplicity — data is ephemeral |
| No bastion host | `oc debug node` provides shell; SSM policy on IAM role for flexibility |
| On-Demand, not Reserved | Sessions are short — Reserved commits to 1yr billing |
| Full destroy, not stop/start | Stopped instances still incur NLB + NAT Gateway charges (~$50/mo idle) |
| All state in GitHub | Enables clean rebuild from scratch each session |

## Links

- [OKD Documentation](https://docs.okd.io)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io)
- [Fedora CoreOS](https://getfedora.org/coreos)
- [Architecture Reference](docs/architecture-reference.html)
- [m6a Instance Details](https://aws.amazon.com/ec2/instance-types/m6a/)
