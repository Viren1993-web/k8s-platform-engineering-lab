# Kubernetes Platform Engineering Lab

> Production-ready Kubernetes platform built iteratively — from optimized containers to full cloud-native infrastructure with observability, auto-scaling, and CI/CD.

[![Docker Build](https://img.shields.io/badge/Docker-Multi--Stage-2496ED?logo=docker&logoColor=white)](docker/Dockerfile)
[![Go](https://img.shields.io/badge/Go-1.26-00ADD8?logo=go&logoColor=white)](app/go.mod)
[![Security](https://img.shields.io/badge/Security-Trivy%20%7C%20Hadolint%20%7C%20Dockle-green)](scripts/security-scan.sh)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## What This Project Demonstrates

This is a **single, evolving platform engineering project** that showcases:

- **Container optimization** — Multi-stage builds, distroless images, ~10MB production containers
- **Security-first approach** — Non-root execution, CVE scanning, CIS benchmarks, no shell in production
- **Production patterns** — Structured logging, graceful shutdown, health probes, config management
- **Kubernetes-native design** — Deployments, Services, Ingress, HPA, PDB, NetworkPolicy, RBAC
- **Helm & Kustomize** — Full Helm chart + Kustomize overlays for dev/staging/production
- **Infrastructure as Code** — Reproducible builds, Docker Compose, Makefile automation

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                   Platform API                        │
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │              Middleware Chain                     │  │
│  │  Request ID → Logging → Recovery → CORS → Route │  │
│  └─────────────────────────────────────────────────┘  │
│                                                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │
│  │ /healthz │ │ /readyz  │ │ /metrics │ │/api/v1/*│  │
│  │ Liveness │ │Readiness │ │Prometheus│ │ Business│  │
│  └──────────┘ └──────────┘ └──────────┘ └─────────┘  │
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │  Structured JSON Logging  │  Graceful Shutdown  │  │
│  └─────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
         │                              │
    Distroless Container           Non-root User
    (~10MB image)                  (UID 65532)
```

> Full architecture documentation: [docs/architecture.md](docs/architecture.md)

---

## Quick Start

```bash
# Clone and run
git clone https://github.com/virenpatel/k8s-platform-engineering-lab.git
cd k8s-platform-engineering-lab

# Start the service (using Makefile)
make run

# Verify it's working
make smoke
```

See [Local Development](#local-development) for other start methods and development workflow.

---

## Local Development

### Starting the Service

Choose your preferred method:

#### **Option 1: Using Makefile (Recommended)**

```bash
make run       # Start with Docker Compose
make stop      # Stop gracefully

# View logs
docker compose -f docker/docker-compose.yml logs -f platform-api
```

#### **Option 2: Docker Compose Directly**

```bash
cd docker && docker compose up -d --build    # Start
cd docker && docker compose logs -f platform-api  # View logs
cd docker && docker compose down              # Stop
```

#### **Option 3: Go Locally (Go 1.26+ required)**

```bash
cd app && go run main.go        # Default port 9090
cd app && PORT=9090 go run main.go  # Custom port
# Stop with: Ctrl+C (graceful shutdown)
```

### Service Endpoints

Once running, test the endpoints:

```bash
curl http://localhost:9090/                    # Root (service info)
curl http://localhost:9090/healthz             # Liveness probe
curl http://localhost:9090/readyz              # Readiness probe
curl http://localhost:9090/api/v1/info         # Service metadata
curl http://localhost:9090/api/v1/status       # Runtime status
curl http://localhost:9090/metrics             # Prometheus metrics
```

### Graceful Shutdown (How It Works)

The app gracefully handles `Ctrl+C` or `SIGTERM`:
1. Stops accepting new requests
2. Waits for in-flight requests to complete (timeout: 30s)
3. Exits cleanly without data loss

```bash
# Example: start in background, make a request, then stop
make run &
curl http://localhost:9090/api/v1/status
make stop  # Waits for pending requests to drain
```

### Common Commands

```bash
# Run all tests
make test
cd app && go test ./...

# Security scans
make scan        # Trivy + Hadolint + Dockle

# Build locally
cd app && go build -o platform-api

# Hot-reload development (requires dev profile in docker-compose)
docker compose -f docker/docker-compose.yml --profile dev up
```

---

## Project Structure

```
k8s-platform-engineering-lab/
├── app/                          # Go microservice source code
│   ├── main.go                   # Entrypoint with graceful shutdown
│   ├── config/                   # Environment-based configuration
│   ├── handlers/                 # HTTP handlers (health, API)
│   └── middleware/               # Request ID, logging, recovery, CORS
├── docker/                       # Container configuration
│   ├── Dockerfile                # Multi-stage production build
│   ├── Dockerfile.dev            # Development with hot-reload
│   ├── docker-compose.yml        # Local orchestration
│   └── .dockerignore             # Build context optimization
├── scripts/                      # Automation scripts
│   ├── build.sh                  # Build with metadata injection
│   ├── security-scan.sh          # Trivy + Hadolint + Dockle
│   ├── smoke-test.sh             # Endpoint validation
│   ├── k8s-deploy.sh             # K8s deployment (Kustomize + Helm)
│   └── k8s-validate.sh           # Deployment validation (6-step)
├── docs/                         # Documentation
│   ├── architecture.md           # System & container architecture
│   ├── week1-container-foundation.md
│   └── week2-kubernetes-core.md
├── kubernetes/                   # K8s manifests + Kustomize overlays
│   ├── base/                     # Base manifests (12 resources)
│   └── overlays/                 # dev / staging / production
├── helm/                         # Helm chart
│   └── platform-api/             # Parameterized chart (v0.2.0)
├── monitoring/                   # Prometheus & Grafana (Week 3)
├── terraform/                    # EKS infrastructure (Week 4)
├── ci-cd/                        # CI/CD pipelines (Week 4)
├── Makefile                      # Development automation
└── .github/workflows/            # GitHub Actions CI
```

---

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/healthz` | GET | Kubernetes liveness probe |
| `/readyz` | GET | Kubernetes readiness probe |
| `/metrics` | GET | Prometheus metrics (scrape target) |
| `/api/v1/info` | GET | Service metadata (version, env, runtime) |
| `/api/v1/status` | GET | Runtime status (uptime, memory, goroutines) |

---

## Container Security

| Layer | Tool | What It Checks |
|-------|------|----------------|
| Dockerfile | **Hadolint** | Best practices, pinned versions, layer optimization |
| Image CVEs | **Trivy** | Known vulnerabilities (HIGH/CRITICAL) |
| CIS Benchmark | **Dockle** | Docker security compliance |
| Runtime | **Distroless** | No shell, no package manager, minimal attack surface |
| User | **Non-root** | Container runs as UID 65532 |

```bash
# Run all security scans
make scan
```

---

## Production Patterns Implemented

- **Multi-stage Docker build** — Compile in golang:alpine, run in distroless (~10MB)
- **Structured JSON logging** — Machine-parseable via Zap (ready for ELK/Loki/CloudWatch)
- **Graceful shutdown** — SIGTERM → mark not-ready → drain connections → exit
- **Request tracing** — X-Request-ID propagation through middleware chain
- **Panic recovery** — Middleware catches panics, returns 500, never crashes
- **12-Factor configuration** — All config via environment variables with defaults
- **Prometheus metrics** — `/metrics` endpoint ready for scraping
- **Resource constraints** — CPU/memory limits in Docker Compose

---

## Development

```bash
# Available commands
make help

# Run tests
make test

# Development mode (hot-reload)
make dev

# Build, scan, and smoke test
make all
```

---

## Roadmap

| Week | Focus | Status |
|------|-------|--------|
| **1** | **Container Foundation** — Multi-stage builds, security scanning, structured logging | **Done** |
| **2** | **Kubernetes Core** — Deployments, Services, Ingress, ConfigMaps, Secrets, Helm, Kustomize | **Done** |
| 3 | **Observability** — Prometheus, Grafana dashboards, HPA, alerting, incident docs | Planned |
| 4 | **Cloud Integration** — Terraform EKS, CI/CD pipeline, IAM, production config | Planned |

---

## Tech Stack

| Category | Technology |
|----------|------------|
| Language | Go 1.26 |
| Container | Docker (multi-stage, distroless) |
| Orchestration | Kubernetes, Docker Compose |
| Package Mgmt | Helm 3, Kustomize |
| Logging | Zap (structured JSON) |
| Metrics | Prometheus client |
| Security | Trivy, Hadolint, Dockle, NetworkPolicy, RBAC |
| Automation | Make, Bash |
| CI | GitHub Actions |

---

## License

MIT