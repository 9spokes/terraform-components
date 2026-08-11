mock_provider "aws" {}

variables {
  enabled     = false
  region      = "ap-southeast-2"
  namespace   = "example"
  environment = "apse2"
  stage       = "test"
  name        = "serverless-ca"

  root_certificate_profile = {
    commonName   = "Example Root CA"
    organization = "Example"
  }

  issuing_certificate_profile = {
    commonName   = "Example Issuing CA"
    organization = "Example"
  }

  lambda_artifacts = {
    for name in ["create_root_ca", "create_issuing_ca", "root_ca_crl", "issuing_ca_crl", "tls_cert", "expiry", "notify"] : name => {
      bucket     = "immutable-artifacts"
      key        = "serverless-ca/${name}.zip"
      version_id = "version-${name}"
      sha256     = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    }
  }
}

run "disabled_component_creates_nothing" {
  command = plan

  assert {
    condition     = length(module.ca) == 0
    error_message = "Disabled component must not instantiate the CA module."
  }

  assert {
    condition     = output.deployment_contract == null
    error_message = "Disabled component must not expose a deployment contract."
  }
}
