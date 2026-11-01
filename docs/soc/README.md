# SOC lab handover

The lab sends bounded, scenario-tagged commerce activity through the FastAPI
application, structured Container Apps logs, Log Analytics, Microsoft Sentinel,
and the existing Sentinel-triggered Logic App into GLPI. Tickets provide a
concise investigation handoff; Sentinel and Log Analytics remain the evidence
sources.

## Current status

- The genuine end-to-end path is verified for brute force, password spray,
  multiple failed logins, and synthetic administrator activity. Seven live
  Sentinel incidents have one automatically generated GLPI ticket each; one
  additional suspicious-request case is also verified.
- All eight cases were replayed through real Sentinel trigger histories. The
  Logic App succeeded, duplicate ticket creation was skipped, and ticket
  content/follow-up hashes stayed unchanged.
- All eight open cases now show the actual correlated source IP. The one-field
  post-creation GLPI update preserved titles, status, and analyst follow-ups;
  future cases receive the source directly from the Logic App.
- **4/20 requested scenarios are verified; 16 remain blocked** by missing
  identity/MFA or endpoint/EDR sources, or because the safe negative test did not
  demonstrate compromise, unauthorized creation, or privilege escalation.
- The last refreshed full Terraform plan reports no changes or destroys. The
  current remote state backup is recorded in
  [`scenario-progress.md`](scenario-progress.md).

## Start here

- [`scenario-progress.md`](scenario-progress.md): scenario status, exact
  incident and ticket IDs, live evidence, limitations, and replay verification.
- [`runbook.md`](runbook.md): beginner investigation, classification,
  escalation, remediation ownership, and closure criteria.
- [`case-catalogue.md`](case-catalogue.md): detections and what each signal
  actually represents.
- [`architecture.md`](architecture.md): deployed components and data flow.
- [`k6.md`](k6.md): bounded reproduction and validation commands.
- [`soc/kql/hunting-pack.kql`](../../soc/kql/hunting-pack.kql): investigation
  queries for Log Analytics.

Never treat an HTTP request as proof of endpoint malware, MFA, trusted
geolocation, compromise, or a successful privilege change. Unavailable
prerequisites are explicitly recorded rather than simulated as telemetry.
