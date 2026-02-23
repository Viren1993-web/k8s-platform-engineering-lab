// Package config provides typed, validated configuration loaded from environment variables.
// All production services should be configurable via environment variables (12-factor app).
package config

import (
	"os"
	"strconv"
	"time"
)

// Config holds all service configuration.
type Config struct {
	// Service metadata
	ServiceName string
	Version     string
	Environment string

	// Server settings
	Port         int
	ReadTimeout  time.Duration
	WriteTimeout time.Duration
	IdleTimeout  time.Duration

	// Graceful shutdown
	ShutdownTimeout time.Duration

	// Logging
	LogLevel string
}

// Load reads configuration from environment variables with sensible production defaults.
func Load() *Config {
	return &Config{
		ServiceName: getEnv("SERVICE_NAME", "platform-api"),
		Version:     getEnv("SERVICE_VERSION", "1.0.0"),
		Environment: getEnv("ENVIRONMENT", "development"),

		Port:         getEnvInt("PORT", 9090),
		ReadTimeout:  getEnvDuration("READ_TIMEOUT", 5*time.Second),
		WriteTimeout: getEnvDuration("WRITE_TIMEOUT", 10*time.Second),
		IdleTimeout:  getEnvDuration("IDLE_TIMEOUT", 120*time.Second),

		ShutdownTimeout: getEnvDuration("SHUTDOWN_TIMEOUT", 30*time.Second),

		LogLevel: getEnv("LOG_LEVEL", "info"),
	}
}

// getEnv retrieves an environment variable or returns a default value.
func getEnv(key, defaultValue string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultValue
}

// getEnvInt retrieves an integer environment variable or returns a default value.
func getEnvInt(key string, defaultValue int) int {
	if value, exists := os.LookupEnv(key); exists {
		if intVal, err := strconv.Atoi(value); err == nil {
			return intVal
		}
	}
	return defaultValue
}

// getEnvDuration retrieves a duration environment variable or returns a default value.
func getEnvDuration(key string, defaultValue time.Duration) time.Duration {
	if value, exists := os.LookupEnv(key); exists {
		if duration, err := time.ParseDuration(value); err == nil {
			return duration
		}
	}
	return defaultValue
}
