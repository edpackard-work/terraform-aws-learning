terraform {
  required_version = "~> 1.14.8"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-2"
}

# Create the S3 Bucket
resource "aws_s3_bucket" "static_website" { # "static_website" is tf's reference to resource
  bucket = "ep-learning-bucket-24-4-26-v2"  # IMPORTANT: This must be globally unique!
  tags = {
    Name        = "ep-tf"
    Environment = "ep-learning"
  }
}

resource "aws_cloudfront_origin_access_control" "website_oac" {
  name                              = "ep-learning-OAC-24-4-26"
  description                       = "Basic OAC Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.static_website.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.website_oac.id
    origin_id                = "s3_website_root"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "EP Day 1 sandbox static site"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3_website_root"

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
  }


  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name        = "ep-tf"
    Environment = "ep-learning"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.static_website.id
  key          = "index.html"
  source       = "index.html"
  content_type = "text/html"
}

# 1. define policy
data "aws_iam_policy_document" "allow_cloudfront_oac_access" {
  statement {
    # Who is allowed? (CloudFront Service)
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    # What are they allowed to do? (Only read files.)
    actions = ["s3:GetObject"]

    # Where are they allowed to do it? (Every file inside specified bucket.)
    resources = ["${aws_s3_bucket.static_website.arn}/*"]

    # important - only allow if the request is coming from specified CloudFront distribution.
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}

# 2. attach policy to bucket
resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.static_website.id
  policy = data.aws_iam_policy_document.allow_cloudfront_oac_access.json
}

output "website_url" {
  description = "The public URL of our CloudFront distribution"
  value       = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
}