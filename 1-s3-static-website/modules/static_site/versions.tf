terraform {
  required_version = ">= 1.14.0" # >= instead of ~>. Modules should be flexible.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}