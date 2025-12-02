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
}

resource "aws_route53_record" "staging" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "staging-app.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.cloudfront_staging_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
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