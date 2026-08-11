locals {
  runtime = "python3.14"

  create_root_ca_function_name    = "create-root-ca"
  create_issuing_ca_function_name = "create-issuing-ca"
  root_ca_crl_function_name       = "root-ca-crl"
  issuing_ca_crl_function_name    = "issuing-ca-crl"
  tls_cert_function_name          = "tls-cert"
  expiry_function_name            = "expiry"
  notify_function_name            = "notify"

  ca_bundle_s3_key            = contains(var.prod_envs, var.env) ? "${var.project}-ca-bundle.pem" : "${var.project}-ca-bundle-${var.env}.pem"
  root_ca_cert_s3_key         = contains(var.prod_envs, var.env) ? "${var.project}-root-ca.crt" : "${var.project}-root-ca-${var.env}.crt"
  issuing_ca_cert_s3_key      = contains(var.prod_envs, var.env) ? "${var.project}-issuing-ca.crt" : "${var.project}-issuing-ca-${var.env}.crt"
  root_ca_crl_s3_key          = contains(var.prod_envs, var.env) ? "${var.project}-root-ca.crl" : "${var.project}-root-ca-${var.env}.crl"
  issuing_ca_crl_s3_key       = contains(var.prod_envs, var.env) ? "${var.project}-issuing-ca.crl" : "${var.project}-issuing-ca-${var.env}.crl"
  ca_bundle_s3_location       = "${module.external_s3.s3_bucket_domain_name}/${local.ca_bundle_s3_key}"
  root_ca_cert_s3_location    = "${module.external_s3.s3_bucket_domain_name}/${local.root_ca_cert_s3_key}"
  issuing_ca_cert_s3_location = "${module.external_s3.s3_bucket_domain_name}/${local.issuing_ca_cert_s3_key}"
  root_ca_crl_s3_location     = "${module.external_s3.s3_bucket_domain_name}/${local.root_ca_crl_s3_key}"
  issuing_ca_crl_s3_location  = "${module.external_s3.s3_bucket_domain_name}/${local.issuing_ca_crl_s3_key}"
}
