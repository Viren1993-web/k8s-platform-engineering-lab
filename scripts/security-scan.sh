#!/usr/bin/env bash
# ============================================================================
# Security Scan Script
# ============================================================================
# Runs multiple security scans against the Docker image:
#   1. Trivy      — CVE vulnerability scanning
#   2. Hadolint   — Dockerfile best practices linting
#   3. Dockle     — Container image linting (CIS benchmarks)
#
# Usage:
#   ./scripts/security-scan.sh [IMAGE_NAME]
#
# Prerequisites:
#   brew install trivy hadolint dockle   (macOS)
# ============================================================================

set -euo pipefail

IMAGE_NAME="${1:-platform-api:latest}"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================"
echo "  Security Scan: ${IMAGE_NAME}"
echo "============================================"
echo ""

# ── 1. Dockerfile Linting with Hadolint ──────────────────────────────────────
echo -e "${YELLOW}[1/3] Hadolint — Dockerfile Best Practices${NC}"
echo "--------------------------------------------"
if command -v hadolint &> /dev/null; then
    hadolint docker/Dockerfile \
        --ignore DL3018 \
        --format tty && \
        echo -e "${GREEN}✓ Hadolint passed${NC}" || \
        echo -e "${RED}✗ Hadolint found issues${NC}"
else
    echo -e "${YELLOW}⚠ hadolint not installed. Install: brew install hadolint${NC}"
fi
echo ""

# ── 2. Vulnerability Scanning with Trivy ─────────────────────────────────────
echo -e "${YELLOW}[2/3] Trivy — CVE Vulnerability Scan${NC}"
echo "--------------------------------------------"
if command -v trivy &> /dev/null; then
    trivy image \
        --severity HIGH,CRITICAL \
        --exit-code 0 \
        --format table \
        "${IMAGE_NAME}" && \
        echo -e "${GREEN}✓ Trivy scan complete${NC}" || \
        echo -e "${RED}✗ Trivy found vulnerabilities${NC}"
else
    echo -e "${YELLOW}⚠ trivy not installed. Install: brew install trivy${NC}"
fi
echo ""

# ── 3. Container Image Linting with Dockle ───────────────────────────────────
echo -e "${YELLOW}[3/3] Dockle — CIS Benchmark Check${NC}"
echo "--------------------------------------------"
if command -v dockle &> /dev/null; then
    dockle \
        --exit-code 0 \
        "${IMAGE_NAME}" && \
        echo -e "${GREEN}✓ Dockle passed${NC}" || \
        echo -e "${RED}✗ Dockle found issues${NC}"
else
    echo -e "${YELLOW}⚠ dockle not installed. Install: brew install goodwithtech/r/dockle${NC}"
fi
echo ""

echo "============================================"
echo "  Security Scan Complete"
echo "============================================"
