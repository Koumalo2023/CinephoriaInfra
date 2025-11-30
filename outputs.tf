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