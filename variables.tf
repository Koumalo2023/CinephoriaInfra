variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3" # Paris
}

variable "domain_name" {
  description = "Base domain name for Cinephoria"
  type        = string
  default     = "cinephoria.eu"
}

variable "bucket_prefix" {
  description = "Prefix for S3 bucket names"
  type        = string
  default     = "cinephoria-frontend"
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ec2_key_name" {
  description = "SSH key pair name for EC2 instance"
  type        = string
}

variable "postgres_password" {
  description = "PostgreSQL database password"
  type        = string
  sensitive   = true
}

variable "cloudwatch_alarm_actions" {
  description = "List of ARNs for CloudWatch alarm actions"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "github_owner" {
  description = "GitHub owner/organization for OIDC configuration"
  type        = string
  default     = "simopatrice"  # Remplacez par votre nom d'utilisateur GitHub
}