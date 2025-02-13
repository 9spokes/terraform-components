locals {
  enabled     = module.this.enabled
  vpc_outputs = module.vpc.outputs

  short_region = module.utils.region_az_alt_code_maps["to_short"][var.region]

  vpc_id = local.vpc_outputs.vpc_id

  #cluster_availability_zones_expanded = local.enabled && length(var.cluster_availability_zones) > 0 && length(var.cluster_availability_zone_ids) == 0 ? (
  #  (substr(
  #    var.cluster_availability_zones[0],
  #    0,
  #    length(var.region)
  #  ) == var.region) ? var.cluster_availability_zones : formatlist("${var.region}%s", var.cluster_availability_zones)
  #) : []

  #cluster_availability_zone_ids_expanded = local.enabled && length(var.cluster_availability_zone_ids) > 0 ? (
  #  (substr(
  #    var.cluster_availability_zone_ids[0],
  #    0,
  #    length(local.short_region)
  #  ) == local.short_region) ? var.cluster_availability_zone_ids : formatlist("${local.short_region}%s", var.cluster_availability_zone_ids)
  #) : []

  # Create a map of AZ IDs to AZ names (and the reverse),
  # but fail safely, because AZ IDs are not always available.
  #cluster_az_id_map = length(local.cluster_availability_zone_ids_expanded) > 0 ? try(zipmap(data.aws_availability_zones.default[0].zone_ids, data.aws_availability_zones.default[0].names), {}) : {}

  #cluster_availability_zones_normalized = length(local.cluster_availability_zone_ids_expanded) > 0 ? [
  #  for v in local.cluster_availability_zone_ids_expanded : local.cluster_az_id_map[v]
  #] : local.cluster_availability_zones_expanded

  # Get only the private subnets that correspond to the AZs provided in `var.cluster_availability_zones`
  # `az_private_subnets_map` is a map of AZ names to list of private subnet IDs in the AZs
  # LEGACY SUPPORT for legacy VPC with no az_public_subnets_map
  cluster_private_subnet_ids = try(flatten([
    for k, v in local.vpc_outputs.az_private_subnets_map : v
    if contains(var.cluster_availability_zones, k) || length(var.cluster_availability_zones) == 0
    ]),
  local.vpc_outputs.private_subnet_ids)

  # Infer the availability zones from the private subnets if var.availability_zones is empty:
  # availability_zones = local.enabled ? (length(local.cluster_availability_zones_normalized) == 0 ? keys(local.vpc_outputs.az_private_subnets_map) : local.cluster_availability_zones_normalized) : []

  hsm_availability_zones_expanded = local.enabled && length(var.hsm_availability_zones) > 0 && length(var.hsm_availability_zone_ids) == 0 ? (
    (substr(
      var.hsm_availability_zones[0],
      0,
      length(var.region)
    ) == var.region) ? var.hsm_availability_zones : formatlist("${var.region}%s", var.hsm_availability_zones)
  ) : []

  hsm_availability_zone_ids_expanded = local.enabled && length(var.hsm_availability_zone_ids) > 0 ? (
    (substr(
      var.hsm_availability_zone_ids[0],
      0,
      length(local.short_region)
    ) == local.short_region) ? var.hsm_availability_zone_ids : formatlist("${local.short_region}%s", var.hsm_availability_zone_ids)
  ) : []

  # Create a map of AZ IDs to AZ names (and the reverse),
  # but fail safely, because AZ IDs are not always available.
  # hsm_az_id_map = length(local.hsm_availability_zone_ids_expanded) > 0 ? try(zipmap(data.aws_availability_zones.default[0].zone_ids, data.aws_availability_zones.default[0].names), {}) : {}

  #hsm_availability_zones_normalized = length(local.hsm_availability_zone_ids_expanded) > 0 ? [
  #  for v in local.hsm_availability_zone_ids_expanded : local.hsm_az_id_map[v]
  #] : local.hsm_availability_zones_expanded

  # Get only the private subnets that correspond to the AZs provided in `var.hsm_availability_zones`
  # `az_private_subnets_map` is a map of AZ names to list of private subnet IDs in the AZs
  # LEGACY SUPPORT for legacy VPC with no az_public_subnets_map
  hsm_private_subnet_ids = try(flatten([
    for k, v in local.vpc_outputs.az_private_subnets_map : v
    if contains(var.hsm_availability_zones, k) || length(var.hsm_availability_zones) == 0
    ]),
  local.vpc_outputs.private_subnet_ids)
}

#data "aws_availability_zones" "default" {
#  count = length(local.cluster_availability_zone_ids_expanded) > 0 ? 1 : 0
#
#  # Filter out Local Zones. See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones#by-filter
#  filter {
#    name   = "opt-in-status"
#    values = ["opt-in-not-required"]
#  }
#
#  lifecycle {
#    postcondition {
#      condition     = length(self.zone_ids) > 0
#      error_message = "No availability zones IDs found in region ${var.region}. You must specify availability zones instead."
#    }
#  }
#}

module "utils" {
  source  = "cloudposse/utils/aws"
  version = "1.3.0"
}

module "aws_cloudshm" {
  source = "github.com/9spokes/terraform-components.git//modules/aws_cloudhsm"
  count = local.enabled ? 1 : 0

  create_cluster  = var.create_cluster
  cluster_id      = var.cluster_id
  vpc_id          = local.vpc_id
  cluster_subnets = local.cluster_private_subnet_ids
  hsm_subnets     = local.hsm_private_subnet_ids
}
