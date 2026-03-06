# ============================================================================
# Makefile — Platform API Development Commands
# ============================================================================
# Usage:
#   make help           Show this help
#   make build          Build Docker image
#   make run            Run locally with Docker
#   make test           Run Go tests
#   make lint           Lint Dockerfile
#   make scan           Security scan
#   make smoke          Run smoke tests
#   make k8s-deploy     Deploy to Kubernetes (dev)
#   make k8s-validate   Validate K8s deployment
#   make helm-deploy    Deploy with Helm
#   make helm-template  Render Helm templates locally
#   make clean          Clean up containers and images
# ============================================================================

.PHONY: help build run stop test lint scan smoke clean dev all \
        k8s-deploy k8s-deploy-staging k8s-deploy-prod k8s-validate k8s-status k8s-logs k8s-clean \
        helm-deploy helm-template helm-lint

# ── Variables ────────────────────────────────────────────────────────────────
IMAGE_NAME    := platform-api
VERSION       := 1.0.0
COMMIT_SHA    := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TIME    := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
DOCKER_COMPOSE := docker compose -f docker/docker-compose.yml
K8S_NAMESPACE := platform-api

# ── Default ──────────────────────────────────────────────────────────────────
help: ## Show this help message
	@echo ""
	@echo "Platform API — Development Commands"
	@echo "===================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ── Build ────────────────────────────────────────────────────────────────────
build: ## Build production Docker image
	@bash scripts/build.sh $(IMAGE_NAME) $(VERSION)

# ── Docker Run ───────────────────────────────────────────────────────────────
run: ## Run the service with Docker Compose
	@BUILD_TIME=$(BUILD_TIME) COMMIT_SHA=$(COMMIT_SHA) $(DOCKER_COMPOSE) up --build -d
	@echo ""
	@echo "Service running at http://localhost:8080"
	@echo "  Health:  http://localhost:8080/healthz"
	@echo "  Ready:   http://localhost:8080/readyz"
	@echo "  Metrics: http://localhost:8080/metrics"
	@echo "  Info:    http://localhost:8080/api/v1/info"
	@echo "  Status:  http://localhost:8080/api/v1/status"

stop: ## Stop all containers
	@$(DOCKER_COMPOSE) down

dev: ## Run in development mode with hot-reload
	@$(DOCKER_COMPOSE) --profile dev up --build

# ── Test ─────────────────────────────────────────────────────────────────────
test: ## Run Go unit tests
	@cd app && go test -v -race -cover ./...

smoke: ## Run smoke tests against running service
	@bash scripts/smoke-test.sh

# ── Security ─────────────────────────────────────────────────────────────────
lint: ## Lint Dockerfile with Hadolint
	@hadolint docker/Dockerfile

scan: build ## Run security scans on Docker image
	@bash scripts/security-scan.sh $(IMAGE_NAME):$(VERSION)

# ── Kubernetes (Kustomize) ───────────────────────────────────────────────────
k8s-deploy: build ## Deploy to K8s (dev environment)
	@bash scripts/k8s-deploy.sh dev

k8s-deploy-staging: build ## Deploy to K8s (staging)
	@bash scripts/k8s-deploy.sh staging

k8s-deploy-prod: build ## Deploy to K8s (production)
	@bash scripts/k8s-deploy.sh production

k8s-validate: ## Validate K8s deployment health
	@bash scripts/k8s-validate.sh $(K8S_NAMESPACE)

k8s-status: ## Show K8s resources status
	@echo "=== Pods ==="
	@kubectl get pods -n $(K8S_NAMESPACE) -o wide 2>/dev/null || echo "Namespace not found"
	@echo ""
	@echo "=== Services ==="
	@kubectl get svc -n $(K8S_NAMESPACE) 2>/dev/null || true
	@echo ""
	@echo "=== Deployments ==="
	@kubectl get deployments -n $(K8S_NAMESPACE) 2>/dev/null || true
	@echo ""
	@echo "=== HPA ==="
	@kubectl get hpa -n $(K8S_NAMESPACE) 2>/dev/null || true

k8s-logs: ## Tail logs from K8s pods
	@kubectl logs -n $(K8S_NAMESPACE) -l app.kubernetes.io/name=platform-api --tail=50 -f

k8s-clean: ## Remove all K8s resources
	@kubectl delete namespace platform-api platform-api-dev platform-api-staging 2>/dev/null || true
	@echo "Kubernetes resources cleaned."

# ── Helm ─────────────────────────────────────────────────────────────────────
helm-deploy: build ## Deploy with Helm (dev)
	@bash scripts/k8s-deploy.sh --helm dev

helm-template: ## Render Helm templates locally
	@helm template platform-api ./helm/platform-api

helm-lint: ## Lint Helm chart
	@helm lint ./helm/platform-api

# ── Clean ────────────────────────────────────────────────────────────────────
clean: ## Remove containers, images, and build artifacts
	@$(DOCKER_COMPOSE) down --rmi local --volumes --remove-orphans 2>/dev/null || true
	@docker rmi $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest 2>/dev/null || true
	@echo "Cleaned up."

# ── All ──────────────────────────────────────────────────────────────────────
all: build scan smoke ## Build, scan, and test everything
