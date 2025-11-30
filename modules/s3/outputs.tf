output "prod_bucket_name" {
  description = "Production S3 bucket name"
  value       = aws_s3_bucket.frontend_prod.bucket
}

output "staging_bucket_name" {
  description = "Staging S3 bucket name"
  value       = aws_s3_bucket.frontend_staging.bucket
}

output "prod_bucket_arn" {
  description = "Production S3 bucket ARN"
  value       = aws_s3_bucket.frontend_prod.arn
}

output "staging_bucket_arn" {
  description = "Staging S3 bucket ARN"
  value       = aws_s3_bucket.frontend_staging.arn
}