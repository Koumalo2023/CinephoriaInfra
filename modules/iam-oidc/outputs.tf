output "backend_role_arn" {
  description = "ARN of the IAM role for GitHub Actions (backend)"
  value       = aws_iam_role.github_actions_backend.arn
}

output "frontend_role_arn" {
  description = "ARN of the IAM role for GitHub Actions (frontend)"
  value       = aws_iam_role.github_actions_frontend.arn
}

output "role_arn" {
  description = "ARN of the IAM role for GitHub Actions (alias for backend)"
  value       = aws_iam_role.github_actions_backend.arn
}