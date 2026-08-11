output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}

output "trusted_principals" {
  value = var.aws_principals
}
