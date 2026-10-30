# GLPI runtime verification

This document records checks that can be performed without changing GLPI or
MySQL data. Do not mark the endpoint healthy from DNS alone: a valid result
must include a normal TLS handshake and the GLPI login page.

## Public endpoint checks

```bash
curl --fail --silent --show-error --max-time 20 \
  --proto '=https' --tlsv1.2 \
  -D headers.txt -o glpi.html https://ticket.platf0rm.site/

grep -Eiq 'GLPI|login|authentication' glpi.html
openssl s_client -connect ticket.platf0rm.site:443 \
  -servername ticket.platf0rm.site -verify_return_error </dev/null
```

The DNS chain must point `ticket.platf0rm.site` at the current GLPI Container
App FQDN. A reset connection, a certificate-name error, an Azure error page,
or the setup wizard is a failure.

## Azure checks

Run these with an authenticated Azure CLI and the repository's remote state
configuration. Do not print environment variables, secrets, or Terraform
outputs containing secret values.

```bash
az containerapp show -g secure-commerce-dev-rg -n secure-commerce-dev-glpi \
  --query '{fqdn:properties.configuration.ingress.fqdn,
            ingress:properties.configuration.ingress,
            customDomains:properties.configuration.customDomains}'

az containerapp revision list -g secure-commerce-dev-rg \
  -n secure-commerce-dev-glpi -o table

az containerapp logs show -g secure-commerce-dev-rg \
  -n secure-commerce-dev-glpi --type console --tail 200

az mysql flexible-server show -g secure-commerce-dev-rg \
  -n secure-commerce-dev-mysql \
  --query '{state:state, fqdn:fullyQualifiedDomainName,
            publicAccess:network.publicNetworkAccess,
            backupRetentionDays:backup.backupRetentionDays}'
```

The expected database posture is `Ready`, public access disabled, private DNS
resolution from the Container Apps environment, TLS required, and seven-day
backups. The GLPI container must show successful database installation or
update followed by a serving Apache process; repeated connection, certificate,
or permission errors must be fixed before testing tickets.

## Persistence acceptance

Use a dedicated test account and a harmless text attachment. Record the ticket
ID and attachment filename in the evidence record, then replace the revision
through the normal deployment path. Verify both records after the replacement
and after a planned restart. Never delete existing tickets or reset the GLPI
database as part of this test.

## Current session evidence

On 2026-10-30, public DNS resolved `ticket.platf0rm.site` to the GLPI
Container App CNAME, but the normal TLS connection was reset before receiving
a certificate or HTTP response. The origin hostname supplied in the handover
did not return a direct DNS answer from this environment. Azure CLI could not
be used because no active login was available, so the custom-domain binding,
certificate state, revision health, logs, and MySQL state remain unverified.
