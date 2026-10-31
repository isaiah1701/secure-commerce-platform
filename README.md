# Secure Commerce Platform

A compact, production-style e-commerce application designed for cloud security and SOC training. It includes a FastAPI/PostgreSQL API, React storefront, admin controls, structured JSON security telemetry, request correlation, health checks, and Prometheus metrics.

## Start locally with Docker

You only need Docker Desktop (or Docker Engine with Compose).

```bash
docker compose up --build -d
```

Then open:

- Storefront: http://localhost:3000
- API documentation: http://localhost:8000/api/docs
- Health: http://localhost:8000/health
- Readiness: http://localhost:8000/ready
- Metrics: http://localhost:8000/metrics

The initial migration and idempotent seed run automatically when the backend container starts.

### Local-development-only accounts

| Role | Email | Password |
|---|---|---|
| Customer | `customer@example.com` | `DemoPass!2026` |
| Admin | `admin@example.com` | `AdminPass!2026` |

These defaults are intentionally public and must not be used outside local development. To customize credentials and secrets, copy `.env.example` to `.env`, replace `JWT_SECRET`, `POSTGRES_PASSWORD`, and the demo passwords, then start Compose.

```bash
cp .env.example .env
docker compose up --build -d
```

Useful commands:

```bash
docker compose ps
docker compose logs -f backend
docker compose down
docker compose down -v   # also removes the local database volume
```

## Development without containers

Backend (requires PostgreSQL and environment variables matching `.env.example`):

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
alembic upgrade head
python -m app.seed
uvicorn app.main:app --reload
```

Frontend:

```bash
cd frontend
npm install
npm run dev
```

Vite proxies API and operational endpoints to `localhost:8000`.

## Tests

```bash
cd backend
pytest -q

cd ../frontend
npm run build
```

Backend tests use an isolated SQLite database. Application runtime uses PostgreSQL.

## Security and observability

- Argon2 password hashing and expiring signed JWT access tokens
- Account lockout after five failed logins and basic per-IP authentication rate limiting
- Server-side customer ownership and admin-role checks
- Parameterized SQL through SQLAlchemy and Pydantic request validation
- Security headers, safe centralized errors, and suspicious-pattern detection
- JSON request logs with request ID, route, status, timing, user context, client IP, and user agent
- Explicit events such as `AUTH_LOGIN_FAILURE`, `AUTH_ACCOUNT_LOCKED`, `AUTH_FORBIDDEN`, `ORDER_CREATED`, and `SUSPICIOUS_REQUEST`
- Email addresses in failed-login telemetry are represented by a short SHA-256 digest; passwords, tokens, cookies, and authorization headers are never logged

### Actions that generate security telemetry

| Application action | Event emitted | Investigation value |
|---|---|---|
| Registration succeeds or is rejected | `AUTH_REGISTER_SUCCESS`, `AUTH_REGISTER_FAILURE` | Account creation and duplicate-registration activity |
| Login succeeds or fails | `AUTH_LOGIN_SUCCESS`, `AUTH_LOGIN_FAILURE` | Authentication baselines and credential-attack detection |
| Five failed logins lock an account | `AUTH_ACCOUNT_LOCKED` | Brute-force and account-targeting detection |
| Authentication traffic exceeds the per-IP limit | `RATE_LIMIT_EXCEEDED` | Automated or high-volume authentication attempts |
| A user signs out | `AUTH_LOGOUT` | Session lifecycle correlation |
| A missing, invalid, or expired token is used | `AUTH_UNAUTHORIZED` | Unauthenticated API access attempts |
| A customer calls an admin endpoint | `AUTH_FORBIDDEN` | Privilege-boundary probing |
| An admin creates, changes, or disables a product | `ADMIN_PRODUCT_CREATED`, `ADMIN_PRODUCT_UPDATED`, `ADMIN_PRODUCT_DISABLED` | Privileged business changes |
| A customer adds an item to a cart | `CART_ITEM_ADDED` | Business-flow context before checkout |
| Checkout creates an order | `ORDER_CREATED` | High-value transaction correlation |
| Input fails schema validation | `VALIDATION_FAILURE` | Malformed requests and API probing |
| A request contains obvious script, SQL injection, or traversal markers | `SUSPICIOUS_REQUEST` | Safe observation of common attack payloads |
| Any HTTP request completes | `HTTP_REQUEST` | Request ID, route, response, timing, identity, IP, and user-agent context |

Authentication failures use a one-way email digest rather than the raw email. Passwords, hashes, bearer tokens, cookies, and authorization headers are never included in logs.

The in-memory rate limiter is appropriate for this intentionally small single-instance learning app. Replace it with a shared store such as Redis before scaling to multiple replicas.

Ticket verification evidence is stored in [`evidence/SP-5/`](evidence/SP-5/README.md).

## Azure deployment platform

The Azure path keeps the application a modular monolith. The production [Dockerfile](Dockerfile) builds React once and serves the compiled assets and FastAPI API from one non-root container on port 8000. Local development remains the three-service Docker Compose setup.

### Architecture

![Secure Commerce Azure SOC Platform — current cloud infrastructure](https://github.com/user-attachments/assets/cd6dd7ad-43c8-4d8f-b096-968e50e1a901)

The diagram is a snapshot of the deployed commerce and GLPI applications, private databases,
centralized monitoring, Sentinel detections, and the SOC training workflow. Its Logic App status
predates the deployed Sentinel-to-GLPI automation; see the [SOC acceptance matrix](docs/soc/acceptance-matrix.md)
for current status.

The VNet uses `10.20.0.0/16`, with `10.20.0.0/23` delegated to Container Apps and `10.20.4.0/24` delegated exclusively to PostgreSQL. PostgreSQL public access is disabled and its hostname resolves through a VNet-linked private DNS zone.

### Terraform modules

| Module | Responsibility |
|---|---|
| `network` | VNet, Container Apps subnet, PostgreSQL delegated subnet, and PostgreSQL private DNS |
| `acr` | Basic ACR, user-assigned application identity, `AcrPull`, CI `AcrPush`, and diagnostics |
| `monitoring` | 30-day Log Analytics workspace and workspace-based Application Insights |
| `key-vault` | RBAC-enabled vault, application secrets, app secret-read role, and audit diagnostics |
| `postgres` | Private PostgreSQL Flexible Server, `commerce` database, TLS enforcement, and diagnostics |
| `container-app` | Managed environment, external HTTPS ingress, probes, scaling, ACR identity, and Key Vault references |
| `dns` | Optional Azure public DNS zone, CNAME/TXT verification, and managed custom-domain binding |

The resource group remains in the root module. Module inputs and outputs express every cross-module dependency; modules do not discover each other by naming conventions.

### Local versus Azure

| Concern | Local development | Azure |
|---|---|---|
| Runtime | Frontend, backend, and PostgreSQL Compose services | One frontend/backend monolith image plus managed PostgreSQL |
| Secrets | Local `.env` or Compose development defaults | GitHub environment secrets → Terraform → Key Vault → Container App references |
| Database | PostgreSQL container | Private PostgreSQL Flexible Server with required TLS |
| Logs | JSON logs through `docker compose logs` | Container logs in Log Analytics and OpenTelemetry requests/logs in Application Insights |
| Images | Built locally by Compose | SHA-tagged image in ACR, pulled with a user-assigned identity |

### One-time remote-state bootstrap

Terraform state is never committed. Create the state resources once with a globally unique storage account name:

```bash
az login
az account set --subscription "<subscription-id>"

cd infra/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Replace the storage account placeholder in terraform.tfvars.
terraform init
terraform fmt -check
terraform validate
terraform apply
```

The bootstrap disables storage account shared keys, enables blob versioning and soft deletion, and grants the caller `Storage Blob Data Contributor`. Grant the GitHub OIDC principal the same role on the state storage account. Record the four bootstrap outputs as GitHub variables described below. The bootstrap state is local and ignored by Git; protect or migrate it separately.

### GitHub OIDC and repository configuration

Create a Microsoft Entra application/service principal or user-assigned managed identity for `isaiah1701/secure-commerce-platform`. Add a federated credential with:

```text
Issuer:   https://token.actions.githubusercontent.com
Subject:  repo:isaiah1701/secure-commerce-platform:environment:dev
Audience: api://AzureADTokenExchange
```

Assign only the roles needed by these workflows:

- `Contributor` on the target subscription or a pre-created deployment resource group.
- `User Access Administrator` on that same scope so Terraform can create `AcrPull`, `AcrPush`, and Key Vault role assignments. A custom role limited to role assignments is preferable when available.
- `Storage Blob Data Contributor` on the remote-state storage account.

Create a protected GitHub Environment named `dev`, ideally with required reviewers for production-like apply/deploy operations. Configure these environment variables:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
TF_STATE_RESOURCE_GROUP
TF_STATE_STORAGE_ACCOUNT
TF_STATE_CONTAINER
AZURE_RESOURCE_GROUP       # secure-commerce-dev-rg by default
ACR_NAME
ACR_LOGIN_SERVER
CONTAINER_APP_NAME         # secure-commerce-dev-app by default
```

Configure these environment secrets; do not put them in a tfvars file:

```text
POSTGRES_ADMIN_PASSWORD
JWT_SECRET
```

Both workflows request GitHub `id-token: write` and use `azure/login`; no Azure client secret or `AZURE_CREDENTIALS` JSON is used.

### Infrastructure deployment

Export secrets locally when planning outside GitHub:

```bash
export TF_VAR_postgres_admin_password='<strong-generated-password>'
export TF_VAR_jwt_secret='<at-least-32-random-characters>'

cd infra
terraform fmt -recursive
terraform init \
  -backend-config="resource_group_name=<state-resource-group>" \
  -backend-config="storage_account_name=<state-storage-account>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=secure-commerce-dev.tfstate" \
  -backend-config="use_azuread_auth=true"
terraform validate
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

The first apply uses a public Microsoft placeholder while ACR is being bootstrapped. It may be unhealthy on the application’s port; this is expected only during bootstrap. The application workflow then builds the root Dockerfile, blocks on high/critical Trivy findings, pushes `<acr>.azurecr.io/secure-commerce:<git-sha>`, updates the Container App revision, and verifies `/health` and `/ready`. Terraform ignores only the deployed image attribute so later plans do not roll a successful SHA deployment back to the placeholder.

### CI/CD flow

`.github/workflows/terraform.yml` runs formatting, initialization, validation, Checkov, and an Azure-backed plan on pull requests. On a push to `main`, it applies the saved plan. Application changes are included in the push trigger so the platform is always reconciled before a deployment. After that Terraform run succeeds, `.github/workflows/deploy.yml` checks out the exact triggering commit, runs Ruff and pytest, frontend lint/build, the production Docker build, Trivy, OIDC login, ACR push, Container App revision deployment, and live health checks. It can also be started manually.

### DNS

The development configuration uses the GoDaddy-registered domain `platf0rm.site` and publishes the application at `shop.platf0rm.site`:

```hcl
domain_name                  = "platf0rm.site"
app_subdomain                = "shop"
enable_custom_domain_binding = false
```

GoDaddy remains the registrar, while Azure DNS becomes the authoritative DNS host. Use this two-stage sequence:

1. Keep `enable_custom_domain_binding = false` and apply Terraform. This creates the `platf0rm.site` Azure DNS zone, the `shop` CNAME pointing directly to the Container App hostname, and the `asuid.shop` verification TXT record.
2. Read the four assigned nameservers with `terraform output dns_name_servers`.
3. Before changing nameservers, copy any existing GoDaddy DNS records that must continue working—especially MX, TXT, verification, or other website records—into the Azure DNS zone. Records left only in GoDaddy DNS stop resolving after delegation. If you copy a CAA policy, ensure it permits `digicert.com` so Azure can issue and renew the managed certificate.
4. In GoDaddy, open **Domain Portfolio → platf0rm.site → DNS → Nameservers → Change Nameservers**, choose the option to enter your own nameservers, and enter all four Azure nameservers from the Terraform output. Do not invent or reuse nameservers from another Azure zone.
5. Verify delegation and records:

   ```bash
   dig NS platf0rm.site +short
   dig CNAME shop.platf0rm.site +short
   dig TXT asuid.shop.platf0rm.site +short
   ```

6. Once public DNS returns the Azure values, set `enable_custom_domain_binding = true` in `infra/environments/dev.tfvars` and apply again. Terraform then creates the Container Apps binding and requests the Azure-managed certificate for `shop.platf0rm.site`.

Keep the `shop` record as a direct CNAME to the generated Container Apps hostname. An intermediate proxy or CNAME can prevent managed-certificate issuance and renewal. The application remains available at its default Container Apps HTTPS hostname during DNS propagation.

### Database connectivity and observability

The application receives a TLS-required SQLAlchemy URL through a versionless Key Vault reference. The Container Apps environment is VNet-integrated and can resolve/reach the private server. Alembic migrations run when the production container starts; production does not seed the local demo accounts.

Container Apps console/system logs flow to Log Analytics. ACR, Key Vault, and PostgreSQL diagnostic settings target the same workspace. The backend activates the Azure Monitor OpenTelemetry distribution only when `APPLICATIONINSIGHTS_CONNECTION_STRING` is present, so local operation is unchanged. Sentinel is intentionally not enabled in this phase, but the workspace is ready for it.

### Security decisions

- GitHub-to-Azure authentication uses OIDC, not stored client secrets.
- The application uses managed identity for ACR and Key Vault; ACR admin and anonymous access are disabled.
- PostgreSQL has no public endpoint and requires TLS 1.2 or later.
- Container ingress is HTTPS-only and has liveness/readiness probes.
- Terraform state, plans, `.env`, certificates, and credentials are ignored by Git.
- Both delegated subnets have network security groups; PostgreSQL still has no public route.
- Key Vault soft deletion is enabled. Purge protection remains off for this disposable development lab so destroy/recreate remains possible.
- Basic ACR has a public service endpoint because private endpoints require Premium; all access remains authenticated and RBAC-controlled.
- Checkov exceptions are inline and justified. They cover deliberate lab constraints such as public service routing for GitHub-hosted runners, Basic-tier ACR features, operator-coordinated secret rotation, and single-region/LRS cost choices.

### Cost considerations

PostgreSQL Flexible Server is the main predictable cost because it does not scale to zero. The configuration uses the small burstable `B_Standard_B1ms` SKU, 32 GiB storage, seven-day local backups, and no HA, replicas, or geo-redundant backup. Container Apps can scale to zero and incurs usage-based compute when active. Basic ACR has a small fixed registry/storage charge. Log Analytics and Application Insights charge primarily by ingestion and retention; verbose attack simulations will increase this. Key Vault charges per operation, while Azure DNS charges per hosted zone and query. Check the Azure Pricing Calculator for current UK South prices before applying because rates change.

### Destroy

```bash
cd infra
terraform destroy -var-file=environments/dev.tfvars
```

The remote-state storage is deliberately separate and is not destroyed with the application platform. Delete it only after the application state is no longer needed.

## Repository layout

```text
backend/    FastAPI application, Alembic migration, seed, and tests
frontend/   React + TypeScript + Vite storefront and Nginx runtime
infra/      Modular Azure Terraform and remote-state bootstrap
.github/    Terraform CI and application deployment workflows
evidence/   Reproducible local acceptance evidence grouped by ticket
Dockerfile  Production monolith image for Azure Container Apps
docker-compose.yml
.env.example
```
