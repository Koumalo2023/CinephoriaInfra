# Module IAM OIDC pour GitHub Actions
# Ce module crée les rôles IAM nécessaires pour l'authentification OIDC avec GitHub Actions

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider AWS
provider "aws" {
  region = var.aws_region
}

# Rôle IAM pour le backend (CinephoriaBackEnd)
resource "aws_iam_role" "github_actions_backend" {
  name = "github-actions-cinephoria-backend"
  description = "Role IAM pour GitHub Actions - Backend Cinephoria"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_owner}/CinephoriaBackEnd:environment:staging",
              "repo:${var.github_owner}/CinephoriaBackEnd:environment:production"
            ]
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Project     = "Cinephoria"
    Environment = "all"
    ManagedBy   = "Terraform"
    Repository  = "CinephoriaBackEnd"
  }
}

# Rôle IAM pour le frontend (Cinephoria-web)
resource "aws_iam_role" "github_actions_frontend" {
  name = "github-actions-cinephoria-frontend"
  description = "Role IAM pour GitHub Actions - Frontend Cinephoria"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_owner}/Cinephoria-web:environment:staging",
              "repo:${var.github_owner}/Cinephoria-web:environment:production"
            ]
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Project     = "Cinephoria"
    Environment = "all"
    ManagedBy   = "Terraform"
    Repository  = "Cinephoria-web"
  }
}

# Politique pour le backend - Permissions EC2
resource "aws_iam_policy" "backend_ec2_policy" {
  name        = "github-actions-cinephoria-backend-ec2"
  description = "Permissions EC2 pour GitHub Actions - Backend Cinephoria"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances",
          "ec2:GetConsoleOutput"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation"
        ]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${var.ec2_instance_id}",
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:document/*"
        ]
      }
    ]
  })
}

# Politique pour le frontend - Permissions S3
resource "aws_iam_policy" "frontend_s3_policy" {
  name        = "github-actions-cinephoria-frontend-s3"
  description = "Permissions S3 pour GitHub Actions - Frontend Cinephoria"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_staging}",
          "arn:aws:s3:::${var.s3_bucket_production}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucketMultipartUploads",
          "s3:AbortMultipartUpload"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_staging}/*",
          "arn:aws:s3:::${var.s3_bucket_production}/*"
        ]
      }
    ]
  })
}

# Attachement des politiques aux rôles
resource "aws_iam_role_policy_attachment" "backend_ec2_attachment" {
  role       = aws_iam_role.github_actions_backend.name
  policy_arn = aws_iam_policy.backend_ec2_policy.arn
}

resource "aws_iam_role_policy_attachment" "frontend_s3_attachment" {
  role       = aws_iam_role.github_actions_frontend.name
  policy_arn = aws_iam_policy.frontend_s3_policy.arn
}

# Données pour récupérer l'account ID actuel
data "aws_caller_identity" "current" {}