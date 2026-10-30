# GLPI database

Azure MySQL Flexible Server is now available in UK South after the subscription upgrade. Terraform provisions a private `Standard_B1ms` server with a delegated subnet, private DNS, TLS enforcement, seven-day backups, and a `glpi` database. No VM or ephemeral database storage is used.

Required secret:

1. Confirm the GitHub Actions `GLPI_DATABASE_PASSWORD` environment secret is set and at least 16 characters.
2. Terraform creates the server and GLPI Container App when `enable_glpi=true`.
3. Complete the ticket, attachment, revision-replacement, and recovery persistence tests before enabling Sentinel-to-GLPI automation.

The server is a small Burstable Pay-As-You-Go resource intended for this training lab. It has recurring cost and no high-availability replica.
