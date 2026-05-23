locals {
  cluster_domain = "${var.cluster_name}.${var.base_domain}"
}

# ── Public Hosted Zone ────────────────────────────────────────────────────────
data "aws_route53_zone" "base" {
  name         = "${var.base_domain}."
  private_zone = false
}

# api.<cluster>.<domain> → External API NLB
resource "aws_route53_record" "api_ext" {
  zone_id = data.aws_route53_zone.base.zone_id
  name    = "api.${local.cluster_domain}"
  type    = "A"

  alias {
    name                   = var.api_nlb_ext_dns_name
    zone_id                = var.api_nlb_ext_zone_id
    evaluate_target_health = false
  }
}

# *.apps.<cluster>.<domain> → Apps NLB (public)
resource "aws_route53_record" "apps_ext" {
  zone_id = data.aws_route53_zone.base.zone_id
  name    = "*.apps.${local.cluster_domain}"
  type    = "A"

  alias {
    name                   = var.apps_nlb_dns_name
    zone_id                = var.apps_nlb_zone_id
    evaluate_target_health = false
  }
}

# ── Private Hosted Zone ───────────────────────────────────────────────────────
resource "aws_route53_zone" "private" {
  name = local.cluster_domain

  vpc {
    vpc_id = var.vpc_id
  }

  tags = { Name = "${var.cluster_name}-private-zone" }
}

# api.<cluster>.<domain> → Internal API NLB (private resolution)
resource "aws_route53_record" "api_int" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "api.${local.cluster_domain}"
  type    = "A"

  alias {
    name                   = var.api_nlb_int_dns_name
    zone_id                = var.api_nlb_int_zone_id
    evaluate_target_health = false
  }
}

# api-int.<cluster>.<domain> → Internal API NLB
resource "aws_route53_record" "api_int_internal" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "api-int.${local.cluster_domain}"
  type    = "A"

  alias {
    name                   = var.api_nlb_int_dns_name
    zone_id                = var.api_nlb_int_zone_id
    evaluate_target_health = false
  }
}

# *.apps.<cluster>.<domain> → Apps NLB (private resolution)
resource "aws_route53_record" "apps_int" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "*.apps.${local.cluster_domain}"
  type    = "A"

  alias {
    name                   = var.apps_nlb_dns_name
    zone_id                = var.apps_nlb_zone_id
    evaluate_target_health = false
  }
}
