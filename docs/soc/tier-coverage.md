# SOC tier coverage

The lab currently produces real, searchable commerce telemetry through the
owned site. These cases are suitable for progressive analyst practice:

| Tier | Skills exercised | Lab case |
|---|---|---|
| L1 | Alert triage, Sentinel timeline, Log Analytics filtering, source and outcome identification, GLPI notes | Failed authentication, rate limiting, suspicious API request |
| L2 | Authentication sequence analysis, authorization review, scope and impact assessment, false-positive reasoning, escalation | Password-spray pattern, successful login after failures, privilege probing, API burst |
| L3 | Detection quality, telemetry reliability, correlation, response planning, control-gap analysis | Correlated multi-event activity, telemetry gap, detection and runbook review |

## What the commerce lab cannot produce

K6 traffic to the commerce application cannot create a genuine endpoint EDR,
phishing, malware, Azure administrative-change, or vulnerability-scanner alert.
Those cases require the corresponding telemetry source, such as Microsoft
Defender for Endpoint, Microsoft Defender for Office 365, Azure Activity, or a
container/image scanner. They should not be represented as EDR tickets from
HTTP traffic. The existing Sentinel rules for cloud changes and telemetry gaps
are available for investigation, but only a real matching event should create a
case.

## Safe traffic

Run only against `shop.platf0rm.site` with synthetic accounts and a unique
scenario ID. `password-spray.js` sends at most five failed logins. `api-read-
burst.js` sends at most 60 read-only product requests. Stop either script with
`KILL_SWITCH=true`; do not increase the limits or use real accounts.
