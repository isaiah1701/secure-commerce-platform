# SOC runbook

## Analyst workflow

Use this order for every case:

1. **Sentinel:** open the incident link in the GLPI ticket and review the rule,
   severity, entities, alerts, and timeline.
2. **Log Analytics:** open the workspace link and review the log source relevant
   to the alert around the incident timestamp. For commerce alerts, start with
   `ContainerAppConsoleLogs_CL`; for cloud-change alerts, use `AzureActivity`.
3. **Investigation:** identify the source, identity, endpoint or resource, then
   compare successful activity with blocked or failed activity. Expand the time
   range only when the timeline needs context.
4. **GLPI:** record the timeline, evidence links, affected resources, impact,
   classification, confidence, and escalation decision.
5. **Resolution:** resolve only with a clear finding and justification; escalate
   confirmed unauthorized access, successful privileged activity, control failure,
   material impact, or serious uncertainty.

## Containment

Use application-level rate limiting and credential rotation for commerce cases. For Azure changes, confirm the caller and deployment run before reversing anything. Do not delete the commerce resource group as a response action.

## Evidence and closure

GLPI is the case record, not the primary hunting interface. Do not paste full
query results, credentials, or implementation details into it. Reference the
Sentinel incident and relevant Log Analytics results, and summarize the finding
in plain language. Close only when the evidence, timeline, affected resources,
impact, classification, and escalation decision are documented.

## Case-management notes

Automation creates one open GLPI case for a Sentinel incident, preserves the
incident link, and does not close the case. Technical enrichment is used for
correlation and duplicate prevention behind the scenes; it is not required for
analyst triage. Add findings as a GLPI follow-up or in the case description.

## Scenario-specific decisions

- Authentication failures/lockout: prove attempts, targeted accounts, sources, lockout, success, other accounts, and brute force/password spraying versus benign activity.
- Authentication rate limiting: prove endpoint, volume, duration, HTTP 429 count, accepted requests, source concentration, and legitimate impact.
- Privilege boundary probing: prove restricted endpoints, identity/permissions, 403 count, privileged success, and authorization enforcement.
- Suspicious API activity: use safe path/parameter representations, determine probing versus exploitation, response outcomes, validation, and related activity.
- Correlated activity: reconstruct the sequence and correlate source, identity,
  request ID, and related events; reassess severity if failures precede success
  or probing.

Escalations include the incident ID, incident time window, timeline, scope,
evidence links, impact, confidence, and requested action. The escalation
owner/group is not configured in the current GLPI deployment and remains an
operational gap.

## Concise GLPI handoff

Each ticket follows: Incident summary → Investigation objective → Investigation
steps → Definition of Done. Analysts should not need the repository, Terraform,
the automation implementation, or a hunting-pack file to complete triage.
