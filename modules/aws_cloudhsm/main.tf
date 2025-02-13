locals {
  enabled = module.this.enabled
}

resource "aws_cloudhsm_v2_cluster" "cloudhsm_v2_cluster" {
  count             = local.enabled ? 1 : 0
  hsm_type          = var.hsm_type
  mode              = "FIPS"
  subnet_ids        = var.cluster_subnets
  tags              = module.this.tags
}

data "aws_cloudhsm_v2_cluster" "cloudhsm_v2_cluster" {
  depends_on = [aws_cloudhsm_v2_cluster.cloudhsm_v2_cluster]
  cluster_id = var.create_cluster ? aws_cloudhsm_v2_cluster.cloudhsm_v2_cluster[0].cluster_id : var.cluster_id
}

resource "aws_cloudhsm_v2_hsm" "hsm" {
  depends_on = [data.aws_cloudhsm_v2_cluster.cloudhsm_v2_cluster]
  count      = length(var.hsm_subnets)
  subnet_id  = var.hsm_subnets[count.index]
  cluster_id = data.aws_cloudhsm_v2_cluster.cloudhsm_v2_cluster.cluster_id
}
