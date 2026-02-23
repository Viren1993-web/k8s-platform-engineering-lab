# ============================================================================
# Makefile — Platform API Development Commands
# ============================================================================
# Usage:
#   make help         Show this help
#   make build        Build Docker image
#   make run          Run locally with Docker
#   make test         Run Go tests
#   make lint         Lint Dockerfile
#   make scan         Security scan
#   make smoke        Run smoke tests
#   make clean        Clean up containers and images
# ============================================================================

.PHONY: help build run stop test lint scan smoke clean dev all

# ── Variables ────────────────────────────────────────────────────────────────
IMAGE_NAME    := platform-api
VERSION       := 1.0.0
COMMIT_SHA    := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TIME    := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
DOCKER_COMPOSE := docker compose -f docker/docker-compose.yml

# ── Default ──────────────────────────────────────────────────────────────────
help: ## Show this help message
	@echo ""
	@echo "Platform API — Development Commands"
	@echo "===================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ── Build ────────────────────────────────────────────────────────────────────
build: ## Build production Docker image
	@bash scripts/build.sh $(IMAGE_NAME) $(VERSION)

# ── Run ──────────────────────────────────────────────────────────────────────
run: ## Run the service with Docker Compose
	@BUILD_TIME=$(BUILD_TIME) COMMIT_SHA=$(COMMIT_SHA) $(DOCKER_COMPOSE) up --build -d
	@echo ""
	@echo "Service running at http://localhost:9090"
	@echo "  Health:  http://localhost:9090/healthz"
	@echo "  Ready:   http://localhost:9090/readyz"
	@echo "  Metrics: http://localhost:9090/metrics"
	@echo "  Info:    http://localhost:9090/api/v1/info"
	@echo "  Status:  http://localhost:9090/api/v1/status"

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

# ── Clean ────────────────────────────────────────────────────────────────────
clean: ## Remove containers, images, and build artifacts
	@$(DOCKER_COMPOSE) down --rmi local --volumes --remove-orphans 2>/dev/null || true
	@docker rmi $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest 2>/dev/null || true
	@echo "Cleaned up."

# ── All ──────────────────────────────────────────────────────────────────────
all: build scan smoke ## Build, scan, and test everything
