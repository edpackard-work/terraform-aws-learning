resource "aws_dynamodb_table" "main" {
  name         = "3-serverless-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S" # String
  }
}