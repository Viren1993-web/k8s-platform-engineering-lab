# Week 2 — Kubernetes Core

## Objectives

Deploy the platform-api as a production-grade Kubernetes workload with security, high availability, and multi-environment support.

---

## What Was Built

### Raw Manifests (`kubernetes/base/`)

| Resource | File | Purpose |
|----------|------|---------|
| Namespace | `namespace.yaml` | Workload isolation |
| ServiceAccount | `serviceaccount.yaml` | Pod identity with auto-mount disabled |
| ConfigMap | `configmap.yaml` | Non-sensitive 12-factor configuration |
| Secret | `secret.yaml` | Sensitive config (placeholder values) |
| Deployment | `deployment.yaml` | 3-replica rolling deployment with full security |
| Service | `service.yaml` | ClusterIP internal load balancing |
| Ingress | `ingress.yaml` | External HTTPS routing with rate limiting |
| NetworkPolicy | `networkpolicy.yaml` | Zero-trust pod-to-pod networking |
| HPA | `hpa.yaml` | CPU/memory-based auto-scaling (2–10 pods) |
| PDB | `pdb.yaml` | Disruption budget (min 2 available) |
| ResourceQuota | `resourcequota.yaml` | Namespace resource caps |
| LimitRange | `limitrange.yaml` | Per-container default limits |

### Helm Chart (`helm/platform-api/`)

Full Helm chart with:
- Parameterized templates for all resources
- `values.yaml` with production defaults
- Conditional rendering (ingress, HPA, network policy, secrets)
- ConfigMap checksum annotation (auto-restart on config change)
- Helm tests for deployment validation

### Kustomize Overlays (`kubernetes/overlays/`)

| Environment | Replicas | HPA | NetworkPolicy | Log Level |
|-------------|----------|-----|---------------|-----------|
| **dev** | 1 | Off | Off | debug |
| **staging** | 2 | On | On | info |
| **production** | 3 | On | On | info |

### Scripts

- `k8s-deploy.sh` — Deploy via Kustomize or Helm to any environment
- `k8s-validate.sh` — Comprehensive health check (pods, endpoints, probes)

---

## Production Patterns Applied

### Deployment Strategy
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # One extra pod during rollout
    maxUnavailable: 0  # Never drop below desired count
```
This ensures **zero-downtime deployments**.

### Security Context
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
  seccompProfile:
    type: RuntimeDefault
```

### Probe Configuration
| Probe | Path | Purpose |
|-------|------|---------|
| Startup | `/healthz` | Wait for app to initialize before checking liveness |
| Liveness | `/healthz` | Restart container if process is stuck |
| Readiness | `/readyz` | Remove from service if not ready to serve |

### Anti-Affinity + Topology Spread
- **Pod anti-affinity**: Spread across nodes (no two pods on same node)
- **Topology spread**: Distribute across availability zones

---

## How to Deploy

```bash
# Kustomize (dev)
make k8s-deploy

# Kustomize (production)
make k8s-deploy-prod

# Helm
make helm-deploy

# Validate
make k8s-validate

# Check status
make k8s-status

# Tail logs
make k8s-logs
```

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Both Kustomize and Helm | Shows fluency in both tools (real teams use both) |
| NetworkPolicy | Zero-trust; only ingress controller + Prometheus can reach pods |
| PodDisruptionBudget | Prevents accidental outage during node maintenance |
| ResourceQuota + LimitRange | Namespace guardrails; prevents noisy-neighbor problems |
| Startup probes | Prevents false liveness failures during slow cold starts |
| Topology spread | Multi-AZ resilience for production |
| ServiceAccount with no auto-mount | Reduces token exposure; follows least-privilege |
