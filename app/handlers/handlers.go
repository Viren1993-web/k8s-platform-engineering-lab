// Package handlers provides HTTP handlers for the platform API.
package handlers

import (
	"encoding/json"
	"net/http"
	"runtime"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/virenpatel/k8s-platform-engineering-lab/app/config"

	"go.uber.org/zap"
)

// HealthHandler manages Kubernetes health and readiness probes.
type HealthHandler struct {
	logger    *zap.Logger
	cfg       *config.Config
	ready     atomic.Bool
	startTime time.Time
}

// NewHealthHandler creates a new health handler, marking the service as ready.
func NewHealthHandler(logger *zap.Logger, cfg *config.Config) *HealthHandler {
	h := &HealthHandler{
		logger:    logger,
		cfg:       cfg,
		startTime: time.Now(),
	}
	h.ready.Store(true)
	return h
}

// SetNotReady marks the service as not ready (used during graceful shutdown).
func (h *HealthHandler) SetNotReady() {
	h.ready.Store(false)
	h.logger.Info("service marked as not ready")
}

// livenessResponse is the JSON response for the liveness probe.
type livenessResponse struct {
	Status    string `json:"status"`
	Timestamp string `json:"timestamp"`
}

// Liveness handles the /healthz endpoint.
// Kubernetes uses this to determine if the container needs to be restarted.
func (h *HealthHandler) Liveness(w http.ResponseWriter, r *http.Request) {
	resp := livenessResponse{
		Status:    "alive",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(resp)
}

// readinessResponse is the JSON response for the readiness probe.
type readinessResponse struct {
	Status    string  `json:"status"`
	Uptime    string  `json:"uptime"`
	Timestamp string  `json:"timestamp"`
	Checks    []check `json:"checks"`
}

type check struct {
	Name   string `json:"name"`
	Status string `json:"status"`
}

// Readiness handles the /readyz endpoint.
// Kubernetes uses this to determine if the pod should receive traffic.
func (h *HealthHandler) Readiness(w http.ResponseWriter, r *http.Request) {
	isReady := h.ready.Load()

	status := "ready"
	httpStatus := http.StatusOK
	if !isReady {
		status = "not_ready"
		httpStatus = http.StatusServiceUnavailable
	}

	resp := readinessResponse{
		Status:    status,
		Uptime:    time.Since(h.startTime).Round(time.Second).String(),
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Checks: []check{
			{Name: "server", Status: boolToStatus(isReady)},
		},
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(httpStatus)
	json.NewEncoder(w).Encode(resp)
}

func boolToStatus(b bool) string {
	if b {
		return "pass"
	}
	return "fail"
}

// ────────────────────────────────────────────────────────────────────────────

// APIHandler provides application endpoints.
type APIHandler struct {
	logger    *zap.Logger
	cfg       *config.Config
	startTime time.Time
}

// NewAPIHandler creates a new API handler.
func NewAPIHandler(logger *zap.Logger, cfg *config.Config) *APIHandler {
	return &APIHandler{
		logger:    logger,
		cfg:       cfg,
		startTime: time.Now(),
	}
}

// infoResponse is the response for the /api/v1/info endpoint.
type infoResponse struct {
	Service     string `json:"service"`
	Version     string `json:"version"`
	Environment string `json:"environment"`
	GoVersion   string `json:"go_version"`
	OS          string `json:"os"`
	Arch        string `json:"arch"`
}

// Info returns service metadata.
func (a *APIHandler) Info(w http.ResponseWriter, r *http.Request) {
	resp := infoResponse{
		Service:     a.cfg.ServiceName,
		Version:     a.cfg.Version,
		Environment: a.cfg.Environment,
		GoVersion:   runtime.Version(),
		OS:          runtime.GOOS,
		Arch:        runtime.GOARCH,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(resp)
}

// statusResponse is the response for the /api/v1/status endpoint.
type statusResponse struct {
	Status      string `json:"status"`
	Uptime      string `json:"uptime"`
	Goroutines  int    `json:"goroutines"`
	MemoryAlloc string `json:"memory_alloc_mb"`
	Timestamp   string `json:"timestamp"`
}

// Status returns runtime status of the service.
func (a *APIHandler) Status(w http.ResponseWriter, r *http.Request) {
	var memStats runtime.MemStats
	runtime.ReadMemStats(&memStats)

	resp := statusResponse{
		Status:      "operational",
		Uptime:      time.Since(a.startTime).Round(time.Second).String(),
		Goroutines:  runtime.NumGoroutine(),
		MemoryAlloc: formatBytes(memStats.Alloc),
		Timestamp:   time.Now().UTC().Format(time.RFC3339),
	}

	a.logger.Debug("status check",
		zap.Int("goroutines", resp.Goroutines),
		zap.String("memory", resp.MemoryAlloc),
	)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(resp)
}

func formatBytes(b uint64) string {
	const mb = 1024 * 1024
	return strconv.FormatFloat(float64(b)/float64(mb), 'f', 2, 64)
}
