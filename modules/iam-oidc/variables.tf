# Variables pour le module IAM OIDC

variable "aws_region" {
  description = "Région AWS où déployer les ressources"
  type        = string
  default     = "eu-west-3"
}

variable "github_owner" {
  description = "Propriétaire/organisation du repository GitHub"
  type        = string
}

variable "ec2_instance_id" {
  description = "ID de l'instance EC2 pour le backend"
  type        = string
}

variable "s3_bucket_staging" {
  description = "Nom du bucket S3 pour l'environnement staging"
  type        = string
}

variable "s3_bucket_production" {
  description = "Nom du bucket S3 pour l'environnement production"
  type        = string
}