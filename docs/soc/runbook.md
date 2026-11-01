# SOC runbook

## Start an investigation

1. Open **Sentinel** from the GLPI case. Read the incident severity, alert,
   related entities, incident activity window, and any similar incidents.
2. Open **Log Analytics** from the second case link. It opens the
   `secure-commerce-dev-law` workspace. Start with `ContainerAppConsoleLogs_CL`
   and the incident time window; use the correlation ID shown in the case to
   find related events. Use `soc/kql/hunting-pack.kql` for saved queries.
3. Compare failed/denied requests with successful actions. Determine source,
   targeted identities, affected assets, and whether the controls prevented the
   activity. Treat hashed identifiers as the same identity only when the logs
   support that correlation. Use `unknown` when a source is only a proxy.
4. Record your own timeline, evidence links, scope, impact, classification,
   confidence, and decision in GLPI follow-ups. The initial case intentionally
   leaves the findings for the analyst.

## Classify and respond

- **Expected or benign activity:** Verify the user, change, or test context with
  the service owner. Document why it is expected and close only when the
  evidence supports that finding.
- **Attempt prevented by a control:** Record the failures/denials and confirm
  no related success or impact. State which control worked (for example,
  account lockout or an authorization denial). Do not reset credentials, unlock
  an account, or block an IP solely because failed attempts occurred.
- **Confirmed or suspected successful unauthorized action:** Escalate promptly
  to the SOC lead and relevant application/identity owner. Establish session,
  account, affected resource, and impact before recommending containment.
  Credential reset, session revocation, account disablement, or permission
  changes require the authorized owner and approval; they are never automatic.
- **Unclear evidence or telemetry gap:** Keep the case open and escalate for
  specialist review. Do not infer compromise, location, endpoint behavior, or
  user intent from HTTP traffic alone.

## Scenario decisions

- **Brute force / password spray:** Count failures, identify targeted hashed
  accounts and actual source, check lockout/rate-limit outcomes, and search for
  later successes. If no success occurred and lockout worked, document the
  preventive control. Ask the commerce owner to review authentication controls
  only if activity is sustained, impacts users, or exposes a control gap.
- **Successful login after failures:** Validate the identity and session with
  the account owner, then examine subsequent account activity. A real login
  using known synthetic credentials is not proof of compromise. Escalate if
  independent evidence shows an unauthorized session or action.
- **Registration rejections:** Verify responses and confirm no unauthorized
  account exists. A rejected duplicate registration is not account creation;
  document the control result and close when the scope is checked.
- **Privilege probes:** Identify the principal, protected endpoint, and 403
  results, then search for any successful privileged action. If the denials held
  and there is no impact, document authorization effectiveness. A 403 is not
  privilege escalation.
- **Administrator activity:** Confirm the actor, role, expected task, and
  related changes with the application owner. Directory reads alone do not
  prove malicious activity. Escalate unexpected successful changes.
- **Suspicious API requests:** Review the matched request, response, and related
  activity in the app telemetry. Distinguish blocked probing from a successful
  exploit; do not repeat destructive requests during investigation.
- **Endpoint, MFA, or location scenarios:** This lab has no corresponding
  endpoint/EDR, MFA challenge, or trusted identity sign-in feed. Do not close a
  case as verified from commerce HTTP telemetry alone; obtain the source and
  specialist owner before investigating these event types.

## Remediation ownership

The **SOC analyst** owns evidence gathering, classification, case notes, and
escalation. The **commerce application owner** owns application authentication,
registration, rate-limit, and authorization changes. A future **identity
administrator** owns identity sign-ins, MFA, account controls, and session
actions; a future **endpoint/EDR owner** owns endpoint containment and cleanup.
Those teams are not integrated into this lab's GLPI assignment workflow, so name
the receiving owner in the case and track the handoff explicitly.

Never automatically block an IP, reset a password, disable an account, revoke a
session, change a role, or destroy a resource. Before remediation, document the
evidence, scope, affected identities/assets, expected impact, approval, and
responsible owner. After an approved change, verify effectiveness using new
relevant telemetry and confirm normal service was not disrupted. Do not add
unneeded remediation when the application already prevented the activity.

## Escalation and closure

Escalate confirmed unauthorized access, successful privileged activity,
control failure, material impact, ongoing user impact, or significant
uncertainty. Include the immutable incident ID, UTC window, timeline, affected
entities, sources and attribution confidence, impact, evidence links, actions
taken, and requested decision. GLPI does not currently configure a dedicated
SOC escalation owner/group; make the handoff explicit in the case.

Close only when all of the following are documented:

- Evidence sources and UTC timeline, with relevant successful and prevented
  actions distinguished.
- Affected identities, assets, scope, and impact, or an explicit statement of
  what remains unknown.
- Classification and confidence with evidence-based reasoning.
- Control effectiveness and any remediation decision, owner, approval, and
  effectiveness check.
- Escalation/handoff decision and a clear closure justification.

Keep inconclusive cases open. Use a GLPI follow-up for findings; do not paste
credentials, raw log dumps, or speculative conclusions into the initial case.

## Evidence and training boundaries

GLPI is the case record; Sentinel and Log Analytics are the investigation
tools. The current app logs real structured authentication, registration,
authorization, admin, and request events to `ContainerAppConsoleLogs_CL`.
Source attribution uses the observed connection telemetry; do not invent
country information. Entra Premium/sign-in and endpoint/EDR telemetry are
unavailable and the scenarios needing them remain blocked. See
[`scenario-progress.md`](scenario-progress.md) for live identifiers, validation,
and limitations, and [`k6.md`](k6.md) for bounded reproductions.
