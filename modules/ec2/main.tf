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