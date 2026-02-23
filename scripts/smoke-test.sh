#!/usr/bin/env bash
# ============================================================================
# Smoke Test — Validates the running container is healthy
# ============================================================================

set -euo pipefail

BASE_URL="${1:-http://localhost:9090}"
PASS=0
FAIL=0

check() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"

    actual_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

    if [[ "$actual_code" == "$expected_code" ]]; then
        echo "  ✓ ${name} (HTTP ${actual_code})"
        ((PASS++))
    else
        echo "  ✗ ${name} — expected ${expected_code}, got ${actual_code}"
        ((FAIL++))
    fi
}

echo "============================================"
echo "  Smoke Tests: ${BASE_URL}"
echo "============================================"
echo ""

check "Liveness probe"   "${BASE_URL}/healthz"
check "Readiness probe"  "${BASE_URL}/readyz"
check "Metrics endpoint" "${BASE_URL}/metrics"
check "Service info"     "${BASE_URL}/api/v1/info"
check "Service status"   "${BASE_URL}/api/v1/status"

echo ""
echo "============================================"
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "============================================"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
