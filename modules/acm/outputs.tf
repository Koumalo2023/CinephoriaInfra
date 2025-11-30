output "certificate_arn" {
  description = "ARN of the wildcard certificate"
  value       = aws_acm_certificate.wildcard.arn
}

output "certificate_domain" {
  description = "Domain name of the certificate"
  value       = aws_acm_certificate.wildcard.domain_name
}