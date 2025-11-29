variable "bucket_prefix" {
  description = "Prefix for S3 bucket names"
  type        = string
  default     = "cinephoria-frontend"
}

variable "cloudfront_prod_arn" {
  description = "ARN of production CloudFront distribution"
  type        = string
}

variable "cloudfront_staging_arn" {
  description = "ARN of staging CloudFront distribution"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}