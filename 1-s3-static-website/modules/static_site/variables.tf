variable "bucket_name" {
  description = "The globally unique name for the S3 bucket"
  type        = string
}

variable "oac_name" {
  description = "The name of the OAC"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "html_source_path" {
  description = "The local file path to the index.html file"
  type        = string
}

variable "default_root_object" {
  description = "The default root object for the CloudFront distribution"
  type        = string
  default     = "index.html"
}