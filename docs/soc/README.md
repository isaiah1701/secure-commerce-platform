# SOC lab status

The Log Analytics workspace is `secure-commerce-dev-law` and Sentinel onboarding is managed by Terraform. Scheduled rules are defined in `infra/modules/soc` and query `ContainerAppConsoleLogs_CL`.

GLPI is intentionally disabled until a durable managed MySQL-compatible provider is connected. Azure MySQL Flexible Server SKU discovery returned no provisionable SKUs in the tested regions, and no Azure VM fallback is used. No paid external service has been purchased.
