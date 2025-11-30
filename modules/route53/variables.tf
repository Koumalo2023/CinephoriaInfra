variable "domain_name" {
  description = "The domain name for the hosted zone"
  type        = string
}

variable "cloudfront_prod_domain_name" {
  description = "CloudFront distribution domain name for production"
  type        = string
}

variable "cloudfront_staging_domain_name" {
  description = "CloudFront distribution domain name for staging"
  type        = string
}

variable "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID"
  type        = string
  default     = "Z2FDTNDATAQYW2" # CloudFront's fixed hosted zone ID
}

variable "ec2_elastic_ip" {
  description = "Elastic IP address for EC2 instance"
  type        = string
}