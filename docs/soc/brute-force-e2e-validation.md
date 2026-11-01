# Brute-force investigation validation

This is the **historical 2026-10-31 record**, not validation of the current
deployment. See [scenario progress](scenario-progress.md) and its linked evidence
for the independently checked 2026-11-01 deployment, corrected suppression and
grouping behaviour, current tests, and fresh incident/ticket results. Historical
RBAC changes below were reported by the prior session, not repeated in this run.

## Result

The bounded lab simulation completed on 2026-10-31. One genuine Sentinel
incident triggered the existing Logic App integration, which automatically
created one GLPI ticket. The ticket is open for analyst investigation.

| Item | Verified value |
| --- | --- |
| k6 scenario ID | `soc-bruteforce-e2e-20261031T222435Z` |
| k6 traffic | 8 login requests, 1 VU, 16.6 seconds; all returned HTTP 401 |
| Authentication telemetry | 5 `AUTH_LOGIN_FAILURE`; 4 `AUTH_ACCOUNT_LOCKED`; 0 successful logins |
| Observed source | `82.9.130.188` (matches test runner egress; not the ACA proxy address) |
| Target account | `cb849a5c2d4dc262` (hashed identifier only) |
| Activity window | 2026-10-31 22:24:49.2395714Z–22:25:04.0620955Z |
| Sentinel incident | `56` (`cb92f08b-a13d-4853-ac72-0e52e7b317db`), Medium |
| Sentinel incident URL | <https://portal.azure.com/#asset/Microsoft_Azure_Security_Insights/Incident/subscriptions/43adc2c2-0fd5-4474-aa8a-9f32f541e4b7/resourceGroups/secure-commerce-dev-rg/providers/Microsoft.OperationalInsights/workspaces/secure-commerce-dev-law/providers/Microsoft.SecurityInsights/Incidents/cb92f08b-a13d-4853-ac72-0e52e7b317db> |
| GLPI ticket | `46`, title “Potential Brute-Force Attack – Commerce Authentication — Sentinel incident 56” |
| GLPI ticket URL | <https://ticket.platf0rm.site/front/ticket.form.php?id=46> |
| Logic App run | `08584081207881562779955613983CU53`, Succeeded |
| Duplicate check | GLPI search by incident title returned exactly one ticket |

The GLPI record was retrieved through the GLPI API and verified to contain the
Log Analytics activity timestamps, count, observed lockout status, absence of
observed successful logins, source IP, hashed account identifier, Sentinel
incident URL, and Log Analytics workspace link. The Logic App evidence query,
duplicate search, and `Create_GLPI_BruteForce_Ticket` action all succeeded; the
create response was HTTP 201. The ticket does not include raw event dumps or
prewritten findings.

## Deployment and State

- Deployed image: `securecommercedev43adc2acr.azurecr.io/secure-commerce-platform:soc-bruteforce-20261031-2219` (digest `sha256:3774342eb138c603fa4044271a8a268a44cc92d505aadaa6c1961a5cd4b90ed7`).
- Targeted Terraform apply updated the existing authentication detection and
  GLPI evidence/ticket Logic App actions: 0 added, 4 changed, 0 destroyed.
- State backup: `tfstate/backups/secure-commerce-dev-before-soc-e2e-20261031.tfstate`
  in storage account `scstate43adc2c20fd5` / container `tfstate`; captured
  before Terraform changes.
- Corrected `resource_suffix` to `43adc2`, matching the deployed ACR and GLPI
  Files storage names. This removed the planned destructive replacements.
- The GitHub Actions deployment identity is
  `secure-commerce-platform-github-actions`. Its subscription-wide Contributor
  and User Access Administrator assignments were removed; Owner is scoped to
  `secure-commerce-dev-rg`, Key Vault Administrator to the lab vault, AcrPush
  to the lab ACR, and Storage Blob Data Contributor to the Terraform state
  storage account. The CLI user’s prior subscription Owner assignment was also
  removed; its lab RG, vault, and state-storage roles remain.
- No imports or state moves were needed: the target Sentinel and Logic App
  resources already existed at their correct Terraform addresses. A full plan
  still reports unrelated in-place drift and three additions, with no
  remaining destroys; those unrelated changes were intentionally not applied.

## Validation

- Backend tests: 18 passed. k6 scenario tests: 2 passed.
- k6 script inspection, Terraform formatting/validation, and `git diff --check`
  passed.
- Log Analytics confirmed the scenario’s real FastAPI events and request IDs.
  The forwarded IP matched the test runner’s independently observed egress IP;
  earlier logs showed the internal `100.100.0.x` proxy addresses, which were
  not used as the test source.
- Sentinel’s one-hour suppression remained enabled. The latest prior incident
  from this rule was more than a day old, so it did not suppress this run.
- No ticket was manually created. GLPI ticket `46` was created by the
  Sentinel-triggered Logic App run.
