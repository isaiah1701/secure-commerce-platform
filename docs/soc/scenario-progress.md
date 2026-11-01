# SOC scenario progress

Live audit completed 2026-11-01 03:26 UTC. A scenario is **VERIFIED** only when
the bounded activity, real application telemetry, Sentinel incident, successful
Logic App execution, and exactly one correlated GLPI case are all confirmed.

## Completion summary

- **4 of 20 requested scenarios verified end to end (20%).** These are brute
  force, password spray, multiple failed logins, and suspicious administrator
  activity.
- **16 of 20 blocked by missing capabilities or intentionally unproven impact.**
  They are not represented as implemented detections or verified attacks.
- Seven fresh Sentinel incidents (66–72) map one-to-one to seven fresh tickets;
  suspicious-request incident 73 is an additional verified signal. All eight
  tickets have a successful Logic App run, evidence returned by Log Analytics,
  working Sentinel/workspace links, and exactly one GLPI record.
- Every one of the eight genuine incidents was replayed through its Sentinel
  trigger history. All replay runs succeeded, ticket-creation actions were
  skipped, ticket content and analyst follow-ups stayed unchanged, and the
  incident-to-ticket mapping stayed stable. See
  [final replay evidence](evidence/dedup-after-source-enrichment.json) and the
  [initial replay evidence](evidence/dedup-all-incidents.json).
- After initial automatic creation, one observed-source line was added to each
  existing open case using the GLPI API. Only ticket description content was
  changed; titles, IDs, status, and analyst follow-ups were preserved. The source
  came from correlated Log Analytics telemetry, not an inferred location or
  proxy header. See [source enrichment](evidence/ticket-source-enrichment.json).
- The final Logic App query rejects private, loopback, link-local, and carrier-
  grade NAT IPv4 ranges before including a source. A live replay of incident 68
  returned `82.9.130.188` from eight correlated events, skipped ticket creation,
  and preserved ticket 58; see
  [source-filter verification](evidence/source-filter-live-verification.json).
- No analyst follow-ups existed on the eight new cases before replay; their
  count and content remained unchanged. Existing historical cases were not
  edited, deleted, or closed.

## Requested scenario status

| # | Scenario | Safe activity and actual capability | Status | Evidence or limitation |
| --- | --- | --- | --- | --- |
| 1 | Brute force | Eight invalid login attempts against one synthetic user; FastAPI failure and lockout events | **VERIFIED** | Incident 66, ticket 57; see fresh reconciliation below |
| 2 | Password spraying | Five invalid attempts across five synthetic accounts | **VERIFIED** | Incident 67, ticket 56 |
| 3 | Account compromise | Three failures followed by a real login using the synthetic account's known valid credential | **BLOCKED** | Supplemental suspicious-success signal verified as incident 69/ticket 59; this does not establish compromise or an unauthorized session |
| 4 | Suspicious login locations | No trusted identity sign-in location source; HTTP geolocation is not used | **BLOCKED** | Requires an identity provider sign-in feed and trusted location context |
| 5 | Impossible travel | No identity-correlated trusted location history | **BLOCKED** | Requires timestamped identity sign-ins and suitable licensed telemetry |
| 6 | MFA fatigue | Commerce application has no MFA challenge or approval telemetry | **BLOCKED** | Requires a real MFA provider, test identity, and challenge outcomes |
| 7 | Multiple failed login attempts | Same genuine bounded attack as scenario 1; shared detection, no duplicate rule | **VERIFIED** | Same incident 66/ticket 57; not counted as a second incident |
| 8 | Unauthorized account creation | Five duplicate registrations were rejected by the application | **BLOCKED** | Rejection signal verified as incident 70/ticket 60; no unauthorized account was created or claimed |
| 9 | Privilege escalation | A customer received three expected 403 responses from read-only protected endpoints | **BLOCKED** | Denied-probe signal verified as incident 72/ticket 62; no successful escalation occurred |
| 10 | Suspicious administrator activity | Synthetic administrator login and three read-only directory views | **VERIFIED** | Incident 68, ticket 58; intent remains for the analyst to determine |
| 11 | Ransomware | No endpoint file or process telemetry | **BLOCKED** | Requires an approved disposable endpoint and safe detection source |
| 12 | Trojan infection | No endpoint prevention/detection source | **BLOCKED** | Requires an onboarded licensed EDR or equivalent; no malware deployed |
| 13 | Spyware detection | No endpoint behavioral source | **BLOCKED** | Requires safe endpoint detection telemetry; no surveillance/credential theft |
| 14 | Malware download | No endpoint AV or download-scanning events | **BLOCKED** | Requires a scanner/AV event from an approved endpoint; HTTP alone is insufficient |
| 15 | Suspicious PowerShell | No Windows host or process logging | **BLOCKED** | Requires an approved host and script-block/4688/Sysmon ingestion |
| 16 | Malicious scripts | No endpoint script-execution monitoring | **BLOCKED** | Requires an approved endpoint and monitored harmless test scripts |
| 17 | Unauthorized software installation | No installation or software-inventory events | **BLOCKED** | Requires endpoint installation audit and an authorization baseline |
| 18 | Suspicious processes | Container console logs are not host process auditing | **BLOCKED** | Requires process-creation telemetry such as Sysmon/4688 or equivalent |
| 19 | EDR alerts | No EDR connector, license, or onboarded endpoint | **BLOCKED** | Requires a genuine product alert; none was manufactured |
| 20 | Cryptomining malware | No endpoint behavioral/resource detection | **BLOCKED** | Requires a safe monitored endpoint; no miner or resource exhaustion used |

## Fresh incident-to-ticket reconciliation

These are real Sentinel incident and GLPI identifiers. The observed source was
the runner's actual public egress `82.9.130.188`; no source or country was
spoofed. Account identifiers remain hashed in application telemetry. Event
windows below come from the actual Log Analytics rows. The linked case is the
automatically created GLPI ticket, not a manually submitted one.

| Scenario / simulation | Sentinel incident | Rule / severity | Observed UTC window | Logic App run | GLPI case | Result |
| --- | --- | --- | --- | --- | --- | --- |
| Brute force / `soc-auth-lockout-20261101T023544Z` | 66 / `057517db-1a7d-480f-9c4a-44daae6b2712` | `auth_attack` / Medium | 02:35:48.767–02:36:03.161 | `08584081055651905884616995791CU53` / Succeeded | [57](https://ticket.platf0rm.site/front/ticket.form.php?id=57) | **PASS**; 5 failure and 4 lockout events |
| Password spray / `soc-password-spray-20261101T023648Z` | 67 / `caae16a0-bed7-498a-adbd-5d21578adedc` | `auth_spray` / Medium | 02:36:56.590–02:37:04.857 | `08584081055656334936669435900CU28` / Succeeded | [56](https://ticket.platf0rm.site/front/ticket.form.php?id=56) | **PASS**; 5 invalid attempts across 5 hashed accounts |
| Admin activity / `soc-admin-directory-20261101T023627Z` | 68 / `ae0afadb-9a0d-426c-b8b2-23359fbdfbc6` | `admin_activity` / Low | 02:36:31.346–02:36:34.501 | `08584081055647622134059699356CU21` / Succeeded | [58](https://ticket.platf0rm.site/front/ticket.form.php?id=58) | **PASS**; administrator directory views |
| Successful auth after failures / `soc-auth-success-after-failures-20261101T023721Z` | 69 / `5091222c-75b3-4050-a03d-bac25fff4f6c` | `suspicious_success` / Medium | 02:37:24.704–02:37:27.919 | `08584081055643203262706563904CU58` / Succeeded | [59](https://ticket.platf0rm.site/front/ticket.form.php?id=59) | **PASS signal only**; valid synthetic login is not proof of compromise |
| Rejected registration burst / `soc-registration-abuse-20261101T023820Z` | 70 / `e978070c-2a61-459f-b48b-3dc5ce02a8ba` | `account_registration_burst` / Low | 02:38:23.701–02:38:27.849 | `08584081055639028414895457445CU20` / Succeeded | [60](https://ticket.platf0rm.site/front/ticket.form.php?id=60) | **PASS signal only**; duplicate registrations were rejected |
| Read-only API burst / `soc-api-read-burst-20261101T023909Z` | 71 / `34ebaea6-b5ef-4b3b-9563-5c5d60b05b86` | `api_abuse` / Low | 02:39:11.081–02:40:12.025 | `08584081055634593888439492296CU29` / Succeeded | [61](https://ticket.platf0rm.site/front/ticket.form.php?id=61) | **PASS supplemental**; 60 correlated read requests |
| Denied privilege probe / `soc-privilege-probe-20261101T023806Z` | 72 / `621cf6b3-4ad2-42a5-8649-ab15abda4069` | `privilege_probe` / Medium | 02:38:09.809–02:38:12.915 | `08584081055630515238615509982CU61` / Succeeded | [62](https://ticket.platf0rm.site/front/ticket.form.php?id=62) | **PASS signal only**; three protected requests were denied |

Additional safe signal: one suspicious request generated incident 73
(`9cf069e4-7826-45d8-a24f-0c863fb97460`), successful Logic App run
`08584081054433390365380796450CU22`, and ticket
[63](https://ticket.platf0rm.site/front/ticket.form.php?id=63). One genuine
`SUSPICIOUS_REQUEST` event was observed at 02:42:03.517 UTC.

Each case's structured evidence, matched alert/rule IDs, telemetry rows, ticket
hash, and automatic-creation result are in the correspondingly named
`evidence/soc-*.json` file. The eight duplicate-prevention replay runs and
before/after hashes are in `evidence/dedup-all-incidents.json`.

## Ticket quality and investigation

Live GLPI API reads confirmed short human-readable incident titles, a clear
summary, actual severity and UTC timing, the affected Commerce API/app, the
actual observed source, a scenario correlation ID, clickable Sentinel and
tenant-aware Log Analytics workspace links, an investigation objective, four
concise investigation steps, and a definition of done. These fields were
verified on all eight cases; see
[ticket-quality-final.json](evidence/ticket-quality-final.json). Tickets do not
contain raw logs, answer the case, or classify the event for the analyst. When
the source is unavailable or ambiguous, the workflow reports `unknown` or
`multiple (review Log Analytics)`. The workspace link targets the
`secure-commerce-dev-law` overview. See [runbook.md](runbook.md) for beginner
triage, classification, escalation, remediation, and closure.

## Telemetry and deployment limits

- The application security table is `ContainerAppConsoleLogs_CL`; real failed,
  locked, successful, registration, authorization, admin, and suspicious-request
  events were queried for each simulation.
- All eleven scheduled Sentinel queries executed successfully through Log
  Analytics (HTTP 200); seven active detections matched live activity in this
  evidence set. Cloud-change monitoring stays disabled
  until an approved `AzureActivity` export exists.
- [Telemetry inventory](evidence/telemetry-inventory.json) records no VM,
  identity license SKU, Entra sign-in table, security event table, Sysmon data,
  or EDR feed in this lab. Graph sign-in access returned the tenant's
  `Authentication_RequestFromNonPremiumTenantOrB2CTenant` limitation.
- No paid endpoint or identity resources were added. The unsupported scenarios
  require the real prerequisite sources listed above; they must not be faked.

## State, deduplication, and earlier findings

- The refreshed full Terraform plan is clean with zero changes or destroys. A
  current state snapshot is backed up in remote storage as
  `backups/secure-commerce-dev-final-20261101T0326.tfstate`.
- The deployment identity's lab resource-group Owner and state-storage Blob Data
  Contributor roles were read-only audited; no new role grants were made. The
  Terraform-created Logic App role assignments remain scoped to the workspace
  and vault. See [access/state evidence](evidence/access-and-state.json).
- GLPI's genuine zero-result search omits `data`. The deployed workflow now
  accepts only a valid zero-count empty search, rejects malformed/error results,
  and filters safely. Sentinel trigger execution is serialized; one ticket is
  keyed by immutable incident ID and legacy number.
- Two earlier incident-64 replays also skipped both creation actions and
  preserved ticket 54 and its follow-ups; see
  [historical replay evidence](evidence/dedup-replay.json).
- Historical incidents 64 and 65 generated two tickets for an overlapping
  registration run; both are preserved and not counted as fresh verification.
  Incident 62/ticket 51 was health-check noise. Updated API-volume detection
  excludes health/readiness/metrics. These limitations are detailed in
  [brute-force validation history](brute-force-e2e-validation.md).

## Reproduce

The guarded runner provisions disposable synthetic identities and refuses
unapproved targets. Example from the repository root:

```sh
PYTHONPATH="$PWD" uv run --no-sync --directory backend python "$PWD/soc/validate.py" run auth-lockout
PYTHONPATH="$PWD" uv run --no-sync --directory backend python "$PWD/soc/validate.py" run password-spray
PYTHONPATH="$PWD" uv run --no-sync --directory backend python "$PWD/soc/validate.py" verify soc-auth-lockout-<UTC-run-id> --wait 900
```

Use only the owned lab and a current dedicated synthetic account. See
[`k6.md`](k6.md) for scenario details and [`case-catalogue.md`](case-catalogue.md)
for detection coverage.
