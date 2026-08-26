output "cloudfront_domain_name" {
  value       = var.public_crl ? module.ca_cloudfront[0].cloudfront_domain_name : null
  description = "Domain name of CloudFront distribution used for public CRL"
}

output "ca_bundle_s3_key" {
  value       = local.ca_bundle_s3_key
  description = "S3 key (name) of CA bundle"
}

output "ca_bundle_s3_location" {
  value       = local.ca_bundle_s3_location
  description = "S3 location of CA bundle for use as a TrustStore"
}

output "external_s3_bucket_name" {
  value       = module.external_s3.s3_bucket_name
  description = "External S3 bucket name"
}

output "internal_s3_bucket_name" {
  value       = module.internal_s3.s3_bucket_name
  description = "Internal S3 bucket name"
}

output "issuing_ca_cert_s3_location" {
  value       = local.issuing_ca_cert_s3_location
  description = "S3 location of Issuing CA certificate file"
}

output "issuing_ca_crl_s3_location" {
  value       = local.issuing_ca_crl_s3_location
  description = "S3 location of Issuing CA CRL file"
}

output "root_ca_cert_s3_location" {
  value       = local.root_ca_cert_s3_location
  description = "S3 location of Root CA certificate file"
}

output "root_ca_crl_s3_location" {
  value       = local.root_ca_crl_s3_location
  description = "S3 location of Root CA CRL file"
}

output "sns_topic_arn" {
  value       = module.sns_ca_notifications.sns_topic_arn
  description = "SNS topic ARN"
}

output "lambda_functions" {
  description = "Operational Lambda names and ARNs; no private key material is exposed"
  value = {
    create_root_ca = {
      name = module.create_rsa_root_ca_lambda.lambda_function_name
      arn  = module.create_rsa_root_ca_lambda.lambda_arn
    }
    create_issuing_ca = {
      name = module.create_rsa_issuing_ca_lambda.lambda_function_name
      arn  = module.create_rsa_issuing_ca_lambda.lambda_arn
    }
    root_ca_crl = {
      name = module.rsa_root_ca_crl_lambda.lambda_function_name
      arn  = module.rsa_root_ca_crl_lambda.lambda_arn
    }
    issuing_ca_crl = {
      name = module.rsa_issuing_ca_crl_lambda.lambda_function_name
      arn  = module.rsa_issuing_ca_crl_lambda.lambda_arn
    }
    tls_cert = {
      name = module.rsa_tls_cert_lambda.lambda_function_name
      arn  = module.rsa_tls_cert_lambda.lambda_arn
    }
    expiry = length(module.expiry_lambda) == 0 ? null : {
      name = module.expiry_lambda[0].lambda_function_name
      arn  = module.expiry_lambda[0].lambda_arn
    }
    notify = length(module.notify_lambda) == 0 ? null : {
      name = module.notify_lambda[0].lambda_function_name
      arn  = module.notify_lambda[0].lambda_arn
    }
  }
}

output "state_machine" {
  value = {
    name = module.step-function.state_machine_name
    arn  = module.step-function.state_machine_arn
  }
}

output "scheduler" {
  value = {
    name  = module.scheduler.schedule_name
    arn   = module.scheduler.schedule_arn
    state = module.scheduler.schedule_state
  }
}

output "dynamodb_table" {
  value = {
    name = module.dynamodb.ddb_table_name
    arn  = module.dynamodb.ddb_table_arn
  }
}

output "kms_keys" {
  value = {
    tls_keygen = {
      arn   = module.kms_tls_keygen.kms_arn
      alias = module.kms_tls_keygen.kms_alias_name
    }
    root_ca = {
      arn   = module.kms_rsa_root_ca.kms_arn
      alias = module.kms_rsa_root_ca.kms_alias_name
    }
    issuing_ca = {
      arn   = module.kms_rsa_issuing_ca.kms_arn
      alias = module.kms_rsa_issuing_ca.kms_alias_name
    }
  }
}

output "s3_buckets" {
  value = {
    internal = {
      name = module.internal_s3.s3_bucket_name
      arn  = module.internal_s3.s3_bucket_arn
    }
    external = {
      name = module.external_s3.s3_bucket_name
      arn  = module.external_s3.s3_bucket_arn
    }
  }
}

output "database_reader_role_arn" {
  value = length(module.db-reader-role) == 0 ? null : module.db-reader-role[0].lambda_role_arn
}

output "certificate_locations" {
  value = {
    ca_bundle      = local.ca_bundle_s3_location
    root_ca        = local.root_ca_cert_s3_location
    issuing_ca     = local.issuing_ca_cert_s3_location
    root_ca_crl    = local.root_ca_crl_s3_location
    issuing_ca_crl = local.issuing_ca_crl_s3_location
  }
}

output "deployment_contract" {
  description = "Auditable artifact, authorization, and safety settings"
  value = {
    artifacts = {
      create_root_ca    = module.create_rsa_root_ca_lambda.deployment_contract.artifact
      create_issuing_ca = module.create_rsa_issuing_ca_lambda.deployment_contract.artifact
      root_ca_crl       = module.rsa_root_ca_crl_lambda.deployment_contract.artifact
      issuing_ca_crl    = module.rsa_issuing_ca_crl_lambda.deployment_contract.artifact
      tls_cert          = module.rsa_tls_cert_lambda.deployment_contract.artifact
      expiry            = var.lambda_artifacts["expiry"]
      notify            = var.lambda_artifacts["notify"]
    }
    principals = {
      tls_invocation          = module.rsa_tls_cert_lambda.deployment_contract.allowed_invocation_principals
      database_readers        = length(module.db-reader-role) == 0 ? [] : module.db-reader-role[0].trusted_principals
      external_bucket_readers = module.external_s3.security_contract.reader_principals
    }
    storage = {
      internal_s3                  = module.internal_s3.security_contract
      external_s3                  = module.external_s3.security_contract
      dynamodb_deletion_protection = module.dynamodb.deletion_protection_enabled
    }
    kms_deletion_windows = {
      tls_keygen = module.kms_tls_keygen.deletion_window_in_days
      root_ca    = module.kms_rsa_root_ca.deletion_window_in_days
      issuing_ca = module.kms_rsa_issuing_ca.deletion_window_in_days
    }
    logging = {
      lambda_retention_days        = module.rsa_tls_cert_lambda.deployment_contract.retention_in_days
      step_function_retention_days = module.step-function.log_retention_in_days
    }
    runtime = {
      name         = module.rsa_tls_cert_lambda.deployment_contract.runtime
      architecture = module.rsa_tls_cert_lambda.deployment_contract.architecture
    }
    manifest_keys = sort(keys(aws_s3_object.cert_info))
  }
}
