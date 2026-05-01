resource "aws_s3_bucket" "static_website" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "website_bucket_lockdown" {
  bucket = aws_s3_bucket.static_website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "website_oac" {
  name                              = var.oac_name
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
  comment             = "A static site"
  default_root_object = var.default_root_object

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

  tags = var.tags

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.static_website.id
  key          = "index.html"
  source       = var.html_source_path
  content_type = "text/html"
  etag         = filemd5(var.html_source_path)
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