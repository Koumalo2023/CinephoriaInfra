output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.cinephoria.id
}

output "public_ip" {
  description = "Elastic IP address"
  value       = aws_eip.cinephoria.public_ip
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.cinephoria.id
}