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

## Live Sentinel-to-GLPI evidence

The authenticated GLPI API is enabled with a restricted dedicated integration
identity. Its password and application token were rotated after deployment and
stored in Key Vault; no secret values are recorded here.

| Scenario | Simulation ID | Sentinel incident | Logic App run | GLPI ticket | Result |
|---|---|---|---|---|---|
| Native trigger diagnostic using real incident metadata | `soc-auth-rate-soar-20261030T1128Z` evidence window; incident 17 replay | 17 / `80428182-639a-4669-9a86-d8614f04908b` | `08584082471491068316023616235CU60` | Ticket 1: [GLPI ticket 1](https://ticket.platf0rm.site/front/ticket.form.php?id=1) | PASS |

The Logic App native Sentinel trigger returned HTTP 202 and the run completed
with `Succeeded` from `2026-10-30T11:28:56Z` to `11:28:59Z`. A replay of the
same incident also completed successfully and the GLPI search still returned
`totalcount=1`, proving duplicate suppression.

The bounded rate-limit scenario `soc-auth-rate-soar-20261030T1128Z` produced
409 correlated events in `ContainerAppConsoleLogs_CL` (including
`RATE_LIMIT_EXCEEDED`, `AUTH_LOGIN_FAILURE`, `AUTH_ACCOUNT_LOCKED`, and
`HTTP_REQUEST`, with statuses 401 and 429) from `11:23:37Z` through
`11:24:10Z`. The scheduled Sentinel incident for that fresh event was not
observed during this validation window; the native trigger diagnostic therefore
uses the real incident-17 metadata and is clearly labeled as such.
