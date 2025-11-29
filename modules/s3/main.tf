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