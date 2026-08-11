variable "project" {}

variable "description" {
  description = "description of KSM key overrides default"
  default     = ""
}

variable "enable_key_rotation" {
  description = "enable key rotation"
  default     = false # must be false for asymmetric keys, and symmetric keys used for S3 encryption with long-lived content
}

variable "deletion_window_in_days" {
  description = "Waiting period before scheduled KMS key deletion"
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "KMS deletion window must be between 7 and 30 days."
  }
}

variable "env" {
  description = "Environment name, e.g. dev"
}

variable "prod_envs" {
  description = "List of production environment names. Used to define resource name suffix"
  default     = ["prd", "prod"]
}

variable "kms_policy" {
  description = "KMS policy to use"
  default     = "default"
}

variable "customer_master_key_spec" {
  description = "symmetric default or asymmetric algorithm"
  default     = "SYMMETRIC_DEFAULT"

  validation {
    condition = contains([
      "SYMMETRIC_DEFAULT",
      "RSA_2048",
      "RSA_3072",
      "RSA_4096",
      "HMAC_256",
      "ECC_NIST_P256",
      "ECC_NIST_P384",
      "ECC_NIST_P521",
      "ECC_SECG_P256K1",
    ], var.customer_master_key_spec)
    error_message = "Invalid customer_master_key_spec"
  }
}

variable "key_usage" {
  description = "intended use of the key"
  default     = "ENCRYPT_DECRYPT"

  validation {
    condition = contains([
      "ENCRYPT_DECRYPT",
      "SIGN_VERIFY",
      "GENERATE_VERIFY_MAC",
    ], var.key_usage)
    error_message = "Invalid key_usage"
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
