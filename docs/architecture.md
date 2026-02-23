# Architecture — Platform API Service

## Overview

The Platform API is a production-grade Go microservice designed from the ground up for Kubernetes deployment. It demonstrates real-world platform engineering patterns including structured observability, graceful lifecycle management, and defense-in-depth container security.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                       │
│                                                                 │
│  ┌───────────────┐    ┌──────────────────────────────────────┐  │
│  │   Ingress     │───▶│         Platform API Pod             │  │
│  │  Controller   │    │  ┌──────────────────────────────────┐│  │
│  └───────────────┘    │  │     Distroless Container         ││  │
│                       │  │                                  ││  │
│  ┌───────────────┐    │  │  ┌─────────┐  ┌──────────────┐   ││  │
│  │  Prometheus   │───▶│  │  │ Request │  │  Structured  │   ││  │
│  │  (metrics)    │    │  │  │Middleware│ │  JSON Logger │   ││  │
│  └───────────────┘    │  │  └────┬────┘  └──────────────┘   ││  │
│                       │  │       │                          ││  │
│  ┌───────────────┐    │  │  ┌────▼─────────────────────-┐   ││  │
│  │   Kubelet     │───▶│  │  │      HTTP Router          │   ││  │
│  │ (health check)│    │  │  │                           │   ││  │
│  └───────────────┘    │  │  │  /healthz  → Liveness     │   ││  │
│                       │  │  │  /readyz   → Readiness    │   ││  │
│                       │  │  │  /metrics  → Prometheus   │   ││  │
│                       │  │  │  /api/v1/* → Business API │   ││  │
│                       │  │  └──────────────────────────-┘   ││  │
│                       │  └──────────────────────────────────┘│  │
│                       └──────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Container Architecture

```
┌──────────────────────────────┐
│     Multi-Stage Build        │
│                              │
│  ┌────────────────────────┐  │
│  │   Stage 1: Builder     │  │
│  │   golang:1.26-alpine   │  │
│  │   - Download deps      │  │
│  │   - Compile static bin │  │
│  │   - Inject version     │  │
│  └───────────┬────────────┘  │
│              │               │
│  ┌───────────▼────────────┐  │
│  │  Stage 2: Production   │  │
│  │  distroless/static     │  │
│  │  - ~2MB base image     │  │
│  │  - No shell            │  │
│  │  - No package manager  │  │
│  │  - Non-root user       │  │
│  │  - Read-only fs        │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

### Why Distroless?

| Feature          | Alpine   | Distroless | Ubuntu  |
|------------------|----------|------------|---------|
| Base image size  | ~5 MB    | ~2 MB      | ~77 MB  |
| Shell access     | Yes      | **No**     | Yes     |
| Package manager  | Yes      | **No**     | Yes     |
| CVE surface      | Medium   | **Minimal**| Large   |
| Debug capability | Easy     | Harder     | Easy    |

---

## Request Flow

```
Client Request
     │
     ▼
┌─────────────┐
│  Request ID  │  Inject unique trace ID (or use X-Request-ID header)
│  Middleware   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Logging    │  Log: method, path, status, duration, request_id
│  Middleware   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Recovery    │  Catch panics → return 500 with structured error
│  Middleware   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    CORS      │  Set cross-origin headers
│  Middleware   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Handler    │  Business logic → JSON response
└─────────────┘
```

---

## Configuration

All configuration is via environment variables (12-Factor App methodology):

| Variable           | Default       | Description                    |
|--------------------|---------------|--------------------------------|
| `SERVICE_NAME`     | platform-api  | Service identifier             |
| `SERVICE_VERSION`  | 1.0.0         | Semantic version               |
| `ENVIRONMENT`      | development   | Environment name               |
| `PORT`             | 9090          | HTTP listen port               |
| `LOG_LEVEL`        | info          | Log level (debug/info/warn/error) |
| `READ_TIMEOUT`     | 5s            | HTTP read timeout              |
| `WRITE_TIMEOUT`    | 10s           | HTTP write timeout             |
| `IDLE_TIMEOUT`     | 120s          | HTTP idle timeout              |
| `SHUTDOWN_TIMEOUT` | 30s           | Graceful shutdown window       |

---

## Graceful Shutdown Sequence

```
1. SIGTERM received (Kubernetes sends this)
        │
        ▼
2. Mark service as NOT READY
   (/readyz returns 503)
        │
        ▼
3. Kubernetes stops sending new traffic
   (readiness probe fails)
        │
        ▼
4. Wait for in-flight requests to complete
   (up to SHUTDOWN_TIMEOUT)
        │
        ▼
5. Close server
        │
        ▼
6. Exit cleanly (code 0)
```

This prevents dropped connections during rolling deployments.

---

## Security Model

- **Non-root execution**: Container runs as UID 65532
- **Read-only filesystem**: No writable paths in container
- **No shell**: Distroless has no `/bin/sh` — prevents shell injection
- **No package manager**: Cannot install packages inside running container
- **Minimal CVE surface**: Only static binary + CA certificates
- **Resource limits**: CPU and memory constrained via Docker/K8s
- **Security scanning**: Trivy (CVEs), Hadolint (Dockerfile), Dockle (CIS benchmarks)

---

## Project Roadmap

| Week | Focus                        | Status      |
|------|------------------------------|-------------|
| 1    | Container Foundation         | **Current** |
| 2    | Kubernetes Core              | Planned     |
| 3    | Observability & Auto-scaling | Planned     |
| 4    | Cloud Integration (EKS)      | Planned     |
