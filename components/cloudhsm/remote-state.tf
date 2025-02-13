module "vpc" {
  source  = "cloudposse/stack-config/yaml//modules/remote-state"
  version = "1.5.0"

  bypass    = !local.enabled
  component = var.vpc_component_name

  defaults = {
    public_subnet_ids  = []
    private_subnet_ids = []
    vpc = {
      subnet_type_tag_key = ""
    }
    vpc_cidr = null
    vpc_id   = null
  }

  context = module.this.context
}
