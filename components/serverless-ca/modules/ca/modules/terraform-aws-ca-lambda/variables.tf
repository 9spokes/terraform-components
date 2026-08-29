variable "allowed_invocation_principals" {
  description = "List of principals allowed to invoke this lambda"
  default     = []
}

variable "artifact" {
  description = "Immutable S3 artifact for this Lambda function. sha256 is the base64-encoded SHA-256 digest expected by AWS Lambda."
  type = object({
    architecture = string
    bucket       = string
    key          = string
    version_id   = string
    sha256       = string
  })

  validation {
    condition = (
      var.artifact.architecture == var.architecture &&
      var.artifact.bucket != "" &&
      var.artifact.key != "" &&
      var.artifact.version_id != "" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.artifact.sha256))
    )
    error_message = "The Lambda artifact architecture must match the function and requires a bucket, key, S3 version ID, and base64-encoded SHA-256 digest."
  }
}

variable "architecture" {
  type        = string
  description = "Instruction set architecture for this Lambda function"

  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "architecture must be x86_64 or arm64."
  }
}

variable "enable_subscription_filters" {
  description = "Enable CloudWatch logs Subscription filters for CA Lambda functions"
  default     = false
}

variable "custom_extension_allowlist" {
  description = "List of X.509 extension OIDs callers may include via the 'extensions' request field. Empty by default, which disables the feature."
  type        = list(string)
  default     = []
}

variable "description" {
  description = "description of Lambda function purpose"
}

variable "dynamodb_table_name" {
  description = "Exact DynamoDB table name created by Terraform; CA functions read it instead of deriving a name"
  type        = string
  default     = null

  validation {
    condition     = var.function_name == "notify" || (var.dynamodb_table_name != null && var.dynamodb_table_name != "")
    error_message = "Every CA function must receive the Terraform-created DynamoDB table name."
  }
}

variable "domain" {
  description = "Hosted zone domain, e.g. dev.ca.example.com"
  default     = ""
}

variable "env" {
  description = "Environment name, e.g. dev"
}

variable "expiry_reminders" {
  description = "List of days before certificate expiration to send reminders"
  default     = []
}

variable "external_s3_bucket" {
  description = "External S3 Bucket Name"
  default     = ""
}

variable "filter_pattern" {
  description = "Filter pattern for CloudWatch logs subscription filter"
}

variable "function_name" {
  description = "short name of the Lambda function without project or environment"
}

variable "internal_s3_bucket" {
  description = "Internal S3 Bucket Name"
  default     = ""
}

variable "issuing_ca_info" {
  description = "Issuing CA information"
  default     = {}
}

variable "issuing_crl_days" {
  description = "Number of days before Issuing CA CRL expires, in addition to seconds. Must be greater than or equal to Step Function interval"
  default     = 1
}

variable "issuing_crl_seconds" {
  description = "Number of seconds before Issuing CA CRL expires, in addition to days. Used for overlap in case of clock skew"
  default     = 600
}

variable "lambda_role_arn" {
  description = "Lambda role ARN"
}

variable "logging_account_id" {
  description = "AWS Account ID of central logging account for CloudWatch subscription filters"
  default     = ""
}

variable "max_cert_lifetime" {
  description = "Maximum end entity certificate lifetime in days"
  default     = 365
}

variable "memory_size" {
  description = "Memory allocation for scanning Lambda functions"
  default     = 128
}

variable "prod_envs" {
  description = "List of production environment names. Used to define resource name suffix"
  default     = ["prd", "prod"]
}

variable "project" {
  description = "abbreviation for the project, forms first part of resource names"
  default     = "secure-email"
}

variable "public_crl" {
  description = "Whether to make the CRL and CA certificates publicly available"
  default     = false
}

variable "retention_in_days" {
  description = "CloudWatch log group retention in days"
  default     = 365
}

variable "root_ca_info" {
  description = "Root CA information"
  default     = {}
}

variable "root_crl_days" {
  description = "Number of days before Root CA CRL expires, in addition to seconds. Must be greater than or equal to Step Function interval"
  default     = 1
}

variable "root_crl_seconds" {
  description = "Number of seconds before Root CA CRL expires, in addition to days. Used for overlap in case of clock skew"
  default     = 600
}

variable "runtime" {
  description = "Lambda language runtime"
}

variable "slack_bad_emoji" {
  description = "Emoji to use for Slack bad event notifications"
  default     = ""
}

variable "slack_channels" {
  description = "List of Slack channels to send notifications to"
  default     = []
}

variable "slack_good_emoji" {
  description = "Emoji to use for Slack good event notifications"
  default     = ""
}

variable "slack_secret_arn" {
  description = "ARN of AWS Secrets Manager secret containing Slack OAuth token string"
  default     = ""
}

variable "slack_username" {
  description = "Username to use for Slack notifications"
  default     = ""
}

variable "slack_warning_emoji" {
  description = "Emoji to use for Slack warning notifications"
  default     = ""
}

variable "sns_topic_arn" {
  description = "SNS Topic ARN for Lambda function to publish to"
  default     = ""
}

variable "subscription_filter_destination" {
  description = "CloudWatch log subscription filter destination, last section of ARN"
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "timeout" {
  description = "Amount of time Lambda Function has to run in seconds"
  default     = 180
}

variable "xray_enabled" {
  description = "Whether to enable active tracing with AWS X-Ray"
  default     = true
}
