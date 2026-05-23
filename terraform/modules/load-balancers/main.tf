# ── External API NLB (internet-facing, port 6443) ────────────────────────────
resource "aws_lb" "api_ext" {
  name               = "${var.cluster_name}-api-ext"
  load_balancer_type = "network"
  internal           = false
  subnets            = var.public_subnet_ids
  tags               = { Name = "${var.cluster_name}-api-ext-nlb" }
}

resource "aws_lb_target_group" "api_ext" {
  name        = "${var.cluster_name}-api-ext-tg"
  port        = 6443
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "HTTPS"
    path                = "/readyz"
    port                = "6443"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }
}

resource "aws_lb_listener" "api_ext" {
  load_balancer_arn = aws_lb.api_ext.arn
  port              = 6443
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_ext.arn
  }
}

# ── Internal API NLB (private, port 6443 + 22623) ────────────────────────────
resource "aws_lb" "api_int" {
  name               = "${var.cluster_name}-api-int"
  load_balancer_type = "network"
  internal           = true
  subnets            = var.private_subnet_ids
  tags               = { Name = "${var.cluster_name}-api-int-nlb" }
}

resource "aws_lb_target_group" "api_int" {
  name        = "${var.cluster_name}-api-int-tg"
  port        = 6443
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "HTTPS"
    path                = "/readyz"
    port                = "6443"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }
}

resource "aws_lb_listener" "api_int" {
  load_balancer_arn = aws_lb.api_int.arn
  port              = 6443
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_int.arn
  }
}

# Machine Config Server (MCS) — internal only
resource "aws_lb_target_group" "mcs_int" {
  name        = "${var.cluster_name}-mcs-int-tg"
  port        = 22623
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "HTTPS"
    path                = "/healthz"
    port                = "22623"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }
}

resource "aws_lb_listener" "mcs_int" {
  load_balancer_arn = aws_lb.api_int.arn
  port              = 22623
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mcs_int.arn
  }
}

# ── Apps NLB (internet-facing, ports 80 + 443) ───────────────────────────────
resource "aws_lb" "apps" {
  name               = "${var.cluster_name}-apps"
  load_balancer_type = "network"
  internal           = false
  subnets            = var.public_subnet_ids
  tags               = { Name = "${var.cluster_name}-apps-nlb" }
}

resource "aws_lb_target_group" "apps_http" {
  name        = "${var.cluster_name}-apps-http-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "HTTP"
    path                = "/healthz/ready"
    port                = "1936"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }
}

resource "aws_lb_target_group" "apps_https" {
  name        = "${var.cluster_name}-apps-https-tg"
  port        = 443
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "HTTP"
    path                = "/healthz/ready"
    port                = "1936"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }
}

resource "aws_lb_listener" "apps_http" {
  load_balancer_arn = aws_lb.apps.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.apps_http.arn
  }
}

resource "aws_lb_listener" "apps_https" {
  load_balancer_arn = aws_lb.apps.arn
  port              = 443
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.apps_https.arn
  }
}
