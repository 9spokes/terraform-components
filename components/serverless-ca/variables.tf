variable "region" {
  type        = string
  description = "AWS region"
}

variable "ca_project" {
  type        = string
  description = "Optional upstream project naming override"
  default     = null
  nullable    = true
}

variable "ca_environment" {
  type        = string
  description = "Optional upstream environment naming override"
  default     = null
  nullable    = true
}

variable "root_certificate_profile" {
  description = "Root CA subject and lifetime"
  type = object({
    commonName           = string
    country              = optional(string)
    state                = optional(string)
    lifetime             = optional(number)
    locality             = optional(string)
    organization         = optional(string)
    organizationalUnit   = optional(string)
    emailAddress         = optional(string)
    pathLengthConstraint = optional(number)
  })
}

variable "issuing_certificate_profile" {
  description = "Issuing CA subject and lifetime"
  type = object({
    commonName           = string
    country              = optional(string)
    state                = optional(string)
    lifetime             = optional(number)
    locality             = optional(string)
    organization         = optional(string)
    organizationalUnit   = optional(string)
    emailAddress         = optional(string)
    pathLengthConstraint = optional(number)
  })
}

variable "root_ca_key_spec" {
  type        = string
  description = "KMS asymmetric key specification for the root CA"
  default     = "ECC_NIST_P384"
}

variable "issuing_ca_key_spec" {
  type        = string
  description = "KMS asymmetric key specification for the issuing CA"
  default     = "ECC_NIST_P256"
}

variable "lambda_artifacts" {
  description = "Immutable S3 artifacts for all seven Lambda functions; sha256 is base64 encoded"
  type = map(object({
    bucket     = string
    key        = string
    version_id = string
    sha256     = string
  }))

  validation {
    condition = length(var.lambda_artifacts) == 7 && alltrue([
      for name in ["create_root_ca", "create_issuing_ca", "root_ca_crl", "issuing_ca_crl", "tls_cert", "expiry", "notify"] : contains(keys(var.lambda_artifacts), name)
    ])
    error_message = "lambda_artifacts must define exactly the seven supported functions."
  }

  validation {
    condition = alltrue([
      for artifact in values(var.lambda_artifacts) : (
        artifact.bucket != "" &&
        artifact.key != "" &&
        artifact.version_id != "" &&
        can(regex("^[A-Za-z0-9+/]{43}=$", artifact.sha256))
      )
    ])
    error_message = "Every Lambda artifact requires a bucket, key, S3 version ID, and base64-encoded SHA-256 digest."
  }
}

variable "tls_invocation_principal_arns" {
  type        = list(string)
  description = "Principal ARNs allowed to invoke direct TLS issuance"
  default     = []
}

variable "database_reader_principal_arns" {
  type        = list(string)
  description = "Principal ARNs allowed to assume the DynamoDB reader role"
  default     = []
}

variable "external_bucket_reader_principal_arns" {
  type        = list(string)
  description = "Principal ARNs allowed to read the private CA publication bucket"
  default     = []
}

variable "schedule_expression" {
  type        = string
  description = "EventBridge Scheduler expression for GitOps issuance and revocation"
  default     = "cron(15 8 * * ? *)"
}

variable "scheduler_enabled" {
  type        = bool
  description = "Enable scheduled GitOps issuance only after operator CA initialization and verification"
  default     = false
}

variable "max_certificate_lifetime_days" {
  type        = number
  description = "Maximum end-entity certificate lifetime"
  default     = 365
}

variable "root_crl_lifetime_days" {
  type        = number
  description = "Root CRL lifetime"
  default     = 1
}

variable "issuing_crl_lifetime_days" {
  type        = number
  description = "Issuing CRL lifetime"
  default     = 1
}

variable "crl_clock_skew_seconds" {
  type        = number
  description = "Additional CRL validity for clock skew"
  default     = 600
}

variable "expiry_reminder_days" {
  type        = list(number)
  description = "Days before expiry at which notifications are published"
  default     = [30, 15, 7, 1]
}

variable "log_retention_in_days" {
  type        = number
  description = "CloudWatch log retention for Lambda and Step Functions"
  default     = 365
}

variable "lambda_memory_size" {
  type        = number
  description = "Memory size for each Lambda function"
  default     = 256
}

variable "lambda_timeout" {
  type        = number
  description = "Timeout for each Lambda function"
  default     = 180
}

variable "xray_enabled" {
  type        = bool
  description = "Enable active X-Ray tracing"
  default     = true
}

variable "bucket_prefix" {
  type        = string
  description = "Optional globally unique S3 bucket prefix"
  default     = ""
}

variable "resource_kms_key_arn" {
  type        = string
  description = "Optional separate symmetric KMS key ARN for state encryption"
  default     = ""
}

variable "internal_bucket_kms_key_alias" {
  type        = string
  description = "Optional KMS alias for the internal bucket"
  default     = ""
}

variable "internal_object_sse_algorithm" {
  type        = string
  description = "Optional explicit server-side encryption algorithm for manifest objects"
  default     = ""

  validation {
    condition     = contains(["", "AES256", "aws:kms"], var.internal_object_sse_algorithm)
    error_message = "internal_object_sse_algorithm must be empty, AES256, or aws:kms."
  }
}

variable "use_aws_managed_s3_key" {
  type        = bool
  description = "Use the AWS-managed S3 KMS key instead of the CA resource key"
  default     = false
}

variable "bucket_key_enabled" {
  type        = bool
  description = "Enable S3 bucket keys for SSE-KMS"
  default     = true
}

variable "access_logs" {
  type        = bool
  description = "Enable S3 access logging"
  default     = false
}

variable "access_log_bucket" {
  type        = string
  description = "S3 access log destination when access_logs is enabled"
  default     = ""
}
