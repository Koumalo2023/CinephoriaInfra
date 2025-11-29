output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.ec2.name
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=Cinephoria-Dashboard"
}