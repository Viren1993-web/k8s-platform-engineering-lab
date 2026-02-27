# Week 1 — Container Foundation

## Objectives

Build a production-grade containerized Go microservice that:
- Follows 12-factor app principles
- Is secure by default
- Is ready for Kubernetes deployment
- Produces structured, parseable logs

---

## What Was Built

### Application (`app/`)
- **Go HTTP microservice** with health, readiness, metrics, and API endpoints
- **Structured JSON logging** via `zap` (production) with human-readable dev mode
- **Graceful shutdown** handling SIGINT/SIGTERM with connection draining
- **Request tracing** via X-Request-ID middleware
- **Panic recovery** middleware (never crash the process)
- **Environment-based configuration** (12-factor)

### Docker (`docker/`)
- **Multi-stage Dockerfile** — build in golang:1.26-alpine, run in distroless
- **~10MB final image** (static Go binary + distroless base)
- **Non-root user** (UID 65532)
- **Build-time metadata injection** (version, commit SHA, build time)
- **Docker Compose** for local development and production-like testing
- **Development Dockerfile** with hot-reload via `air`

### Security (`scripts/`)
- **Trivy** — CVE vulnerability scanning
- **Hadolint** — Dockerfile linting against best practices
- **Dockle** — CIS Docker benchmark compliance
- **Smoke tests** — Validate all endpoints respond correctly

### Automation (`Makefile`)
- `make build` — Build production image
- `make run` — Start with Docker Compose
- `make test` — Run Go tests
- `make scan` — Full security scan
- `make smoke` — Endpoint validation

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Go language | Cloud-native standard, static binaries, fast startup |
| Distroless base | Minimal attack surface, no shell |
| Structured logging | Machine-parseable for ELK/Loki/CloudWatch |
| Prometheus metrics | Industry standard, ready for Week 3 |
| Graceful shutdown | Zero-downtime deployments in Kubernetes |

---

## Endpoints

| Endpoint | Purpose | Response |
|----------|---------|----------|
| `GET /healthz` | Kubernetes liveness probe | `{"status":"alive"}` |
| `GET /readyz` | Kubernetes readiness probe | `{"status":"ready","uptime":"..."}` |
| `GET /metrics` | Prometheus metrics | Prometheus text format |
| `GET /api/v1/info` | Service metadata | Version, environment, Go version |
| `GET /api/v1/status` | Runtime status | Uptime, goroutines, memory |

---

## How to Run

```bash
# Build and run
make build
make run

# Verify
make smoke

# Security scan
make scan

# View logs
docker logs -f platform-api
```
