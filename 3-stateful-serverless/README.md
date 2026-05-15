# Day 3: Stateful Serverless Architecture

## Overview
This directory contains the Terraform configuration for a fully serverless, event-driven HTTP API. It provisions an Amazon API Gateway, an AWS Lambda function running Node.js, and an Amazon DynamoDB table. 

The primary focus of this architecture is operational efficiency (scaling automatically to zero when not in use) and strict security governance via AWS Identity and Access Management (IAM).

## Architecture Breakdown

### 1. Database (`dynamodb.tf`)
* **Amazon DynamoDB:** A NoSQL database table (`3-serverless-table`) configured with on-demand capacity (`PAY_PER_REQUEST`). 
* **Partition Key:** A string field named `id`.

### 2. Compute (`lambda.tf` & `lambda/index.js`)
* **AWS Lambda:** A serverless compute function running the Node.js 20.x runtime. 
* **Application Logic:** Uses the AWS SDK for JavaScript v3 to generate a random UUID and insert a new item (the UUID and a timestamp) into the DynamoDB table.
* **Deployment Mechanism:** Terraform uses the `archive_file` data source to automatically compress the `index.js` file into a `.zip` artifact during the `terraform apply` phase. It tracks the `source_code_hash` to only trigger redeployments when the source code is modified.

### 3. API Gateway (`api_gateway.tf`)
* **HTTP API Gateway:** Acts as the public-facing entry point for the Lambda function.
* **Routing:** Configured with a `GET /generate` route.
* **Resource-Based Policy:** The Lambda function includes a permission statement explicitly allowing this specific API Gateway to invoke it.

### 4. Security Boundaries (`iam.tf`)
* **Execution Role:** The Lambda function operates under a dedicated IAM Role built on the Principle of Least Privilege.
* **Strict Scoping:** The IAM Policy attached to the role explicitly allows the `dynamodb:PutItem` action and restricts that action to the exact Amazon Resource Name (ARN) of the deployed DynamoDB table. It cannot read, update, or delete data, nor can it access any other tables in the AWS account.

## File Structure
```text
day-3-serverless/
├── infrastructure/
│   ├── api_gateway.tf
│   ├── dynamodb.tf
│   ├── iam.tf
│   ├── lambda.tf
│   ├── outputs.tf
│   └── providers.tf
└── lambda/
    ├── index.js
    └── unhappy_path_index.js.example
```

## Deployment and verification

Deploy the infrastructure from the infrastructure/ directory:

```bash
terraform init
terraform apply
```

### 1. The Happy Path (integration testing)
Once deployed, Terraform will output the `api_gateway_url`. Run the following command in your terminal to trigger the Lambda function:

```bash
curl <api_gateway_url>/generate
```

**Expected Result:** A `200 OK` response with a JSON payload containing a newly generated UUID. You can verify the insertion by navigating to the DynamoDB console and checking the `3-serverless-table` items.

### 2. The Unhappy Path (security testing)
To verify the IAM boundaries, attempt to execute malicious code violating the execution role's permissions.
- Replace the contents of `lambda/index.js` with the contents of `lambda/unhappy_path_index.js.example`.
- Run `terraform apply` to deploy malicious code.
- Trigger API again via `curl`.

**Expected ResultL** A `500 Internal Server Error`. If you check CloudWatch Logs for the Lambda function, you will find an `AccessDeniedException` proving that AWS IAM successfully blocked the function from scanning unauthorised database tables.