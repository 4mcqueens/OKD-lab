# ── Data: Latest Fedora CoreOS AMI ───────────────────────────────────────────
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

# ── SSH Key Pair ──────────────────────────────────────────────────────────────
# Used by openshift-install to embed SSH access into ignition configs.
# After cluster is up, use `oc debug node/<name>` instead of direct SSH.
resource "aws_key_pair" "cluster" {
  key_name   = "${var.cluster_name}-key"
  public_key = var.ssh_public_key
}

# ── Master Nodes (Compact — master + worker) ──────────────────────────────────
# Single root volume handles both OS and etcd for lab use.
# No dedicated etcd volume — acceptable for non-production, ephemeral sessions.
resource "aws_instance" "master" {
  count         = 3
  ami           = data.aws_ami.fcos.id
  instance_type = var.master_instance_type
  subnet_id     = var.private_subnet_ids[count.index]

  vpc_security_group_ids = [var.master_sg_id]
  iam_instance_profile   = var.master_instance_profile
  key_name               = aws_key_pair.cluster.key_name

  # Ignition user-data: fetches master.ign from S3 on first boot
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
    volume_type           = "gp3"
    volume_size           = var.master_root_volume_size
    iops                  = 3000   # gp3 baseline — adequate for lab etcd
    throughput            = 125
    encrypted             = true
    delete_on_termination = true   # ephemeral — no data to keep between sessions
  }

  tags = {
    Name                                              = "${var.cluster_name}-master-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}"       = "owned"
    Role                                              = "master"
  }

  lifecycle {
    ignore_changes = [ami] # Prevent replacement if FCOS AMI updates mid-session
  }
}

# ── Bootstrap Node (temporary) ────────────────────────────────────────────────
# Exists only during the ~45-min install process.
# Placed in a public subnet so openshift-install can reach the bootstrap API.
# Destroyed by lab-up.sh immediately after bootstrap-complete.
resource "aws_instance" "bootstrap" {
  ami           = data.aws_ami.fcos.id
  instance_type = var.bootstrap_instance_type
  subnet_id     = var.public_subnet_ids[0]

  vpc_security_group_ids      = [var.bootstrap_sg_id]
  iam_instance_profile        = var.master_instance_profile
  key_name                    = aws_key_pair.cluster.key_name
  associate_public_ip_address = true

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
    volume_type           = "gp3"
    volume_size           = 100
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.cluster_name}-bootstrap"
    Note = "TEMPORARY — destroyed by lab-up.sh after bootstrap-complete"
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
# Bootstrap needs to serve the initial API and MCS until masters take over.
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
