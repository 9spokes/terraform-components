output "lambda_arn" {
  value       = aws_lambda_alias.lambda.arn
  description = "ARN of the immutable live Lambda alias"
}

output "lambda_function_arn" {
  value       = aws_lambda_function.lambda.arn
  description = "Unqualified ARN of the Lambda function"
}

output "lambda_function_name" {
  value       = aws_lambda_function.lambda.function_name
  description = "Name of the Lambda function"
}

output "deployment_contract" {
  description = "Immutable deployment and runtime settings used by this function"
  value = {
    artifact                      = var.artifact
    runtime                       = var.runtime
    architecture                  = var.architecture
    retention_in_days             = var.retention_in_days
    allowed_invocation_principals = var.allowed_invocation_principals
  }
}
