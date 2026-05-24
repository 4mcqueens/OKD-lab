# ── Bootstrap Ignition Bucket ─────────────────────────────────────────────────
# Ephemeral — created each session, destroyed with `lab-down.sh`.
resource "aws_s3_bucket" "bootstrap" {
  bucket        = "okd-bootstrap-${var.cluster_id}"
  force_destroy = true
  tags          = { Name = "okd-bootstrap-${var.cluster_id}", Purpose = "bootstrap", Lifecycle = "ephemeral" }
}

resource "aws_s3_bucket_public_access_block" "bootstrap" {
  bucket                  = aws_s3_bucket.bootstrap.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "bootstrap" {
  bucket     = aws_s3_bucket.bootstrap.id
  depends_on = [aws_s3_bucket_public_access_block.bootstrap]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadIgnitionFiles"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.bootstrap.arn}/*"
    }]
  })
}

# ── Image Registry Bucket ─────────────────────────────────────────────────────
# Ephemeral — no versioning, no persistence needed between sessions.
resource "aws_s3_bucket" "image_registry" {
  bucket        = "okd-registry-${var.cluster_id}"
  force_destroy = true
  tags          = { Name = "okd-registry-${var.cluster_id}", Purpose = "image-registry", Lifecycle = "ephemeral" }
}

resource "aws_s3_bucket_public_access_block" "image_registry" {
  bucket                  = aws_s3_bucket.image_registry.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "image_registry" {
  bucket = aws_s3_bucket.image_registry.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
