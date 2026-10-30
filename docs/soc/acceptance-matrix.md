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
| GLPI DNS | PASS | `ticket.platf0rm.site` resolves to the GLPI Container App CNAME and Azure Container Apps edge IP. |
| GLPI HTTPS/application | FAIL | DNS resolves, but a normal TLS handshake resets before returning a certificate or HTTP response. See `docs/glpi-runtime-verification.md`. |
| Durable GLPI database | UNVERIFIED | Private MySQL and GLPI Terraform are present, but Azure CLI authentication is unavailable in the current session. |
| Sentinel-to-GLPI automation | BLOCKED | No Logic Apps/Sentinel-to-GLPI workflow exists in the current repository; endpoint and credentials also require live verification. |
| Endpoint security/EDR | NOT STARTED | Requires a licensing check and separate approval for any paid endpoint service. |
