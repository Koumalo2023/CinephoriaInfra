output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2.public_ip
}

output "cloudfront_prod_url" {
  description = "Production CloudFront distribution URL"
  value       = "https://${module.cloudfront.prod_domain_name}"
}

output "cloudfront_staging_url" {
  description = "Staging CloudFront distribution URL"
  value       = "https://${module.cloudfront.staging_domain_name}"
}

output "api_prod_url" {
  description = "Production API URL"
  value       = "https://api.${var.domain_name}"
}

output "api_staging_url" {
  description = "Staging API URL"
  value       = "https://staging-api.${var.domain_name}"
}

output "route53_name_servers" {
  description = "Route53 name servers for domain configuration"
  value       = module.route53.name_servers
}

output "s3_prod_bucket" {
  description = "Production S3 bucket name"
  value       = module.s3.prod_bucket_name
}

output "s3_staging_bucket" {
  description = "Staging S3 bucket name"
  value       = module.s3.staging_bucket_name
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2.instance_id
}

output "cloudfront_prod_distribution_id" {
  description = "Production CloudFront distribution ID"
  value       = module.cloudfront.prod_distribution_id
}

output "cloudfront_staging_distribution_id" {
  description = "Staging CloudFront distribution ID"
  value       = module.cloudfront.staging_distribution_id
}

output "iam_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = module.iam_oidc.role_arn
}