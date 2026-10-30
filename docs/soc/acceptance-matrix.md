# SOC platform acceptance matrix (2026-10-30)

| Component | Status | Evidence |
|---|---|---|
| Azure subscription offer | PASS | Subscription state `Enabled`; REST policy `quotaId=PayAsYouGo_2014-09-01`; spending limit `Off`. |
| Commerce health | PASS | `https://shop.platf0rm.site/health` returned `{"status":"healthy"}`. |
| Commerce readiness/database | PASS | `/ready` returned `{"status":"ready","database":"connected"}`. |
| Log Analytics | PASS | `ContainerAppConsoleLogs_CL` returned recent rows through Azure CLI. |
| Sentinel onboarding | PASS | Workspace `secure-commerce-dev-law` is onboarded. |
| Sentinel scheduled detections | PASS | Six scheduled rules are deployed: authentication burst, API burst, telemetry gap, suspicious success, privilege probing, and cloud admin changes. |
| Bounded k6 telemetry | PASS | Scenario `auth-burst-20261030` ran against the owned shop endpoint at one request/sec with one VU. Log Analytics showed 240 events for `/api/auth/login` and `/api/products`, with status codes `422`, `429`, and `200`. |
| Traceable SOC simulation telemetry | PASS | `soc-auth-rate-clean-20261030T102036Z` produced 123 correlated `Log_s` events, including 49 `RATE_LIMIT_EXCEEDED` and 49 HTTP 429 records, with `simulation_id`, request IDs, source IPs, and timestamps. |
| Sentinel incident creation | PASS | Incident `9e2ab71b-0b90-4ee6-ab8a-4cabfa69d2ea` (incident number 15), severity Medium, was created by `secure-commerce-dev-auth_rate_limit` after the clean simulation. |
| GLPI DNS | PASS | `ticket.platf0rm.site` resolves to the GLPI Container App CNAME and Azure Container Apps edge IP. |
| GLPI HTTPS/application | PASS | Managed SNI certificate is active; `https://ticket.platf0rm.site/` returned HTTP 200 and the GLPI authentication page. See `docs/glpi-runtime-verification.md`. |
| Durable GLPI database | PASS (metadata verified) | MySQL is `Ready` with public access disabled; the live GLPI schema has 442 tables and the existing database metadata was repaired without touching tickets, users, or files. Ticket/attachment persistence still requires a dedicated test account. |
| Sentinel-to-GLPI automation | PASS (trigger and replay) | Native Sentinel trigger is deployed; Logic App run `08584082471491068316023616235CU60` succeeded and created GLPI ticket 1 for incident 17. Replaying the same incident left GLPI search `totalcount=1`. |
| GLPI authenticated integration | PASS | Dedicated restricted GLPI account authenticated successfully after password and application-token rotation; values are stored in Key Vault and retrieved by the Logic App managed identity. |
| Endpoint security/EDR | NOT STARTED | Requires a licensing check and separate approval for any paid endpoint service. |
