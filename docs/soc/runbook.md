# SOC runbook

## Triage

1. Open the Sentinel incident and copy the alert time window.
2. Run the matching query from `soc/kql/hunting-pack.kql` in the `secure-commerce-dev-law` workspace.
3. Pivot on source, path, status, caller, and resource ID. Save the result as evidence.
4. Decide whether the event is synthetic lab traffic, an expected deployment, or an incident.

## Containment

Use application-level rate limiting and credential rotation for commerce cases. For Azure changes, confirm the caller and deployment run before reversing anything. Do not delete the commerce resource group as a response action.

## GLPI handoff

Automatic ticket creation is intentionally disabled while GLPI has no durable database. Once a durable MySQL-compatible endpoint is supplied, enable GLPI, validate HTTPS, create a test ticket, recreate both workloads, and verify the ticket remains before wiring Sentinel to GLPI.

## Evidence and closure

Record the KQL text, UTC window, alert name, screenshots or exported rows, action taken, and validation result in the case record. Close only when the signal has stopped or the accepted risk is documented.
