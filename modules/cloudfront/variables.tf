variable "domain_name" {
  description = "The base domain name"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate"
  type        = string
}

variable "s3_prod_domain_name" {
  description = "S3 bucket domain name for production"
  type        = string
}

variable "s3_staging_domain_name" {
  description = "S3 bucket domain name for staging"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}