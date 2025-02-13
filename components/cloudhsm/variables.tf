variable "region" {
  type        = string
  description = "AWS Region"
}

variable "cluster_availability_zones" {
  type        = list(string)
  description = <<-EOT
    AWS Availability Zones in which to deploy HSM cluster.
    Ignored if `cluster_availability_zone_ids` is set.
    Can be the full name, e.g. `us-east-1a`, or just the part after the region, e.g. `a` to allow reusable values across regions.
    If not provided, HSM cluster will be provisioned in every zone with a private subnet in the VPC.
    EOT
  default     = []
  nullable    = false
}

variable "hsm_availability_zones" {
  type        = list(string)
  description = <<-EOT
    AWS Availability Zones in which to deploy HSMs.
    Ignored if `hsm_availability_zone_ids` is set.
    Can be the full name, e.g. `us-east-1a`, or just the part after the region, e.g. `a` to allow reusable values across regions.
    If not provided, HSMs will be provisioned in every zone with a private subnet in the VPC.
    EOT
  default     = []
  nullable    = false
}

variable "cluster_availability_zone_ids" {
  type        = list(string)
  description = <<-EOT
    List of Availability Zones IDs where subnets will be created. Overrides `cluster_availability_zones`.
    Can be the full name, e.g. `use1-az1`, or just the part after the AZ ID region code, e.g. `-az1`,
    to allow reusable values across regions. Consider contention for resources and spot pricing in each AZ when selecting.
    Useful in some regions when using only some AZs and you want to use the same ones across multiple accounts.
    EOT
  default     = []
}

variable "hsm_availability_zone_ids" {
  type        = list(string)
  description = <<-EOT
    List of Availability Zones IDs where subnets will be created. Overrides `hsm_availability_zones`.
    Can be the full name, e.g. `use1-az1`, or just the part after the AZ ID region code, e.g. `-az1`,
    to allow reusable values across regions. Consider contention for resources and spot pricing in each AZ when selecting.
    Useful in some regions when using only some AZs and you want to use the same ones across multiple accounts.
    EOT
  default     = []
}

variable "availability_zone_abbreviation_type" {
  type        = string
  description = "Type of Availability Zone abbreviation (either `fixed` or `short`) to use in names. See https://github.com/cloudposse/terraform-aws-utils for details."
  default     = "fixed"
  nullable    = false

  validation {
    condition     = contains(["fixed", "short"], var.availability_zone_abbreviation_type)
    error_message = "The availability_zone_abbreviation_type must be either \"fixed\" or \"short\"."
  }
}

variable "vpc_component_name" {
  type        = string
  description = "The name of the vpc component"
  default     = "vpc"
  nullable    = false
}

variable "create_cluster" {
  type        = bool
  description = "Create a new cluster or use existing"
  default     = true
}

variable "cluster_id" {
  type        = string
  description = "Optional parameter to provide ID of the existing cluster if create_cluster is false"
  default     = ""
}
