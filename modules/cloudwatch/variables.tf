variable "ec2_instance_id" {
  description = "EC2 instance ID to monitor"
  type        = string
}

variable "cloudfront_prod_id" {
  description = "CloudFront production distribution ID"
  type        = string
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm triggers"
  type        = list(string)
  default     = []
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}