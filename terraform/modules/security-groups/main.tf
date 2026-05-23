# ── Master / Control Plane SG ─────────────────────────────────────────────────
resource "aws_security_group" "master" {
  name        = "${var.cluster_name}-master-sg"
  description = "OKD master + worker nodes (compact topology)"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.cluster_name}-master-sg" }

  # Kubernetes API — public (via NLB)
  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Machine Config Server — internal only
  ingress {
    description = "Machine Config Server (MCS)"
    from_port   = 22623
    to_port     = 22623
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # etcd — control plane peers only
  ingress {
    description = "etcd client + peer"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
  }

  # kubelet
  ingress {
    description = "kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Host-level services
  ingress {
    description = "Host-level services"
    from_port   = 9000
    to_port     = 9999
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # OVN-Kubernetes VXLAN
  ingress {
    description = "VXLAN (OVN-Kubernetes)"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Geneve (OVN)
  ingress {
    description = "Geneve (OVN)"
    from_port   = 6081
    to_port     = 6081
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # IPsec IKE
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

  # Ingress router — HTTP/HTTPS
  ingress {
    description = "HTTP ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH from bastion only
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
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
resource "aws_security_group" "bootstrap" {
  name        = "${var.cluster_name}-bootstrap-sg"
  description = "OKD bootstrap node (temporary)"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.cluster_name}-bootstrap-sg" }

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description = "journald (bootstrap log capture)"
    from_port   = 19531
    to_port     = 19531
    protocol    = "tcp"
    security_groups = [aws_security_group.master.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── Bastion SG ────────────────────────────────────────────────────────────────
resource "aws_security_group" "bastion" {
  name        = "${var.cluster_name}-bastion-sg"
  description = "Bastion host SSH access"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.cluster_name}-bastion-sg" }

  ingress {
    description = "SSH from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
