#!/usr/bin/env bash
# ============================================================================
# Validate Script — Verify Kubernetes deployment is healthy
# ============================================================================
# Usage:
#   ./scripts/k8s-validate.sh [namespace]
#
# Checks:
#   1. All pods are running and ready
#   2. Deployment rollout is complete
#   3. Service endpoints are populated
#   4. Health endpoints respond correctly
# ============================================================================

set -euo pipefail

NAMESPACE="${1:-platform-api}"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
PASS=0
FAIL=0

check() {
    local name="$1"
    local result="$2"

    if [[ "$result" == "true" ]]; then
        echo -e "  ${GREEN}✓${NC} ${name}"
        ((PASS++))
    else
        echo -e "  ${RED}✗${NC} ${name}"
        ((FAIL++))
    fi
}

echo ""
echo "============================================"
echo "  Kubernetes Validation: ${NAMESPACE}"
echo "============================================"
echo ""

# ── 1. Namespace exists ───────────────────────────────────────────────────────
echo -e "${YELLOW}[1/6] Namespace${NC}"
NS_EXISTS=$(kubectl get namespace "$NAMESPACE" -o name 2>/dev/null && echo "true" || echo "false")
check "Namespace '${NAMESPACE}' exists" "$NS_EXISTS"

if [[ "$NS_EXISTS" == "false" ]]; then
    echo -e "\n${RED}Namespace not found. Cannot continue.${NC}"
    exit 1
fi

# ── 2. Deployment status ─────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[2/6] Deployment${NC}"
DEPLOY_COUNT=$(kubectl get deployments -n "$NAMESPACE" -l app.kubernetes.io/name=platform-api -o name 2>/dev/null | wc -l | tr -d ' ')
check "Deployment exists" "$([[ $DEPLOY_COUNT -gt 0 ]] && echo true || echo false)"

if [[ $DEPLOY_COUNT -gt 0 ]]; then
    DEPLOY_NAME=$(kubectl get deployments -n "$NAMESPACE" -l app.kubernetes.io/name=platform-api -o jsonpath='{.items[0].metadata.name}')
    AVAILABLE=$(kubectl get deployment "$DEPLOY_NAME" -n "$NAMESPACE" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
    DESIRED=$(kubectl get deployment "$DEPLOY_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    check "All replicas available (${AVAILABLE}/${DESIRED})" "$([[ "$AVAILABLE" == "$DESIRED" ]] && echo true || echo false)"
fi

# ── 3. Pods ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[3/6] Pods${NC}"
RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=platform-api --field-selector=status.phase=Running -o name 2>/dev/null | wc -l | tr -d ' ')
TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=platform-api -o name 2>/dev/null | wc -l | tr -d ' ')
check "All pods running (${RUNNING_PODS}/${TOTAL_PODS})" "$([[ "$RUNNING_PODS" -gt 0 && "$RUNNING_PODS" == "$TOTAL_PODS" ]] && echo true || echo false)"

# Check if pods are ready (all containers ready)
READY_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=platform-api -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -c "True" || echo "0")
check "All pods ready (${READY_PODS}/${TOTAL_PODS})" "$([[ "$READY_PODS" == "$TOTAL_PODS" && "$READY_PODS" -gt 0 ]] && echo true || echo false)"

# ── 4. Service ────────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[4/6] Service${NC}"
SVC_COUNT=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=platform-api -o name 2>/dev/null | wc -l | tr -d ' ')
check "Service exists" "$([[ $SVC_COUNT -gt 0 ]] && echo true || echo false)"

if [[ $SVC_COUNT -gt 0 ]]; then
    ENDPOINT_COUNT=$(kubectl get endpoints -n "$NAMESPACE" -l app.kubernetes.io/name=platform-api -o jsonpath='{.items[0].subsets[0].addresses}' 2>/dev/null | grep -c "ip" || echo "0")
    check "Service has endpoints (${ENDPOINT_COUNT})" "$([[ $ENDPOINT_COUNT -gt 0 ]] && echo true || echo false)"
fi

# ── 5. ConfigMap & Secret ────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[5/6] Configuration${NC}"
CM_COUNT=$(kubectl get configmaps -n "$NAMESPACE" -l app.kubernetes.io/name=platform-api -o name 2>/dev/null | wc -l | tr -d ' ')
check "ConfigMap exists" "$([[ $CM_COUNT -gt 0 ]] && echo true || echo false)"

# ── 6. Port-forward and test endpoints ────────────────────────────────────────
echo ""
echo -e "${YELLOW}[6/6] Endpoint Health Check${NC}"

# Find a running pod
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=platform-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$POD_NAME" ]]; then
    # Start port-forward in background
    LOCAL_PORT=18080
    kubectl port-forward -n "$NAMESPACE" "pod/${POD_NAME}" ${LOCAL_PORT}:8080 &>/dev/null &
    PF_PID=$!
    sleep 2

    # Test endpoints
    for endpoint in /healthz /readyz /api/v1/info /api/v1/status /metrics; do
        CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${LOCAL_PORT}${endpoint}" 2>/dev/null || echo "000")
        check "GET ${endpoint} → HTTP ${CODE}" "$([[ "$CODE" == "200" ]] && echo true || echo false)"
    done

    # Cleanup port-forward
    kill $PF_PID 2>/dev/null || true
    wait $PF_PID 2>/dev/null || true
else
    echo -e "  ${RED}✗ No running pod found for health check${NC}"
    ((FAIL++))
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "============================================"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
