environment = "dev"
location    = "UK South"

# Set a short lowercase suffix if a globally unique ACR or Key Vault name is required.
resource_suffix = ""

enable_glpi            = true
glpi_database_location = "East US"

# GoDaddy remains the registrar; Azure DNS becomes authoritative after the
# first apply returns the four Azure nameservers.
domain_name                  = "platf0rm.site"
app_subdomain                = "shop"
enable_custom_domain_binding = false

postgres_admin_username = "commerceadmin"
postgres_sku_name       = "B_Standard_B1ms"

container_min_replicas = 0
container_max_replicas = 2

# Terraform uses this only to bootstrap the Container App. deploy.yml replaces it
# with an immutable ACR image tag and Terraform intentionally ignores that field.
container_image     = "mcr.microsoft.com/azuredocs/containerapps-helloworld"
container_image_tag = "latest"

tags = {
  CostCentre = "Learning"
  Owner      = "Isaiah"
}
