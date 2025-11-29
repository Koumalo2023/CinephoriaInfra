output "prod_distribution_id" {
  description = "Production CloudFront distribution ID"
  value       = aws_cloudfront_distribution.prod.id
}

output "staging_distribution_id" {
  description = "Staging CloudFront distribution ID"
  value       = aws_cloudfront_distribution.staging.id
}

output "prod_domain_name" {
  description = "Production CloudFront domain name"
  value       = aws_cloudfront_distribution.prod.domain_name
}

output "staging_domain_name" {
  description = "Staging CloudFront domain name"
  value       = aws_cloudfront_distribution.staging.domain_name
}

output "prod_arn" {
  description = "Production CloudFront ARN"
  value       = aws_cloudfront_distribution.prod.arn
}

output "staging_arn" {
  description = "Staging CloudFront ARN"
  value       = aws_cloudfront_distribution.staging.arn
}