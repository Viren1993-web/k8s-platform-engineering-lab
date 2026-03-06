# ============================================================================
# Multi-Stage Production Dockerfile for Platform API
# ============================================================================
# Stage 1: Build the Go binary with all dependencies
# Stage 2: Create a minimal, secure production image
#
# Best Practices Applied:
#   - Multi-stage build (small final image)
#   - Non-root user
#   - Distroless base image (no shell, no package manager = smaller attack surface)
#   - Build arguments for version injection
#   - Layer caching optimization
#   - Health check instruction
# ============================================================================

# ── Stage 1: Builder ─────────────────────────────────────────────────────────
FROM golang:1.26-alpine AS builder

# Install security updates and git (needed for Go modules)
RUN apk update && apk add --no-cache git ca-certificates tzdata

# Create non-root user for the final image
RUN adduser -D -g '' appuser

# Set working directory
WORKDIR /build

# Copy dependency files first (layer caching optimization)
COPY app/go.mod app/go.sum ./
RUN go mod download && go mod verify

# Copy source code
COPY app/ .

# Build arguments for version injection at build time
ARG VERSION=dev
ARG BUILD_TIME
ARG COMMIT_SHA

# Build the binary with:
#   - CGO disabled (static binary, no C dependencies)
#   - Linux target
#   - Version info injected via ldflags
#   - Stripped debug info (-s -w) for smaller binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w \
    -X main.version=${VERSION} \
    -X main.buildTime=${BUILD_TIME} \
    -X main.commitSHA=${COMMIT_SHA}" \
    -o /build/platform-api .

# ── Stage 2: Production Image ────────────────────────────────────────────────
# Using distroless for maximum security:
#   - No shell, no package manager, no OS utilities
#   - Only contains the application binary and CA certificates
#   - Dramatically reduces CVE surface
FROM gcr.io/distroless/static:nonroot

# Labels for container metadata (OCI standard)
LABEL org.opencontainers.image.title="platform-api" \
      org.opencontainers.image.description="Production-ready Kubernetes Platform API Service" \
      org.opencontainers.image.vendor="Platform Engineering" \
      org.opencontainers.image.source="https://github.com/virenpatel/k8s-platform-engineering-lab"

# Copy timezone data and CA certificates from builder
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy the binary from builder stage
COPY --from=builder /build/platform-api /platform-api

# Use non-root user (UID 65532 is the nonroot user in distroless)
USER 65532:65532

# Expose the service port
EXPOSE 9090

# Health check (Docker-level, separate from K8s probes)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD sh -c '/platform-api -health-check || exit 1'

# Run the binary
ENTRYPOINT ["/platform-api"]
