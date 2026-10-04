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
pip install -r requirements.txt
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

## Repository layout

```text
backend/    FastAPI application, Alembic migration, seed, and tests
frontend/   React + TypeScript + Vite storefront and Nginx runtime
evidence/   Reproducible local acceptance evidence grouped by ticket
docker-compose.yml
.env.example
```
