# SOC case catalogue

Use [scenario progress](scenario-progress.md) for runtime verification and exact
incident/ticket IDs. Signals are investigation starting points, not findings.

Fresh live activity verified four requested outcomes (brute force, password
spray, multiple failed logins, and synthetic administrator activity). Other
successful cases are supplementary signals: a known-credential success,
rejected duplicate registrations, denied privilege probes, safe suspicious
request activity, and read-only API volume. These do not establish compromise,
unauthorized creation, or successful privilege escalation.

| Case | Actual trigger and source | Investigation focus |
| --- | --- | --- |
| Brute force / failed authentication | Five distinct failed login requests for one hashed account, or a genuine account lock; FastAPI console events | Accounts, UTC timeline, observed source, lockout and access outcome |
| Password spraying | Five distinct failures over at least three hashed accounts in one controlled run | Target distribution and whether related access succeeded |
| Success after failures | Three failures then genuine success for the same hash/run | Establish whether the success was authorized; do not presume compromise |
| Repeated registration rejection | Five rejected duplicate registrations | Distinguish rejected requests from actual customer creation |
| Privilege-boundary probing | Three distinct authorization-denied requests | Identify identity, restricted paths and any privileged successes |
| Administrator directory access | Three authenticated admin reads of the directory | Validate operator intent, permissions, timing and business justification |
| API volume | At least fifty distinct API requests; exclude platform health endpoints | Assess source, traffic purpose, impact and legitimacy |
| Suspicious request pattern | Actual application pattern-monitor event from a safe read-only request | Determine probing versus exploitation using request outcome and related events |
| Authentication rate control | Genuine application rate-limit events | Validate control effectiveness and legitimate-user impact |

Cloud administration is not currently covered: the AzureActivity export is absent.
Telemetry-gap alerts are intentionally disabled for the scale-to-zero commerce app.
Identity/MFA and endpoint/EDR scenarios require the prerequisites recorded in the
twenty-row progress table. Trivy image scanning is a separate CI capability, not an
endpoint malware infection or EDR event.

Sentinel incident-created automation and GLPI case management are deployed.
GLPI stores the investigation record; Sentinel and Log Analytics hold primary
evidence. Never create a test case directly to substitute for the detection chain.
