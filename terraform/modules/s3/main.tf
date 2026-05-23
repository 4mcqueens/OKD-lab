# ── Bootstrap Ignition Bucket ─────────────────────────────────────────────────
resource "aws_s3_bucket" "bootstrap" {
  bucket        = "okd-bootstrap-${var.cluster_id}"
  force_destroy = true   # Allows destroy even if bucket has objects
  tags          = { Name = "okd-bootstrap-${var.cluster_id}", Purpose = "bootstrap" }
}

resource "aws_s3_bucket_public_access_block" "bootstrap" {
  bucket = aws_s3_bucket.bootstrap.id

  # Bootstrap node fetches bootstrap.ign — must be publicly readable
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "bootstrap" {
  bucket = aws_s3_bucket.bootstrap.id
  depends_on = [aws_s3_bucket_public_access_block.bootstrap]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadBootstrapIgnition"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.bootstrap.arn}/bootstrap.ign"
      }
    ]
  })
}

# ── Image Registry Bucket ─────────────────────────────────────────────────────
resource "aws_s3_bucket" "image_registry" {
  bucket        = "okd-registry-${var.cluster_id}"
  force_destroy = false
  tags          = { Name = "okd-registry-${var.cluster_id}", Purpose = "image-registry" }
}

resource "aws_s3_bucket_versioning" "image_registry" {
  bucket = aws_s3_bucket.image_registry.id
  versioning_configuration { status = "Enabled" }
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
