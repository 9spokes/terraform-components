variable "access_logs" {
  type        = bool
  description = "Enable access logs for S3 buckets, requires log_bucket variable to be set"
  default     = false
}

variable "additional_dynamodb_tags" {
  type        = map(string)
  description = "Tags added to DynamoDB tables, merged with default tags"
  default     = {}
}

variable "additional_lambda_tags" {
  type        = map(string)
  description = "Tags added to Lambda functions, merged with default tags"
  default     = {}
}

variable "additional_s3_tags" {
  type        = map(string)
  description = "Tags added to S3 buckets, merged with default tags"
  default     = {}
}

variable "database_reader_principal_arns" {
  type        = list(string)
  description = "Principal ARNs allowed to assume the read-only DynamoDB role"
  default     = []
}

variable "bucket_prefix" {
  type        = string
  description = "First part of s3 bucket name to ensure uniqueness, if left blank a random suffix will be used instead"
  default     = ""
}

variable "cert_info_files" {
  type        = list(string)
  description = "List of file names to be uploaded to internal S3 bucket for processing"
  default     = ["tls", "revoked", "revoked-root-ca"]

  validation {
    condition     = length(toset(var.cert_info_files)) == 3 && alltrue([for name in ["tls", "revoked", "revoked-root-ca"] : contains(var.cert_info_files, name)])
    error_message = "cert_info_files must contain tls, revoked, and revoked-root-ca so the operational handoff is complete."
  }
}

variable "cloudfront_geo_restricted_locations" {
  type        = list(string)
  description = "List of countries to block from CloudFront Distribution"
  default = [
    "CN",
    "IR",
    "KP",
    "RU",
  ]
}

variable "cloudfront_minimum_protocol_version" {
  type        = string
  description = "CloudFront minimum TLS protocol version"
  default     = "TLSv1.2_2021"
}

variable "cloudfront_web_acl_id" {
  type        = string
  description = "WAF attachment for the public CRL CloudFront distribution, expects the WAF ARN"
  default     = null
}

variable "custom_sns_topic_display_name" {
  type        = string
  description = "Customised SNS topic display name, leave empty to use standard naming convention"
  default     = ""
}

variable "custom_sns_topic_name" {
  type        = string
  description = "Customised SNS topic name, leave empty to use standard naming convention"
  default     = ""
}

variable "dynamodb_deletion_protection" {
  type        = bool
  description = "Enable deletion protection for the DynamoDB table"
  default     = true
}

variable "env" {
  type        = string
  description = "Environment name, e.g. dev"
  default     = "dev"
}

variable "expiry_reminders" {
  type        = list(number)
  description = "List of days before certificate expiry to send reminder notifications, set to empty list to disable expiry reminders"
  default     = [30, 15, 7, 1]
}

variable "filter_pattern" {
  type        = string
  description = "Filter pattern for CloudWatch logs subscription filter"
  default     = ""
}

variable "hosted_zone_domain" {
  type        = string
  description = "Hosted zone domain, e.g. dev.ca.example.com"
  default     = ""
}

variable "hosted_zone_id" {
  type        = string
  description = "Hosted zone ID for public zone, e.g. Z0123456XXXXXXXXXXX"
  default     = ""
}

variable "issuing_ca_info" {
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

  description = "Issuing CA certificate information"
  default = {
    country              = "GB"
    state                = "London"
    lifetime             = 3650
    locality             = "London"
    organization         = "Serverless"
    organizationalUnit   = "IT"
    commonName           = "Serverless Issuing CA"
    emailAddress         = null
    pathLengthConstraint = null
  }
}

variable "issuing_ca_key_spec" {
  type        = string
  description = "Issuing CA key specification"
  default     = "ECC_NIST_P256"

  validation {
    condition = contains([
      "RSA_2048",
      "RSA_3072",
      "RSA_4096",
      "ECC_NIST_P256",
      "ECC_NIST_P384",
      "ECC_NIST_P521",
    ], var.issuing_ca_key_spec)
    error_message = "Invalid issuing_ca_key_spec"
  }
}

variable "issuing_crl_days" {
  type        = number
  description = "Number of days before Issuing CA CRL expires, in addition to seconds. Must be greater than or equal to Step Function interval"
  default     = 1
}

variable "issuing_crl_seconds" {
  type        = number
  description = "Number of seconds before Issuing CA CRL expires, in addition to days. Used for overlap in case of clock skew"
  default     = 600
}

variable "kms_key_alias" {
  type        = string
  description = "KMS key alias for bucket encryption with key rotation disabled, if left at default, TLS key gen KMS key will be used"
  default     = ""
}

variable "kms_arn_resource" {
  type        = string
  description = "KMS key ARN used for general resource encryption, different from key used for CA key protection"
  default     = ""
}

variable "default_aws_kms_key_for_s3" {
  type        = bool
  description = "Use default AWS KMS key instead of customer managed key for S3 bucket encryption. Applicable only if \"sse_algorithm\" is \"aws:kms\""
  default     = false
}

variable "bucket_key_enabled" {
  type        = bool
  description = "Whether or not to use Amazon S3 Bucket Keys for SSE-KMS"
  default     = false
}

variable "log_bucket" {
  type        = string
  description = "Name of log bucket, if access_logs variable set to true"
  default     = ""
}

variable "logging_account_id" {
  type        = string
  description = "AWS Account ID of central logging account for CloudWatch subscription filters"
  default     = ""
}

variable "lambda_artifacts" {
  description = "Immutable, versioned S3 artifacts for all Serverless CA Lambda functions. sha256 is base64 encoded."
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
    error_message = "lambda_artifacts must define exactly the seven supported function artifacts."
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

variable "log_retention_in_days" {
  type        = number
  description = "CloudWatch retention for Lambda and Step Functions logs"
  default     = 365
}

variable "max_cert_lifetime" {
  type        = number
  description = "Maximum end entity certificate lifetime in days"
  default     = 365
}

variable "custom_extension_allowlist" {
  type        = list(string)
  description = "List of X.509 extension OIDs callers may include via the 'extensions' field when requesting a TLS certificate. Empty by default, which disables the feature. Extensions the CA emits itself (basicConstraints, keyUsage, subjectAltName, extendedKeyUsage, etc.) are always rejected regardless of this list."
  default     = []
}

variable "memory_size" {
  type        = number
  description = "Standard memory allocation for Lambda functions"
  default     = 128
}

variable "prod_envs" {
  type        = list(string)
  description = "List of production environment names, for these names the environment name suffix is not required in resource names"
  default     = ["prd", "prod"]
}

variable "project" {
  type        = string
  description = "abbreviation for the project, forms first part of resource names"
  default     = "serverless"
}

variable "public_crl" {
  type        = bool
  description = "Whether to make the CRL and CA certificates publicly available"
  default     = false
}

variable "root_ca_info" {
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

  description = "Root CA certificate information"
  default = {
    country              = "GB"
    state                = "London"
    lifetime             = 7300
    locality             = "London"
    organization         = "Serverless"
    organizationalUnit   = "IT"
    commonName           = "Serverless Root CA"
    emailAddress         = null
    pathLengthConstraint = null
  }
}

variable "root_ca_key_spec" {
  type        = string
  description = "Root CA key specification"
  default     = "ECC_NIST_P384"

  validation {
    condition = contains([
      "RSA_2048",
      "RSA_3072",
      "RSA_4096",
      "ECC_NIST_P256",
      "ECC_NIST_P384",
      "ECC_NIST_P521",
    ], var.root_ca_key_spec)
    error_message = "Invalid root_ca_key_spec"
  }
}

variable "root_crl_days" {
  type        = number
  description = "Number of days before Root CA CRL expires, in addition to seconds. Must be greater than or equal to Step Function interval"
  default     = 1
}

variable "root_crl_seconds" {
  type        = number
  description = "Number of seconds before Root CA CRL expires, in addition to days. Used for overlap in case of clock skew"
  default     = 600
}

variable "external_bucket_reader_principal_arns" {
  type        = list(string)
  description = "Principal ARNs allowed to read the private CA publication bucket"
  default     = []
}

variable "tls_invocation_principal_arns" {
  type        = list(string)
  description = "Principal ARNs allowed to invoke the direct TLS issuance Lambda"
  default     = []
}

variable "schedule_expression" {
  type        = string
  description = "Step function schedule in cron format, must be daily or more frequent for expiry reminders to work correctly, interval should be same as issuing_crl_days"
  default     = "cron(15 8 * * ? *)" # 8.15 a.m. daily
}

variable "slack_bad_emoji" {
  description = "Slack emoji for bad events"
  default     = ":octagonal_sign:"
  type        = string
}

variable "slack_channels" {
  description = "List of Slack Channels"
  default     = []
  type        = list(string)
}

variable "slack_good_emoji" {
  description = "Slack emoji for good events"
  default     = ":white_check_mark:"
  type        = string
}

variable "slack_token" {
  type        = string
  description = "Slack App OAuth token"
  default     = ""
  sensitive   = true
}

variable "slack_username" {
  description = "Slack username appearing in the from field in the Slack message"
  default     = "Serverless CA"
  type        = string
}

variable "slack_warning_emoji" {
  description = "Slack emoji for warning events"
  default     = ":warning:"
  type        = string
}

variable "secret_recovery_window_in_days" {
  description = "Number of days that AWS Secrets Manager waits before deleting a secret"
  type        = number
  default     = 7
}

variable "sns_email_subscriptions" {
  type        = list(string)
  description = "List of email addresses to subscribe to SNS topic"
  default     = []
}

variable "sns_lambda_subscriptions" {
  type        = map(string)
  description = "A map of lambda names to arns to subscribe to SNS topic"
  default     = {}
}

variable "sns_policy" {
  type        = string
  description = "A string containing the SNS policy, if used"
  default     = ""
}

variable "sns_policy_template" {
  type        = string
  description = "Name of SNS policy template file, if used"
  default     = "default"
}

variable "sns_sqs_subscriptions" {
  type        = map(string)
  description = "A map of SQS names to arns to subscribe to the SNS topic"
  default     = {}
}

variable "sse_algorithm" {
  type        = string
  description = "Server side encryption algorithm for internal S3 bucket object upload"
  default     = ""

  validation {
    condition = contains([
      "AES256",
      "aws:kms",
      "",
    ], var.sse_algorithm)
    error_message = "Invalid sse_algorithm"
  }
}

variable "subscription_filter_destination" {
  type        = string
  description = "CloudWatch log subscription filter destination, last section of ARN"
  default     = ""
}

# see also additional_s3_tags, additional_dynamodb_tags, additional_lambda_tags
variable "tags" {
  type    = map(string)
  default = {}
}

variable "timeout" {
  type        = number
  description = "Amount of time Lambda Function has to run in seconds"
  default     = 180
}

variable "workload_account_id" {
  type        = string
  description = "Workload account ID allowed to subscribe to SNS topic if cross-account policy used"
  default     = ""
}

variable "xray_enabled" {
  type        = bool
  description = "Whether to enable active tracing with AWS X-Ray"
  default     = true
}
