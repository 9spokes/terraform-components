output "s3_bucket_name" {
  value = aws_s3_bucket.bucket.id
}
output "s3_bucket_arn" {
  value = aws_s3_bucket.bucket.arn
}

output "s3_bucket_domain_name" {
  value = aws_s3_bucket.bucket.bucket_domain_name
}

output "s3_bucket_regional_domain_name" {
  value = aws_s3_bucket.bucket.bucket_regional_domain_name
}

output "security_contract" {
  value = {
    force_destroy           = var.force_destroy
    versioning              = var.versioning
    block_public_acls       = var.block_public_acls
    block_public_policy     = var.block_public_policy
    ignore_public_acls      = var.ignore_public_acls
    restrict_public_buckets = var.restrict_public_buckets
    reader_principals       = var.app_aws_principals
  }
}
