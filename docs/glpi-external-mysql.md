# GLPI database handoff

Azure Database for MySQL Flexible Server returned no provisionable SKUs for the tested UK South, North Europe, East US, and West Europe checks. The VM fallback has been removed.

Recommended free-trial-compatible provider: **Aiven for MySQL Free**. Aiven documents a $0/month plan with one CPU, 1 GB RAM, 1 GB storage, automated backups, and TLS. It does not require a credit card, has no time limit, and cannot be placed in a VPC or given a static IP. That means GLPI must use TLS and the provider's public endpoint; this is acceptable for this two-person training lab only if the provider's access controls and TLS certificate verification are enabled.

Required manual action:

1. Create an Aiven account and a MySQL Free service.
2. Create a database named `glpi` and an application user with a unique password.
3. Copy the TLS connection hostname, port, username, password, and CA certificate details.
4. Add these as GitHub Actions environment secrets/variables, then set `enable_glpi=true` and `glpi_database_host` in `infra/environments/dev.tfvars`.
5. Rerun Terraform and complete the GLPI acceptance tests.

No service was purchased or created by this repository. The free tier is limited to 1 GB, so it is suitable for a small training queue rather than production.
