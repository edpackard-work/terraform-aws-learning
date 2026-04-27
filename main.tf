module "my_sandbox_website" {
  source = "./modules/static_site"

  bucket_name      = "ep-learning-bucket-24-4-26-v3"
  oac_name         = "ep-learning-oac"
  html_source_path = "${path.root}/app/index.html"
  tags = {
    Name        = "ep-tf"
    Environment = "ep-learning"
  }
}

output "cloudfront_url" {
  value = module.my_sandbox_website.website_url
}