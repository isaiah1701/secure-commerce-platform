# SOC incident lab evidence report

Date: 2026-10-30  
Environment: `secure-commerce-dev-rg` / `secure-commerce-dev-law`  
Application: `https://shop.platf0rm.site`  
Analyst: Muhammad Shah

## Validated vertical slice

Scenario: `soc-auth-rate-clean-20261030T102036Z`  
Profile: one VU, one iteration per second, five seconds, 60 bounded login
requests inside the scenario iterations.  
Registration: one owned lab account on `platf0rm.site`; no real user account
was targeted.

Log Analytics query result:

- Table: `ContainerAppConsoleLogs_CL`
- Correlated events: 123
- `RATE_LIMIT_EXCEEDED`: 49
- HTTP 429 records: 49
- Source IPs observed: `100.100.0.107`, `100.100.0.5`
- Evidence included `simulation_id`, timestamps, request IDs, route, status,
  and user agent.

Sentinel result:

- Rule: `secure-commerce-dev-auth_rate_limit`
- Incident number: 15
- Incident ID: `9e2ab71b-0b90-4ee6-ab8a-4cabfa69d2ea`
- Title: `SOC - Authentication rate limit triggered`
- Severity: Medium
- Status: New
- Incident URL: [Open incident in Azure](https://portal.azure.com/#asset/Microsoft_Azure_Security_Insights/Incident/subscriptions/43adc2c2-0fd5-4474-aa8a-9f32f541e4b7/resourceGroups/secure-commerce-dev-rg/providers/Microsoft.OperationalInsights/workspaces/secure-commerce-dev-law/providers/Microsoft.SecurityInsights/Incidents/9e2ab71b-0b90-4ee6-ab8a-4cabfa69d2ea)

## Pending integration evidence

The GLPI API currently returns `API disabled`. The Terraform playbook is
committed, but no GLPI ticket is claimed until the API is enabled, a dedicated
integration user is created, and the Logic App is deployed and exercised.
No manual or synthetic GLPI ticket has been created as a substitute.

Required next evidence:

1. Logic App workflow run ID for incident 15.
2. GLPI API response and ticket ID/URL.
3. Duplicate-event replay showing no second ticket.
4. Muhammad-facing ticket content review.
