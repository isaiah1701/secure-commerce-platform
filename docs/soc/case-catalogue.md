# SOC case catalogue

This catalogue maps the lab's intended investigations to the evidence currently available. A case is only marked **available** when the required telemetry and action endpoint exist.

| Case | Trigger | Evidence | Status | Response |
|---|---|---|---|---|
| Brute-force authentication | Repeated 401/422/429 login responses | `ContainerAppConsoleLogs_CL` and Sentinel auth rule | Available | Identify source, preserve window, block only an approved test source |
| Password spray | One source tests several accounts | KQL hunting pack query 2 | Available | Confirm synthetic accounts, rotate affected credentials |
| Suspicious successful login | Success after repeated failures | Sentinel suspicious-success rule | Available | Review session and revoke token if confirmed |
| API abuse | High request count or path enumeration | Sentinel API burst rule and KQL query 4 | Available | Reduce rate, inspect client and route distribution |
| Privilege probing | Repeated 403 or admin path attempts | Sentinel privilege rule | Available | Review authorization logs and preserve request IDs |
| Cloud administrative change | Successful Azure write/delete/action | AzureActivity Sentinel rule | Available | Verify change owner and revert only with approval |
| Telemetry gap | No recent container console events | Sentinel telemetry-gap rule | Available | Check app revision, diagnostics, and ingestion |
| GLPI ticket creation | Sentinel alert creates an incident ticket | GLPI API | Blocked | Requires durable GLPI deployment and API credentials |
| Endpoint malware alert | Endpoint/EDR signal | Defender for Endpoint or equivalent | Blocked | Requires separate product licensing and onboarding |
| Vulnerable image remediation | Trivy high/critical finding | GitHub SARIF from deploy workflow | Available | Patch base image/dependency and redeploy |

## Investigation record

For each case, record the UTC time window, query text, alert ID, affected source/resource, decision, and closure evidence. Keep synthetic test traffic separate from production data and include `X-SOC-Scenario-ID` when generating it.
