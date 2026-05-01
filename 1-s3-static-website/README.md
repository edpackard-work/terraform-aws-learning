# Secure S3 Static Website with CloudFront

## Overview
This repository deploys a secure static website. It uses an AWS S3 bucket to host the HTML content and a CloudFront distribution to serve it to the public internet.

It uses Origin Access Control (OAC) and an S3 Public Access Block to ensure the S3 bucket is invisible to the public internet and can only be accessed through CloudFront.

## Architecture
Frontend: HTML located in the `/app` directory.

Storage: AWS S3 Bucket (Private - Public Access Blocked).

CDN: AWS CloudFront Distribution.

Security: CloudFront OAC + IAM S3 Bucket Policy.

## Directory Structure
`/app/` - Contains the application source code (`index.html`).

`/modules/static_site/` - Reusable Terraform module for the web infrastructure.

`./` - Root Terraform configuration (calls the module and sets up the AWS provider).

## Prerequisites
Terraform CLI (`>= 1.14.0`)

AWS CLI configured with MT sandbox credentials.

Pre-commit hooks installed (`pre-commit install`) for TFLint and formatting.

## Deployment Instructions
1. Initialize Terraform:

`terraform init`

2. Review the Plan:

`terraform plan`

3. Deploy the Infrastructure:

`terraform apply`

(Note: CloudFront deployments can take 3-5 minutes to propagate globally).

4. View the Site:
The CloudFront URL will be printed in your terminal as `cloudfront_url` after a successful apply.

Teardown
To prevent sandbox drift and unnecessary AWS charges, destroy the infrastructure when finished:

`terraform destroy`