# OKD Lab

> 3-node OKD compact cluster on AWS · GitOps with ArgoCD

## Architecture

| Component | Details |
|-----------|---------|
| **Cluster** | OKD 4.x, compact topology (3× master+worker) |
| **Cloud** | AWS us-east-1, multi-AZ |
| **Nodes** | 3× m5.2xlarge on Fedora CoreOS |
| **GitOps** | ArgoCD via OpenShift GitOps Operator |
| **IaC** | Terraform (modular) |

📄 Full architecture reference: [`docs/architecture-reference.html`](docs/architecture-reference.html)

## Repository Structure

```
OKD-lab/
├── docs/
│   └── architecture-reference.html   # Full architecture reference
├── terraform/
│   ├── main.tf / variables.tf / outputs.tf / versions.tf
│   ├── modules/
│   │   ├── vpc/                       # VPC, subnets, IGW, NAT GWs
│   │   ├── security-groups/           # SGs for masters, bootstrap, bastion
│   │   ├── iam/                       # IAM roles + instance profiles
│   │   ├── load-balancers/            # 3× NLBs (API ext, API int, Apps)
│   │   ├── dns/                       # Route53 public + private zones
│   │   ├── s3/                        # Bootstrap + image registry buckets
│   │   └── ec2/                       # Bastion, bootstrap, master nodes
│   └── environments/
│       └── okd-prod/
│           ├── terraform.tfvars       # Environment values
│           └── backend.tf             # S3 remote state
└── gitops/
    ├── apps/                          # ArgoCD Application manifests
    ├── infrastructure/                # Cluster-level infra (cert-manager, etc.)
    └── services/                      # Application manifests
```

## Quick Start

### Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.6
- `openshift-install` CLI ([download](https://github.com/okd-project/okd/releases))
- `oc` CLI
- A registered domain in Route53

### 1. Create Terraform state backend (once)

```bash
aws s3 mb s3://okd-lab-tfstate --region us-east-1
aws dynamodb create-table \
  --table-name okd-lab-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. Configure your environment

```bash
cp terraform/environments/okd-prod/terraform.tfvars terraform/environments/okd-prod/terraform.tfvars.local
# Edit terraform.tfvars with your domain, SSH key, and IP
```

### 3. Deploy core infrastructure (without EC2)

```bash
cd terraform
terraform init
terraform apply -target=module.vpc \
                -target=module.security_groups \
                -target=module.iam \
                -target=module.s3 \
                -target=module.load_balancers \
                -target=module.dns
```

### 4. Generate OKD ignition configs

```bash
./openshift-install create install-config --dir=./cluster-config
# Edit cluster-config/install-config.yaml for compact topology
./openshift-install create ignition-configs --dir=./cluster-config

# Upload ignition files to S3
BUCKET=$(terraform output -raw bootstrap_bucket_name)
aws s3 cp cluster-config/bootstrap.ign s3://$BUCKET/bootstrap.ign
aws s3 cp cluster-config/master.ign    s3://$BUCKET/master.ign
```

### 5. Launch EC2 instances

```bash
terraform apply -target=module.ec2
```

### 6. Monitor installation

```bash
./openshift-install wait-for bootstrap-complete --dir=./cluster-config --log-level=info
# Once complete, terminate the bootstrap node:
terraform destroy -target=module.ec2.aws_instance.bootstrap

./openshift-install wait-for install-complete --dir=./cluster-config
```

### 7. Access the cluster

```bash
export KUBECONFIG=./cluster-config/auth/kubeconfig
oc get nodes
oc get clusteroperators
# Console: https://console.apps.okd-prod.<your-domain>
```

### 8. Install ArgoCD (OpenShift GitOps Operator)

```bash
oc apply -f gitops/apps/gitops-operator-subscription.yaml
# Connect this repo to ArgoCD and apply the app-of-apps
```

## Links

- [OKD Documentation](https://docs.okd.io)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io)
- [Fedora CoreOS](https://getfedora.org/coreos)
- [Architecture Reference](docs/architecture-reference.html)
