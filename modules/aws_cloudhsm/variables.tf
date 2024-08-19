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

variable "hsm_type" {
  type        = string
  description = "HSM type. Default is hsm2m.medium"
  default     = "hsm2m.medium"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "cluster_subnets" {
  type        = list(string)
  description = "List of VPC subnet IDs for cluster"
}

variable "hsm_subnets" {
  type        = list(string)
  description = "List of VPC subnet IDs for HSMs"
}

variable "instance_availability_zone" {
  type        = string
  default     = ""
  description = "Optional parameter to place cluster instances in a specific availability zone. If left empty, will place randomly"
}
