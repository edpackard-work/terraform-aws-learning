resource "aws_apigatewayv2_api" "http_api" {
  name          = "3-serverless-api"
  protocol_type = "HTTP"
}

#?
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"

  # Instruct the API to trigger specific Lambda
  integration_uri = aws_lambda_function.api_handler.invoke_arn
}

resource "aws_apigatewayv2_route" "generate_route" {
  api_id = aws_apigatewayv2_api.http_api.id

  # Users make a GET request to /generate - pragmatic decision for this sandbox toy to easily generate data to test
  route_key = "GET /generate"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Resource-Based Policy: like an IAM Role, tells Lambda what it can do, 
# This policy tells Lambda it is allowed to be invoked by API Gateway.
resource "aws_lambda_permission" "api_gw_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.function_name
  principal     = "apigateway.amazonaws.com"

  # Restrict invocation to ONLY this specific API Gateway
  source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}