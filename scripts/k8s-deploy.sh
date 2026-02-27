#!/usr/bin/env bash
# ============================================================================
# Deploy Script — Deploy platform-api to Kubernetes
# ============================================================================
# Usage:
#   ./scripts/k8s-deploy.sh [dev|staging|production]
#   ./scripts/k8s-deploy.sh --helm [dev|staging|production]
#
# Supports both Kustomize and Helm deployments.
# ============================================================================

set -euo pipefail

ENV="${1:-dev}"
USE_HELM=false
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
if [[ "${1:-}" == "--helm" ]]; then
    USE_HELM=true
    ENV="${2:-dev}"
fi

echo -e "${CYAN}"
echo "============================================"
echo "  Deploy Platform API"
echo "  Environment: ${ENV}"
echo "  Method:      $(if $USE_HELM; then echo 'Helm'; else echo 'Kustomize'; fi)"
echo "============================================"
echo -e "${NC}"

# ── Validate environment ─────────────────────────────────────────────────────
case "$ENV" in
    dev|staging|production)
        ;;
    *)
        echo -e "${RED}Error: Invalid environment '${ENV}'${NC}"
        echo "Usage: $0 [dev|staging|production]"
        exit 1
        ;;
esac

# ── Check prerequisites ──────────────────────────────────────────────────────
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found${NC}"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    echo "Make sure your kubeconfig is set and cluster is running."
    exit 1
fi

echo -e "${GREEN}✓ kubectl connected to cluster${NC}"

# ── Ensure image exists ──────────────────────────────────────────────────────
if ! docker image inspect platform-api:1.0.0 &> /dev/null; then
    echo -e "${YELLOW}Building Docker image...${NC}"
    bash scripts/build.sh platform-api 1.0.0
fi

# ── Deploy ────────────────────────────────────────────────────────────────────
if $USE_HELM; then
    # Helm deployment
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}Error: helm not found. Install: brew install helm${NC}"
        exit 1
    fi

    NAMESPACE="platform-api"
    [[ "$ENV" == "dev" ]] && NAMESPACE="platform-api-dev"
    [[ "$ENV" == "staging" ]] && NAMESPACE="platform-api-staging"

    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    VALUES_FILE=""
    if [[ -f "helm/platform-api/values-${ENV}.yaml" ]]; then
        VALUES_FILE="-f helm/platform-api/values-${ENV}.yaml"
    fi

    echo -e "${YELLOW}Deploying with Helm to namespace: ${NAMESPACE}...${NC}"
    helm upgrade --install platform-api ./helm/platform-api \
        --namespace "$NAMESPACE" \
        --set config.ENVIRONMENT="$ENV" \
        $VALUES_FILE \
        --wait --timeout 120s

else
    # Kustomize deployment
    OVERLAY_DIR="kubernetes/overlays/${ENV}"

    if [[ ! -d "$OVERLAY_DIR" ]]; then
        echo -e "${RED}Error: Overlay not found at ${OVERLAY_DIR}${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Deploying with Kustomize (${ENV})...${NC}"

    # Preview what will be applied
    echo ""
    echo -e "${CYAN}Resources to be applied:${NC}"
    kubectl kustomize "$OVERLAY_DIR" | grep "^kind:" | sort | uniq -c
    echo ""

    # Apply
    kubectl apply -k "$OVERLAY_DIR"
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Verify with:"
echo "  kubectl get all -n platform-api"
echo "  kubectl logs -n platform-api -l app.kubernetes.io/name=platform-api"
