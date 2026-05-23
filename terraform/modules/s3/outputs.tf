output "bootstrap_bucket_name"       { value = aws_s3_bucket.bootstrap.bucket }
output "bootstrap_bucket_arn"        { value = aws_s3_bucket.bootstrap.arn }
output "image_registry_bucket_name"  { value = aws_s3_bucket.image_registry.bucket }
output "image_registry_bucket_arn"   { value = aws_s3_bucket.image_registry.arn }
