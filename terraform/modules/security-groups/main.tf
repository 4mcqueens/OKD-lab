# ── Master / Control Plane SG ─────────────────────────────────────────────────
# No SSH ingress — use `oc debug node/<name>` for shell access after cluster is up.
resource "aws_security_group" "master" {
  name        = "${var.cluster_name}-master-sg"
  description = "OKD compact master+worker nodes - no bastion, access via oc debug"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.cluster_name}-master-sg" }

  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Machine Config Server (MCS) - internal only"
    from_port   = 22623
    to_port     = 22623
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "etcd client + peer - control plane only"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Host-level services"
    from_port   = 9000
    to_port     = 9999
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "VXLAN - OVN-Kubernetes"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Geneve - OVN"
    from_port   = 6081
    to_port     = 6081
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "IPsec IKE"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "IPsec NAT-T"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "HTTP ingress router"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS ingress router"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress router health check port (used by NLB health checks)
  ingress {
    description = "Ingress router health check"
    from_port   = 1936
    to_port     = 1936
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── Bootstrap SG ──────────────────────────────────────────────────────────────
# Temporary node — exists only during cluster installation (~45 min).
# openshift-install monitors bootstrap progress via the API (port 6443 via NLB).
# Direct SSH access is optional; port 22 open to installer_allowed_cidr for log streaming.
resource "aws_security_group" "bootstrap" {
  name        = "${var.cluster_name}-bootstrap-sg"
  description = "OKD bootstrap node (temporary, destroyed after install)"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.cluster_name}-bootstrap-sg" }

  ingress {
    description = "Kubernetes API (via NLB + direct)"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Machine Config Server"
    from_port   = 22623
    to_port     = 22623
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Bootstrap journal log endpoint (openshift-install log streaming)"
    from_port   = 19531
    to_port     = 19531
    protocol    = "tcp"
    cidr_blocks = [var.installer_allowed_cidr]
  }

  ingress {
    description = "SSH - installer machine only (optional, for manual log inspection)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.installer_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
