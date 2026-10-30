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

## Rebuild evidence

The deployed Terraform source is `infra/modules/soar/main.tf`, enabled in
`infra/environments/dev.tfvars`. The Logic App uses fixed
`firstActivityTimeUtc`/`lastActivityTimeUtc`, derives the incident resource ID
from the native incident URL when a separate trigger field is absent, and
queries the Azure Monitor Logs API with managed identity. The duplicate gate
checks both the derived ID and incident number.

Real incident 22 created GLPI ticket 12:

- Sentinel incident: 22 / `285c2ec3-d555-4236-8eb4-c781abeed70e`
- Rule: `SOC - Suspicious API request burst`
- Logic App run: `08584082431393076819313742315CU25` (`Succeeded`)
- GLPI ticket: [ticket 12](https://ticket.platf0rm.site/front/ticket.form.php?id=12)
- Evidence window: `2026-10-30T12:20:17Z` through `2026-10-30T12:30:17Z`
- Evidence action: succeeded with actual event counts, event types, status codes, source addresses, endpoints, request IDs, and simulation IDs.
- Additive follow-up: GLPI follow-up 1 was verified on ticket 12; existing content was preserved.

The final bounded simulations produced real Log Analytics telemetry:

| Scenario | Simulation ID | Events | Observed outcomes | Sentinel after final patch |
|---|---|---:|---|---|
| Authentication failures/lockout | `soc-final-auth-lockout-20261030T123836Z` | 61 | login failure, account lockout, 401/429 | Not created during current suppression window |
| Privilege boundary probing | `soc-final-privilege-probe-20261030T123836Z` | 120 | login success, forbidden, 403/429/401 | Not created during current suppression window |
| Suspicious API | `soc-final-suspicious-api-20261030T124019Z` | 30 | HTTP request, 200 | Not created during current suppression window |
| Authentication rate limiting | `soc-final-auth-rate-limit-20261030T124019Z` | 697 | rate-limit, login failure/lockout, 401/429 | Not created during current suppression window |
| Correlated activity | `soc-final-multi-event-20261030T124019Z` | 240 | success, failure, forbidden, unauthorized, 200/401/403/429 | Not created during current suppression window |

KQL verification against the incident-22 window succeeded for exact match
(331 rows), timeline (3,146 rows), scenario outcome (11 rows), and correlation
(3,376 rows). The wider-context query also executed successfully; its CLI JSON
renderer could not serialize the very large dynamic path set, so it was verified
through tabular output rather than counted as a JSON result.

The five fresh Sentinel incidents are explicitly incomplete for the final-patch
acceptance gate. No incident or GLPI ticket was manually fabricated to hide
that gap; wait for the existing Sentinel suppression interval to expire, then
rerun the same bounded simulations and complete the evidence table.
