output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}

output "trusted_principals" {
  value = var.aws_principals
}

output "policy_document" {
  description = "Rendered inline IAM policy document"
  value       = aws_iam_role_policy.lambda.policy
}
