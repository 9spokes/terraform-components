mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111111111111"
      arn        = "arn:aws:iam::111111111111:root"
    }
  }

  mock_data "aws_region" {
    defaults = {
      id     = "ap-southeast-2"
      name   = "ap-southeast-2"
      region = "ap-southeast-2"
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      arn         = "arn:aws:lambda:ap-southeast-2:111111111111:function:example-tls-cert-test"
      code_sha256 = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      version     = "1"
    }
  }

  mock_resource "aws_lambda_alias" {
    defaults = {
      arn = "arn:aws:lambda:ap-southeast-2:111111111111:function:example-tls-cert-test:live"
    }
  }
}

variables {
  architecture = "x86_64"
  artifact = {
    architecture = "x86_64"
    bucket       = "immutable-artifacts"
    key          = "serverless-ca/tls-cert-x86_64.zip"
    version_id   = "version-tls-cert"
    sha256       = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  }
  description     = "Issue TLS certificates"
  env             = "test"
  filter_pattern  = ""
  function_name   = "tls-cert"
  lambda_role_arn = "arn:aws:iam::111111111111:role/example-tls-cert-test"
  runtime         = "python3.14"
}

run "matching_service_digest_is_accepted" {
  command = apply
}

run "matching_updated_service_digest_is_accepted" {
  command = apply

  variables {
    artifact = {
      architecture = "x86_64"
      bucket       = "immutable-artifacts"
      key          = "serverless-ca/tls-cert-x86_64.zip"
      version_id   = "version-tls-cert-2"
      sha256       = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
    }
  }

  override_resource {
    target = aws_lambda_function.lambda
    values = {
      code_sha256 = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
    }
  }
}
