terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "cinephoria-terraform-state"
    key    = "cinephoria/infrastructure.tfstate"
    region = "eu-west-3"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "Cinephoria"
      Environment = "Infrastructure"
      ManagedBy   = "Terraform"
    }
  }
}

# Get default VPC and subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Module: ACM
module "acm" {
  source = "./modules/acm"

  domain_name    = var.domain_name
  hosted_zone_id = module.route53.hosted_zone_id
  tags           = var.tags
}

# Module: S3
module "s3" {
  source = "./modules/s3"

  bucket_prefix          = var.bucket_prefix
  cloudfront_prod_arn    = module.cloudfront.prod_arn
  cloudfront_staging_arn = module.cloudfront.staging_arn
  tags                   = var.tags
}

# Module: CloudFront
module "cloudfront" {
  source = "./modules/cloudfront"

  domain_name            = var.domain_name
  certificate_arn        = module.acm.certificate_arn
  s3_prod_domain_name    = module.s3.prod_bucket_name
  s3_staging_domain_name = module.s3.staging_bucket_name
  tags                   = var.tags
}

# Module: EC2
module "ec2" {
  source = "./modules/ec2"

  instance_type     = var.ec2_instance_type
  key_name          = var.ec2_key_name
  vpc_id            = data.aws_vpc.default.id
  subnet_id         = data.aws_subnets.default.ids[0]
  postgres_password = var.postgres_password
  domain_name       = var.domain_name
  tags              = var.tags
}

# Module: Route53
module "route53" {
  source = "./modules/route53"

  domain_name                  = var.domain_name
  cloudfront_prod_domain_name  = module.cloudfront.prod_domain_name
  cloudfront_staging_domain_name = module.cloudfront.staging_domain_name
  cloudfront_hosted_zone_id    = "Z2FDTNDATAQYW2" # CloudFront's fixed hosted zone ID
  ec2_elastic_ip               = module.ec2.public_ip
}

# Module: CloudWatch
module "cloudwatch" {
  source = "./modules/cloudwatch"

  ec2_instance_id      = module.ec2.instance_id
  cloudfront_prod_id   = module.cloudfront.prod_distribution_id
  alarm_actions        = var.cloudwatch_alarm_actions
  region               = var.region
  tags                 = var.tags
}

# Module: IAM OIDC pour GitHub Actions
module "iam_oidc" {
  source = "./modules/iam-oidc"

  aws_region          = var.region
  github_owner        = var.github_owner
  ec2_instance_id     = module.ec2.instance_id
  s3_bucket_staging   = module.s3.staging_bucket_name
  s3_bucket_production = module.s3.prod_bucket_name
}