// Package main is the entrypoint for the platform API service.
// This is a production-grade microservice designed for Kubernetes deployment.
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/virenpatel/k8s-platform-engineering-lab/app/config"
	"github.com/virenpatel/k8s-platform-engineering-lab/app/handlers"
	"github.com/virenpatel/k8s-platform-engineering-lab/app/middleware"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.uber.org/zap"
)

func main() {
	// ─── Load Configuration ──────────────────────────────────────────
	cfg := config.Load()

	// ─── Initialize Structured Logger ────────────────────────────────
	logger := middleware.NewLogger(cfg.LogLevel, cfg.Environment)
	defer logger.Sync()

	logger.Info("starting platform API service",
		zap.String("version", cfg.Version),
		zap.String("environment", cfg.Environment),
		zap.Int("port", cfg.Port),
	)

	// ─── Initialize Handlers ─────────────────────────────────────────
	healthHandler := handlers.NewHealthHandler(logger, cfg)
	apiHandler := handlers.NewAPIHandler(logger, cfg)

	// ─── Configure Routes ────────────────────────────────────────────
	mux := http.NewServeMux()

	// Health & readiness probes (Kubernetes)
	mux.HandleFunc("/healthz", healthHandler.Liveness)
	mux.HandleFunc("/readyz", healthHandler.Readiness)

	// Prometheus metrics endpoint
	mux.Handle("/metrics", promhttp.Handler())

	// Root endpoint (optional catch-all for testing)
	mux.HandleFunc("/", apiHandler.Info)

	// Application API routes
	mux.HandleFunc("/api/v1/info", apiHandler.Info)
	mux.HandleFunc("/api/v1/status", apiHandler.Status)

	// ─── Apply Middleware ────────────────────────────────────────────
	handler := middleware.RequestID(
		middleware.Logging(logger,
			middleware.Recovery(logger,
				middleware.CORS(mux),
			),
		),
	)

	// ─── Create Server ───────────────────────────────────────────────
	server := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Port),
		Handler:      handler,
		ReadTimeout:  cfg.ReadTimeout,
		WriteTimeout: cfg.WriteTimeout,
		IdleTimeout:  cfg.IdleTimeout,
	}

	// ─── Start Server (non-blocking) ─────────────────────────────────
	go func() {
		logger.Info("server listening", zap.String("addr", server.Addr))
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("server failed to start", zap.Error(err))
		}
	}()

	// ─── Graceful Shutdown ───────────────────────────────────────────
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	sig := <-quit

	logger.Info("received shutdown signal", zap.String("signal", sig.String()))

	ctx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()

	// Mark service as not ready (Kubernetes will stop sending traffic)
	healthHandler.SetNotReady()

	// Allow in-flight requests to drain
	logger.Info("draining connections", zap.Duration("timeout", cfg.ShutdownTimeout))

	if err := server.Shutdown(ctx); err != nil {
		logger.Error("forced shutdown", zap.Error(err))
	}

	logger.Info("server stopped gracefully")
}
