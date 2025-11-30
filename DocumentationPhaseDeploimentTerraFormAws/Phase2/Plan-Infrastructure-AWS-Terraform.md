# Plan d'Infrastructure AWS Low-Cost via Terraform - Cinephoria

## 📋 Vue d'Ensemble

Ce document détaille la mise en place de l'infrastructure AWS complète pour Cinephoria via Terraform, avec une architecture optimisée pour les coûts et compatible Free Tier.

### Architecture Cible

```
🌐 Domaines & Routing:
www.cinephoria.eu          → CloudFront (Production)
staging.cinephoria.eu      → CloudFront (Staging)  
api.cinephoria.eu          → EC2 Port 5000 (Production)
staging-api.cinephoria.eu  → EC2 Port 5001 (Staging)

🖥️ Infrastructure:
EC2 t3.micro (Free Tier) → Backend + PostgreSQL Docker
S3 + CloudFront → Frontend Angular
Route53 → DNS Management
ACM → Certificats SSL
```

## 🏗️ Structure Terraform

### Organisation des Fichiers

```
CinephoriaInfra/
├── modules/
│   ├── acm/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── cloudfront/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ec2/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── user-data.sh
│   ├── route53/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── s3/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── cloudwatch/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
└── README.md
```

## 🌐 Module Route53 (DNS)

### [`modules/route53/main.tf`](CinephoriaInfra/modules/route53/main.tf)

```hcl
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "www_prod" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.cloudfront_prod_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }

  ttl = 300
}

resource "aws_route53_record" "staging" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "staging.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.cloudfront_staging_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }

  ttl = 300
}

resource "aws_route53_record" "api_prod" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [var.ec2_elastic_ip]
}

resource "aws_route53_record" "api_staging" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "staging-api.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [var.ec2_elastic_ip]
}
```

### [`modules/route53/variables.tf`](CinephoriaInfra/modules/route53/variables.tf)

```hcl
variable "domain_name" {
  description = "The domain name for the hosted zone"
  type        = string
}

variable "cloudfront_prod_domain_name" {
  description = "CloudFront distribution domain name for production"
  type        = string
}

variable "cloudfront_staging_domain_name" {
  description = "CloudFront distribution domain name for staging"
  type        = string
}

variable "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID"
  type        = string
  default     = "Z2FDTNDATAQYW2" # CloudFront's fixed hosted zone ID
}

variable "ec2_elastic_ip" {
  description = "Elastic IP address for EC2 instance"
  type        = string
}
```

### [`modules/route53/outputs.tf`](CinephoriaInfra/modules/route53/outputs.tf)

```hcl
output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Name servers for the hosted zone"
  value       = aws_route53_zone.main.name_servers
}
```

## 🔐 Module ACM (Certificats SSL)

### [`modules/acm/main.tf`](CinephoriaInfra/modules/acm/main.tf)

```hcl
resource "aws_acm_certificate" "wildcard" {
  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_route53_record" "wildcard_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.hosted_zone_id
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.wildcard_validation : record.fqdn]
}
```

### [`modules/acm/variables.tf`](CinephoriaInfra/modules/acm/variables.tf)

```hcl
variable "domain_name" {
  description = "The base domain name"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for DNS validation"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

### [`modules/acm/outputs.tf`](CinephoriaInfra/modules/acm/outputs.tf)

```hcl
output "certificate_arn" {
  description = "ARN of the wildcard certificate"
  value       = aws_acm_certificate.wildcard.arn
}

output "certificate_domain" {
  description = "Domain name of the certificate"
  value       = aws_acm_certificate.wildcard.domain_name
}
```

## 🪣 Module S3 (Frontend Storage)

### [`modules/s3/main.tf`](CinephoriaInfra/modules/s3/main.tf)

```hcl
resource "aws_s3_bucket" "frontend_prod" {
  bucket = "${var.bucket_prefix}-prod"
  tags   = var.tags
}

resource "aws_s3_bucket" "frontend_staging" {
  bucket = "${var.bucket_prefix}-staging"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "prod" {
  bucket = aws_s3_bucket.frontend_prod.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "staging" {
  bucket = aws_s3_bucket.frontend_staging.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "prod" {
  bucket = aws_s3_bucket.frontend_prod.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "staging" {
  bucket = aws_s3_bucket.frontend_staging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "prod" {
  bucket = aws_s3_bucket.frontend_prod.id
  policy = data.aws_iam_policy_document.s3_prod.json
}

resource "aws_s3_bucket_policy" "staging" {
  bucket = aws_s3_bucket.frontend_staging.id
  policy = data.aws_iam_policy_document.s3_staging.json
}

data "aws_iam_policy_document" "s3_prod" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.frontend_prod.arn}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [var.cloudfront_prod_arn]
    }
  }
}

data "aws_iam_policy_document" "s3_staging" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.frontend_staging.arn}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [var.cloudfront_staging_arn]
    }
  }
}
```

### [`modules/s3/variables.tf`](CinephoriaInfra/modules/s3/variables.tf)

```hcl
variable "bucket_prefix" {
  description = "Prefix for S3 bucket names"
  type        = string
  default     = "cinephoria-frontend"
}

variable "cloudfront_prod_arn" {
  description = "ARN of production CloudFront distribution"
  type        = string
}

variable "cloudfront_staging_arn" {
  description = "ARN of staging CloudFront distribution"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

### [`modules/s3/outputs.tf`](CinephoriaInfra/modules/s3/outputs.tf)

```hcl
output "prod_bucket_name" {
  description = "Production S3 bucket name"
  value       = aws_s3_bucket.frontend_prod.bucket
}

output "staging_bucket_name" {
  description = "Staging S3 bucket name"
  value       = aws_s3_bucket.frontend_staging.bucket
}

output "prod_bucket_arn" {
  description = "Production S3 bucket ARN"
  value       = aws_s3_bucket.frontend_prod.arn
}

output "staging_bucket_arn" {
  description = "Staging S3 bucket ARN"
  value       = aws_s3_bucket.frontend_staging.arn
}
```

## 🌍 Module CloudFront (CDN)

### [`modules/cloudfront/main.tf`](CinephoriaInfra/modules/cloudfront/main.tf)

```hcl
# Production Distribution
resource "aws_cloudfront_distribution" "prod" {
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100" # North America and Europe only
  aliases             = ["www.${var.domain_name}"]
  default_root_object = "index.html"

  origin {
    domain_name = var.s3_prod_domain_name
    origin_id   = "S3ProdOrigin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.prod.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3ProdOrigin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    compress = true
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = var.tags
}

# Staging Distribution
resource "aws_cloudfront_distribution" "staging" {
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"
  aliases             = ["staging.${var.domain_name}"]
  default_root_object = "index.html"

  origin {
    domain_name = var.s3_staging_domain_name
    origin_id   = "S3StagingOrigin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.staging.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3StagingOrigin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    compress = true
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = var.tags
}

# Origin Access Identities
resource "aws_cloudfront_origin_access_identity" "prod" {
  comment = "OAI for Cinephoria production"
}

resource "aws_cloudfront_origin_access_identity" "staging" {
  comment = "OAI for Cinephoria staging"
}
```

### [`modules/cloudfront/variables.tf`](CinephoriaInfra/modules/cloudfront/variables.tf)

```hcl
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
```

### [`modules/cloudfront/outputs.tf`](CinephoriaInfra/modules/cloudfront/outputs.tf)

```hcl
output "prod_distribution_id" {
  description = "Production CloudFront distribution ID"
  value       = aws_cloudfront_distribution.prod.id
}

output "staging_distribution_id" {
  description = "Staging CloudFront distribution ID"
  value       = aws_cloudfront_distribution.staging.id
}

output "prod_domain_name" {
  description = "Production CloudFront domain name"
  value       = aws_cloudfront_distribution.prod.domain_name
}

output "staging_domain_name" {
  description = "Staging CloudFront domain name"
  value       = aws_cloudfront_distribution.staging.domain_name
}

output "prod_arn" {
  description = "Production CloudFront ARN"
  value       = aws_cloudfront_distribution.prod.arn
}

output "staging_arn" {
  description = "Staging CloudFront ARN"
  value       = aws_cloudfront_distribution.staging.arn
}
```

## 🖥️ Module EC2 (Backend)

### [`modules/ec2/main.tf`](CinephoriaInfra/modules/ec2/main.tf)

```hcl
# Security Group
resource "aws_security_group" "cinephoria" {
  name_prefix = "cinephoria-"
  description = "Security group for Cinephoria EC2 instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this in production
  }

  ingress {
    from_port   = 5000
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# EC2 Instance
resource "aws_instance" "cinephoria" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.cinephoria.id]
  subnet_id              = var.subnet_id
  user_data              = templatefile("${path.module}/user-data.sh", {
    postgres_password = var.postgres_password
    domain_name       = var.domain_name
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  tags = merge(var.tags, {
    Name = "cinephoria-backend"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

# Elastic IP
resource "aws_eip" "cinephoria" {
  instance = aws_instance.cinephoria.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "cinephoria-eip"
  })
}

# AMI Data Source
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
```

### [`modules/ec2/user-data.sh`](CinephoriaInfra/modules/ec2/user-data.sh)

```bash
#!/bin/bash
# User data script for Cinephoria EC2 instance

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl enable docker
systemctl start docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Nginx
amazon-linux-extras install nginx1 -y
systemctl enable nginx
systemctl start nginx

# Create application directory
mkdir -p /opt/cinephoria

# Create docker-compose file for backend
cat << EOF > /opt/cinephoria/docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:15
    container_name: cinephoria-postgres
    environment:
      POSTGRES_DB: CinephoriaDB
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${postgres_password}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  backend-prod:
    image: cinephoria-backend:latest
    container_name: cinephoria-backend-prod
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ConnectionStrings__PostgreSql=Host=postgres;Port=5432;Database=CinephoriaDB_Production;Username=postgres;Password=${postgres_password}
    ports:
      - "5000:8080"
    depends_on:
      - postgres
    restart: unless-stopped

  backend-staging:
    image: cinephoria-backend:latest
    container_name: cinephoria-backend-staging
    environment:
      - ASPNETCORE_ENVIRONMENT=Staging
      - ConnectionStrings__PostgreSql=Host=postgres;Port=5432;Database=CinephoriaDB_Staging;Username=postgres;Password=${postgres_password}
    ports:
      - "5001:8080"
    depends_on:
      - postgres
    restart: unless-stopped

volumes:
  postgres_data:
EOF

# Create Nginx configuration
cat << EOF > /etc/nginx/conf.d/cinephoria.conf
server {
    listen 80;
    server_name api.${domain_name};
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 80;
    server_name staging-api.${domain_name};
    
    location / {
        proxy_pass http://localhost:5001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Reload Nginx
nginx -t && systemctl reload nginx

# Pull and start Docker containers
cd /opt/cinephoria
docker-compose pull
docker-compose up -d

echo "Cinephoria infrastructure setup completed!"
```

### [`modules/ec2/variables.tf`](CinephoriaInfra/modules/ec2/variables.tf)

```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the instance will be launched"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be launched"
  type        = string
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for Nginx configuration"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

### [`modules/ec2/outputs.tf`](CinephoriaInfra/modules/ec2/outputs.tf)

```hcl
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
```

## 📊 Module CloudWatch (Monitoring)

### [`modules/cloudwatch/main.tf`](CinephoriaInfra/modules/cloudwatch/main.tf)

```hcl
# CloudWatch Log Group for EC2
resource "aws_cloudwatch_log_group" "ec2" {
  name              = "/ec2/cinephoria"
  retention_in_days = 30

  tags = var.tags
}

# CloudWatch Alarm - High CPU
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "cinephoria-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  tags = var.tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "Cinephoria-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.ec2_instance_id],
            [".", "NetworkIn", ".", "."],
            [".", "NetworkOut", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "EC2 Instance Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", var.cloudfront_prod_id, "Region", "Global"],
            [".", "4xxErrorRate", ".", ".", ".", "."],
            [".", "5xxErrorRate", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1" # CloudFront metrics are in us-east-1
          title   = "CloudFront Production Metrics"
          period  = 300
        }
      }
    ]
  })
}
```

### [`modules/cloudwatch/variables.tf`](CinephoriaInfra/modules/cloudwatch/variables.tf)

```hcl
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
```

## 🏗️ Fichiers Principaux Terraform

### [`main.tf`](CinephoriaInfra/main.tf)

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Configure backend in terraform.tfvars
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
```

### [`variables.tf`](CinephoriaInfra/variables.tf)

```hcl
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
```

### [`outputs.tf`](CinephoriaInfra/outputs.tf)

```hcl
output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2.public_ip
}

output "cloudfront_prod_url" {
  description = "Production CloudFront distribution URL"
  value       = "https://${module.cloudfront.prod_domain_name}"
}

output "cloudfront_staging_url" {
  description = "Staging CloudFront distribution URL"
  value       = "https://${module.cloudfront.staging_domain_name}"
}

output "api_prod_url" {
  description = "Production API URL"
  value       = "https://api.${var.domain_name}"
}

output "api_staging_url" {
  description = "Staging API URL"
  value       = "https://staging-api.${var.domain_name}"
}

output "route53_name_servers" {
  description = "Route53 name servers for domain configuration"
  value       = module.route53.name_servers
}

output "s3_prod_bucket" {
  description = "Production S3 bucket name"
  value       = module.s3.prod_bucket_name
}

output "s3_staging_bucket" {
  description = "Staging S3 bucket name"
  value       = module.s3.staging_bucket_name
}
```

### [`terraform.tfvars.example`](CinephoriaInfra/terraform.tfvars.example)

```hcl
# AWS Configuration
region = "eu-west-3"

# Domain Configuration
domain_name = "cinephoria.eu"

# EC2 Configuration
ec2_instance_type = "t3.micro"
ec2_key_name      = "your-ssh-key-name"

# Database Configuration
postgres_password = "your-secure-postgres-password"

# CloudWatch Configuration
cloudwatch_alarm_actions = ["arn:aws:sns:eu-west-3:123456789012:alerts"]

# Tags
tags = {
  Environment = "production"
  Project     = "Cinephoria"
  Owner       = "YourTeam"
}

# Terraform Backend Configuration (uncomment and configure)
# terraform {
#   backend "s3" {
#     bucket = "your-terraform-state-bucket"
#     key    = "cinephoria/infrastructure.tfstate"
#     region = "eu-west-3"
#   }
# }
```

## 📖 Documentation

### [`README.md`](CinephoriaInfra/README.md)

```markdown
# Infrastructure AWS Cinephoria - Terraform

Ce projet Terraform déploie l'infrastructure AWS complète pour Cinephoria avec une architecture low-cost optimisée.

## 🏗️ Architecture

- **Frontend**: S3 + CloudFront (Production & Staging)
- **Backend**: EC2 t3.micro + Docker + Nginx
- **Database**: PostgreSQL via Docker (pas de RDS)
- **DNS**: Route53 avec sous-domaines multiples
- **SSL**: ACM wildcard certificate
- **Monitoring**: CloudWatch basique

## 🚀 Déploiement

### Prérequis

1. AWS CLI configuré avec les permissions appropriées
2. Terraform 1.0+
3. Domain `cinephoria.eu` configuré

### Étapes

1. **Configuration initiale**
   ```bash
   cd CinephoriaInfra
   cp terraform.tfvars.example terraform.tfvars
   # Éditer terraform.tfvars avec vos valeurs
   ```

2. **Initialisation**
   ```bash
   terraform init
   ```

3. **Planification**
   ```bash
   terraform plan
   ```

4. **Déploiement**
   ```bash
   terraform apply
   ```

### Coûts Estimés

- **EC2 t3.micro**: ~$8-10/mois
- **S3**: ~$1-2/mois (selon le trafic)
- **CloudFront**: ~$5-15/mois (selon le trafic)
- **Route53**: ~$0.50/mois
- **Total estimé**: ~$15-30/mois

## 🔧 Maintenance

### Mise à jour du Backend

1. Build des nouvelles images Docker
2. SSH vers l'instance EC2
3. Mettre à jour les containers:
   ```bash
   cd /opt/cinephoria
   docker-compose pull
   docker-compose up -d
   ```

### Déploiement du Frontend

1. Build Angular avec les environnements appropriés
2. Upload vers S3:
   ```bash
   # Production
   aws s3 sync dist/prod/ s3://cinephoria-frontend-prod/ --delete
   
   # Staging
   aws s3 sync dist/staging/ s3://cinephoria-frontend-staging/ --delete
   ```

## 🛠️ Modules

Le projet est organisé en modules réutilisables:

- `acm/`: Certificats SSL
- `cloudfront/`: Distributions CDN
- `ec2/`: Instance backend + configuration
- `route53/`: DNS et records
- `s3/`: Buckets frontend
- `cloudwatch/`: Monitoring et alertes

## 🔐 Sécurité

- Les buckets S3 sont privés (accès uniquement via CloudFront)
- Security group restrictif sur EC2
- Mots de passe via variables sensibles Terraform
- Certificats SSL wildcard via ACM
```

## 🚀 Plan de Mise en Œuvre

### Phase 1: Préparation
1. [ ] Configurer le domaine `cinephoria.eu` chez le registrar
2. [ ] Créer un bucket S3 pour le state Terraform
3. [ ] Générer une paire de clés SSH pour EC2
4. [ ] Configurer les variables dans `terraform.tfvars`

### Phase 2: Déploiement Infrastructure
1. [ ] Initialiser Terraform: `terraform init`
2. [ ] Vérifier le plan: `terraform plan`
3. [ ] Déployer l'infrastructure: `terraform apply`
4. [ ] Configurer les DNS avec les names servers Route53

### Phase 3: Configuration Backend
1. [ ] Build et push des images Docker backend
2. [ ] SSH vers l'instance EC2 pour vérifier l'installation
3. [ ] Tester les endpoints API

### Phase 4: Déploiement Frontend
1. [ ] Build Angular pour production et staging
2. [ ] Upload des fichiers vers les buckets S3
3. [ ] Tester les distributions CloudFront

### Phase 5: Validation
1. [ ] Tester tous les endpoints
2. [ ] Vérifier les certificats SSL
3. [ ] Configurer le monitoring CloudWatch
4. [ ] Documenter les procédures de maintenance

## 💰 Optimisations Coût

### Free Tier Compatible
- **EC2**: t3.micro (750h/mois gratuit)
- **S3**: 5GB standard storage gratuit
- **CloudFront**: 1TB data transfer out gratuit
- **Route53**: 1 hosted zone gratuit

### Réductions Supplémentaires
- Utilisation de `PriceClass_100` pour CloudFront
- Pas de RDS coûteux (PostgreSQL dans Docker)
- Logs CloudWatch avec rétention limitée (30 jours)
- Pas de Load Balancer (Nginx fait le routing)

Ce plan fournit une infrastructure AWS complète, sécurisée et économique pour Cinephoria, entièrement gérée via Terraform.