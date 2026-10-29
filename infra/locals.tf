locals {
  project     = var.project_name
  environment = var.environment
  prefix      = "${local.project}-${local.environment}"

  compact_name = replace("${local.project}${local.environment}${var.resource_suffix}", "-", "")
  acr_name     = substr("${local.compact_name}acr", 0, 50)
  key_vault_name = substr(
    join("-", compact([local.prefix, var.resource_suffix, "kv"])),
    0,
    24
  )

  tags = merge(
    {
      Environment = local.environment
      Project     = local.project
      ManagedBy   = "Terraform"
      Workload    = "secure-commerce"
    },
    var.tags
  )
}
