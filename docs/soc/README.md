# SOC lab status

The Log Analytics workspace is `secure-commerce-dev-law` and Sentinel onboarding is managed by Terraform. Scheduled rules are defined in `infra/modules/soc` and query `ContainerAppConsoleLogs_CL`.

Use [`soc/kql/hunting-pack.kql`](../../soc/kql/hunting-pack.kql) for analyst queries, [`runbook.md`](runbook.md) for triage and evidence handling, [`case-catalogue.md`](case-catalogue.md) for coverage, and [`architecture.md`](architecture.md) for the current data flow. The bounded traffic generator is documented in [`k6.md`](k6.md).

GLPI is intentionally disabled until a durable managed MySQL-compatible provider is connected. Azure MySQL Flexible Server SKU discovery returned no provisionable SKUs in the tested regions, and no Azure VM fallback is used. No paid external service has been purchased.
