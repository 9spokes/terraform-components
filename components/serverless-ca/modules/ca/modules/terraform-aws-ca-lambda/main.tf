resource "aws_lambda_function" "lambda" {
  s3_bucket         = var.artifact.bucket
  s3_key            = var.artifact.key
  s3_object_version = var.artifact.version_id
  source_code_hash  = var.artifact.sha256
  function_name     = "${var.project}-${var.function_name}-${var.env}"
  description       = var.description
  role              = var.lambda_role_arn
  handler           = "${local.file_name}.lambda_handler"
  runtime           = var.runtime
  architectures     = [var.architecture]
  memory_size       = var.memory_size
  timeout           = var.timeout
  publish           = true
  tags              = var.tags

  environment {
    variables = var.function_name == "notify" ? local.slack_variables : local.ca_variables
  }

  tracing_config {
    mode = var.xray_enabled ? "Active" : "PassThrough"
  }

  lifecycle {
    postcondition {
      condition     = self.code_sha256 == var.artifact.sha256
      error_message = "AWS Lambda deployed code digest does not match the declared immutable artifact SHA-256 digest."
    }
  }
}

resource "aws_lambda_alias" "lambda" {
  name             = "live"
  description      = "Alias for ${var.project}-${var.function_name}-${var.env}"
  function_name    = aws_lambda_function.lambda.function_name
  function_version = aws_lambda_function.lambda.version
}

resource "aws_lambda_permission" "lambda_invoke" {
  for_each = toset(var.allowed_invocation_principals)

  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  qualifier     = aws_lambda_alias.lambda.name
  principal     = each.value
}
