# SOC platform acceptance matrix (2026-10-30)

| Component | Status | Evidence |
|---|---|---|
| Commerce health | PASS | `https://shop.platf0rm.site/health` returned `{"status":"healthy"}`. |
| Commerce readiness/database | PASS | `/ready` returned `{"status":"ready","database":"connected"}`. |
| Log Analytics | PASS | `ContainerAppConsoleLogs_CL` returned recent rows through Azure CLI. |
| Sentinel onboarding | PASS | Workspace `secure-commerce-dev-law` is onboarded. |
| Sentinel scheduled detections | PASS | Six scheduled rules are deployed: authentication burst, API burst, telemetry gap, suspicious success, privilege probing, and cloud admin changes. |
| Bounded k6 telemetry | PASS | Scenario `auth-burst-20261030` ran against the owned shop endpoint at one request/sec with one VU. Log Analytics showed 240 events for `/api/auth/login` and `/api/products`, with status codes `422`, `429`, and `200`. |
| GLPI HTTPS/application | BLOCKED | Disabled until a durable external MySQL-compatible service is supplied. |
| Durable GLPI database | BLOCKED | Azure MySQL Flexible Server exposed no SKUs; VM fallback was removed after repeated free-trial capacity denial. |
| Sentinel-to-GLPI automation | BLOCKED | Requires a working GLPI API endpoint and credentials. |
| Endpoint security/EDR | NOT STARTED | Requires a licensing check and separate approval for any paid endpoint service. |
