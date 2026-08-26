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

  mock_resource "aws_kms_key" {
    defaults = {
      arn    = "arn:aws:kms:ap-southeast-2:111111111111:key/00000000-0000-0000-0000-000000000000"
      key_id = "00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_kms_alias" {
    defaults = {
      arn            = "arn:aws:kms:ap-southeast-2:111111111111:alias/mock"
      target_key_arn = "arn:aws:kms:ap-southeast-2:111111111111:key/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111111111111:role/serverless-ca-test"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:ap-southeast-2:111111111111:log-group:serverless-ca-test"
    }
  }

  mock_resource "aws_sfn_state_machine" {
    defaults = {
      arn = "arn:aws:states:ap-southeast-2:111111111111:stateMachine:serverless-ca-test"
    }
  }
}

variables {
  project = "example-ca"
  env     = "test"

  lambda_artifacts = {
    for name in ["create_root_ca", "create_issuing_ca", "root_ca_crl", "issuing_ca_crl", "tls_cert", "expiry", "notify"] : name => {
      bucket     = "immutable-artifacts"
      key        = "serverless-ca/${name}.zip"
      version_id = "version-${name}"
      sha256     = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    }
  }

  tls_invocation_principal_arns         = ["arn:aws:iam::111111111111:role/issuer"]
  database_reader_principal_arns        = ["arn:aws:iam::222222222222:role/reader"]
  external_bucket_reader_principal_arns = ["arn:aws:iam::333333333333:role/trust-store-reader"]
}

run "private_hardened_defaults" {
  command = plan

  assert {
    condition     = length(module.ca_cloudfront) == 0 && length(module.cloudfront_certificate) == 0
    error_message = "Private defaults must not create CloudFront, Route53, or ACM resources."
  }

  assert {
    condition = alltrue([
      !output.deployment_contract.storage.internal_s3.force_destroy,
      !output.deployment_contract.storage.external_s3.force_destroy,
      output.deployment_contract.storage.internal_s3.versioning == "Enabled",
      output.deployment_contract.storage.external_s3.versioning == "Enabled",
      output.deployment_contract.storage.internal_s3.block_public_policy,
      output.deployment_contract.storage.external_s3.block_public_policy,
      output.deployment_contract.storage.dynamodb_deletion_protection,
    ])
    error_message = "Storage must be non-destructive, versioned, private, and deletion protected."
  }

  assert {
    condition     = alltrue([for days in values(output.deployment_contract.kms_deletion_windows) : days == 30])
    error_message = "Every KMS key must use a 30-day deletion window."
  }

  assert {
    condition = (
      output.deployment_contract.logging.lambda_retention_days == 365 &&
      output.deployment_contract.logging.step_function_retention_days == 365
    )
    error_message = "Lambda and Step Functions logs must retain 365 days by default."
  }

  assert {
    condition = (
      output.deployment_contract.runtime.name == "python3.14" &&
      output.deployment_contract.runtime.architecture == "x86_64"
    )
    error_message = "Runtime is fixed to Python 3.14 on x86_64."
  }

  assert {
    condition = alltrue([
      toset(output.deployment_contract.principals.tls_invocation) == toset(var.tls_invocation_principal_arns),
      toset(output.deployment_contract.principals.database_readers) == toset(var.database_reader_principal_arns),
      toset(output.deployment_contract.principals.external_bucket_readers) == toset(var.external_bucket_reader_principal_arns),
    ])
    error_message = "Invocation, database, and publication readers must remain separate."
  }

  assert {
    condition     = toset(output.deployment_contract.manifest_keys) == toset(["revoked", "revoked-root-ca", "tls"])
    error_message = "All three operational manifests must be seeded."
  }

  assert {
    condition = alltrue([
      for name, artifact in output.deployment_contract.artifacts : artifact == var.lambda_artifacts[name]
    ])
    error_message = "Each function must receive its exact immutable artifact."
  }

  assert {
    condition     = output.scheduler.state == "DISABLED"
    error_message = "The scheduler must be disabled until an operator initializes and verifies the CA."
  }
}

run "scheduler_can_be_explicitly_enabled" {
  command = plan

  variables {
    scheduler_enabled = true
  }

  assert {
    condition     = output.scheduler.state == "ENABLED"
    error_message = "The scheduler must enable only when scheduler_enabled is explicitly true."
  }
}
