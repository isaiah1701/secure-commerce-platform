# SP-5 — Local acceptance evidence

Verification date: **2026-10-04**<br>
Environment: Docker Compose on Linux, PostgreSQL 16, Python 3.12, Node 22

## Acceptance result

**PASS** — the Secure Commerce Platform runs locally and provides authentication, normal customer activity, admin operations, order checkout, REST APIs, and security-relevant structured telemetry.

| Deliverable | Result | Evidence |
|---|---|---|
| Source-controlled application scaffold | Pass | Backend, frontend, migrations, tests, Compose, environment template, and documentation are committed together |
| Customer and admin flows | Pass | Registration/login, product browsing, cart, checkout, order history, product administration, order viewing, and user viewing are implemented |
| Security-relevant events documented | Pass | README contains an explicit application action-to-event map |
| Runs locally | Pass | PostgreSQL, backend, and frontend containers reported healthy |
| Local test evidence | Pass | 13 backend tests passed and the production frontend build completed successfully |

## Reproduction

From the repository root:

```bash
docker compose up --build -d
docker compose ps
curl -fsS http://localhost:3000/health
curl -fsS http://localhost:3000/ready
curl -fsS http://localhost:3000/api/products | jq length
```

Expected services and URLs:

- Storefront: <http://localhost:3000>
- API documentation: <http://localhost:8000/api/docs>
- Backend health: <http://localhost:8000/health>
- Backend readiness: <http://localhost:8000/ready>
- Prometheus metrics: <http://localhost:8000/metrics>

## Recorded runtime result

```text
SERVICE    STATUS
db         healthy
backend    healthy
frontend   healthy

GET /health  -> {"status":"healthy"}
GET /ready   -> {"status":"ready","database":"connected"}
GET /api/products -> 20 products
```

The live frontend response also returned:

```text
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Content-Security-Policy: default-src 'self'; ...
```

## Recorded automated checks

Backend command:

```bash
docker compose run --rm \
  -e JWT_SECRET=test-secret-that-is-long-enough-for-tests \
  -v "$PWD/backend/app:/app/app:ro" \
  -v "$PWD/backend/tests:/app/tests:ro" \
  backend python -m pytest -q
```

Result:

```text
.............                                                            [100%]
13 passed, 1 warning in 2.46s
```

The warning is a third-party Starlette/AnyIO deprecation warning and does not indicate a test or application failure.

Frontend command and result:

```text
$ cd frontend && npm run build
✓ 37 modules transformed.
dist/index.html                   0.51 kB │ gzip:  0.31 kB
dist/assets/index-Bb67qtHl.css   22.30 kB │ gzip:  5.60 kB
dist/assets/index-FwScrOfP.js   292.43 kB │ gzip: 89.96 kB
✓ built in 1.41s
```

## Covered security scenarios

The backend test suite verifies registration, successful and failed login, account lockout, invalid JWT handling, unauthenticated access, customer/admin authorization, malformed input, product administration, cart validation, checkout, stock reduction, and cross-user order isolation.

Application JSON logs can be observed with:

```bash
docker compose logs -f backend
```

The event/action mapping in the root README identifies the explicit event types available for later Azure Monitor and Microsoft Sentinel ingestion.
