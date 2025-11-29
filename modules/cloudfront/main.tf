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