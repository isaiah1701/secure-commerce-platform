# SOC runbook

## Triage

1. Open the Sentinel incident and copy the alert time window.
2. Run the matching query from `soc/kql/hunting-pack.kql` in the `secure-commerce-dev-law` workspace.
3. Pivot on source, path, status, caller, and resource ID. Save the result as evidence.
4. Decide whether the event is synthetic lab traffic, an expected deployment, or an incident.

## Containment

Use application-level rate limiting and credential rotation for commerce cases. For Azure changes, confirm the caller and deployment run before reversing anything. Do not delete the commerce resource group as a response action.

## GLPI handoff

GLPI is now durable and its public login page is operational. Ticket creation
through the GLPI API remains disabled until the API is explicitly enabled with
an authenticated, restricted integration account. Do not paste administrator
passwords into a workflow. The planned playbook will retrieve its integration
secret from Key Vault, create one open investigation ticket per Sentinel
incident, preserve the Sentinel incident URL and simulation identifier, and
leave investigation tasks incomplete for Muhammad.

## Evidence and closure

Record the KQL text, UTC window, alert name, screenshots or exported rows, action taken, and validation result in the case record. Close only when the signal has stopped or the accepted risk is documented.
