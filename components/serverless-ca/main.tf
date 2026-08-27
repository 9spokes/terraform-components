locals {
  ca_project = coalesce(var.ca_project, module.this.id, "serverless-ca")
  ca_env     = coalesce(var.ca_environment, module.this.stage, "ca")
}

module "ca" {
  count  = module.this.enabled ? 1 : 0
  source = "./modules/ca"

  project   = local.ca_project
  env       = local.ca_env
  prod_envs = []

  root_ca_info        = var.root_certificate_profile
  issuing_ca_info     = var.issuing_certificate_profile
  root_ca_key_spec    = var.root_ca_key_spec
  issuing_ca_key_spec = var.issuing_ca_key_spec

  lambda_artifacts                      = var.lambda_artifacts
  lambda_architecture                   = var.lambda_architecture
  tls_invocation_principal_arns         = var.tls_invocation_principal_arns
  database_reader_principal_arns        = var.database_reader_principal_arns
  external_bucket_reader_principal_arns = var.external_bucket_reader_principal_arns

  max_cert_lifetime     = var.max_certificate_lifetime_days
  root_crl_days         = var.root_crl_lifetime_days
  root_crl_seconds      = var.crl_clock_skew_seconds
  issuing_crl_days      = var.issuing_crl_lifetime_days
  issuing_crl_seconds   = var.crl_clock_skew_seconds
  expiry_reminders      = var.expiry_reminder_days
  schedule_expression   = var.schedule_expression
  scheduler_enabled     = var.scheduler_enabled
  log_retention_in_days = var.log_retention_in_days
  memory_size           = var.lambda_memory_size
  timeout               = var.lambda_timeout
  xray_enabled          = var.xray_enabled

  bucket_prefix              = var.bucket_prefix
  kms_arn_resource           = var.resource_kms_key_arn
  kms_key_alias              = var.internal_bucket_kms_key_alias
  sse_algorithm              = var.internal_object_sse_algorithm
  default_aws_kms_key_for_s3 = var.use_aws_managed_s3_key
  bucket_key_enabled         = var.bucket_key_enabled
  access_logs                = var.access_logs
  log_bucket                 = var.access_log_bucket

  # The first Atmos API intentionally supports private publication only.
  public_crl                   = false
  hosted_zone_domain           = ""
  hosted_zone_id               = ""
  cloudfront_web_acl_id        = null
  slack_channels               = []
  sns_email_subscriptions      = []
  sns_lambda_subscriptions     = {}
  sns_sqs_subscriptions        = {}
  cert_info_files              = ["tls", "revoked", "revoked-root-ca"]
  dynamodb_deletion_protection = true

  tags = module.this.tags
}
