#!/usr/bin/env bash
# ============================================================================
# Build Script — Builds the Docker image with metadata
# ============================================================================

set -euo pipefail

IMAGE_NAME="${1:-platform-api}"
VERSION="${2:-1.0.0}"
COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "============================================"
echo "  Building: ${IMAGE_NAME}:${VERSION}"
echo "  Commit:   ${COMMIT_SHA}"
echo "  Time:     ${BUILD_TIME}"
echo "============================================"

docker build \
    -f docker/Dockerfile \
    --build-arg VERSION="${VERSION}" \
    --build-arg BUILD_TIME="${BUILD_TIME}" \
    --build-arg COMMIT_SHA="${COMMIT_SHA}" \
    -t "${IMAGE_NAME}:${VERSION}" \
    -t "${IMAGE_NAME}:latest" \
    .

echo ""
echo "============================================"
echo "  Build Complete"
echo "============================================"
echo ""
echo "Image size:"
docker images "${IMAGE_NAME}:${VERSION}" --format "  {{.Repository}}:{{.Tag}} → {{.Size}}"
echo ""
echo "Run with:"
echo "  docker run -p 9090:9090 ${IMAGE_NAME}:${VERSION}"
