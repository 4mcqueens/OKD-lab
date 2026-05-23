# ── Data: Latest Fedora CoreOS AMI ───────────────────────────────────────────
# Note: OKD nodes use FCOS. The AMI is region-specific.
# Run: aws ec2 describe-images --owners 125523088429 \
#   --filters "Name=name,Values=fedora-coreos-*" "Name=architecture,Values=x86_64" \
#   --query 'sort_by(Images,&CreationDate)[-1].ImageId'
data "aws_ami" "fcos" {
  most_recent = true
  owners      = ["125523088429"] # Fedora CoreOS AWS account

  filter {
    name   = "name"
    values = ["fedora-coreos-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Data: Amazon Linux 2 AMI (Bastion) ───────────────────────────────────────
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ── SSH Key Pair ──────────────────────────────────────────────────────────────
resource "aws_key_pair" "bastion" {
  key_name   = "${var.cluster_name}-bastion-key"
  public_key = var.ssh_public_key
}

# ── Bastion Host ──────────────────────────────────────────────────────────────
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.bastion_instance_type
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = aws_key_pair.bastion.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y git curl wget jq
    # Install oc CLI
    curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz \
      | tar -xz -C /usr/local/bin oc kubectl
  EOF

  tags = { Name = "${var.cluster_name}-bastion" }
}

# ── Master Nodes (Compact: master + worker) ───────────────────────────────────
resource "aws_instance" "master" {
  count         = 3
  ami           = data.aws_ami.fcos.id
  instance_type = var.master_instance_type
  subnet_id     = var.private_subnet_ids[count.index]

  vpc_security_group_ids = [var.master_sg_id]
  iam_instance_profile   = var.master_instance_profile

  # Ignition user-data: points to the bootstrap ignition URL in S3
  # The actual ignition file is uploaded after running openshift-install
  user_data = jsonencode({
    ignition = {
      version = "3.1.0"
      config = {
        merge = [{
          source = "https://s3.${var.aws_region}.amazonaws.com/${var.bootstrap_ignition_bucket}/master.ign"
        }]
      }
    }
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = var.master_root_volume_size
    encrypted   = true
  }

  tags = {
    Name                                              = "${var.cluster_name}-master-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}"       = "owned"
  }
}

# ── Dedicated etcd EBS Volumes ────────────────────────────────────────────────
resource "aws_ebs_volume" "etcd" {
  count             = 3
  availability_zone = var.availability_zones[count.index]
  size              = var.master_etcd_volume_size
  type              = "gp3"
  iops              = 3000
  throughput        = 125
  encrypted         = true
  tags              = { Name = "${var.cluster_name}-etcd-${count.index}" }
}

resource "aws_volume_attachment" "etcd" {
  count       = 3
  device_name = "/dev/xvdb"
  volume_id   = aws_ebs_volume.etcd[count.index].id
  instance_id = aws_instance.master[count.index].id
}

# ── Bootstrap Node (temporary) ────────────────────────────────────────────────
resource "aws_instance" "bootstrap" {
  ami           = data.aws_ami.fcos.id
  instance_type = var.bootstrap_instance_type
  subnet_id     = var.public_subnet_ids[0]

  vpc_security_group_ids = [var.bootstrap_sg_id]
  iam_instance_profile   = var.master_instance_profile

  user_data = jsonencode({
    ignition = {
      version = "3.1.0"
      config = {
        merge = [{
          source = "https://s3.${var.aws_region}.amazonaws.com/${var.bootstrap_ignition_bucket}/bootstrap.ign"
        }]
      }
    }
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = 120
    encrypted   = true
  }

  tags = {
    Name = "${var.cluster_name}-bootstrap"
    Note = "TEMPORARY — destroy after cluster install completes"
  }
}

# ── NLB Target Group Attachments — Masters ────────────────────────────────────
resource "aws_lb_target_group_attachment" "api_ext" {
  count            = 3
  target_group_arn = var.api_nlb_ext_target_arn
  target_id        = aws_instance.master[count.index].id
  port             = 6443
}

resource "aws_lb_target_group_attachment" "api_int" {
  count            = 3
  target_group_arn = var.api_nlb_int_target_arn
  target_id        = aws_instance.master[count.index].id
  port             = 6443
}

resource "aws_lb_target_group_attachment" "mcs_int" {
  count            = 3
  target_group_arn = var.mcs_nlb_int_target_arn
  target_id        = aws_instance.master[count.index].id
  port             = 22623
}

resource "aws_lb_target_group_attachment" "apps_http" {
  count            = 3
  target_group_arn = var.apps_nlb_http_target_arn
  target_id        = aws_instance.master[count.index].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "apps_https" {
  count            = 3
  target_group_arn = var.apps_nlb_https_target_arn
  target_id        = aws_instance.master[count.index].id
  port             = 443
}

# ── NLB Target Group Attachments — Bootstrap ──────────────────────────────────
resource "aws_lb_target_group_attachment" "bootstrap_api_ext" {
  target_group_arn = var.api_nlb_ext_target_arn
  target_id        = aws_instance.bootstrap.id
  port             = 6443
}

resource "aws_lb_target_group_attachment" "bootstrap_api_int" {
  target_group_arn = var.api_nlb_int_target_arn
  target_id        = aws_instance.bootstrap.id
  port             = 6443
}

resource "aws_lb_target_group_attachment" "bootstrap_mcs_int" {
  target_group_arn = var.mcs_nlb_int_target_arn
  target_id        = aws_instance.bootstrap.id
  port             = 22623
}
