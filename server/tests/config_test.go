package tests

import (
	"testing"

	"github.com/ducdo/sprinty/server/config"
)

func TestConfigFailsFastOnMissingJWTSecret(t *testing.T) {
	t.Setenv("JWT_SECRET", "")
	t.Setenv("ENVIRONMENT", "")

	_, err := config.Load()
	if err == nil {
		t.Error("expected error when JWT_SECRET is missing")
	}
}

func TestConfigFailsFastOnMissingEnvironment(t *testing.T) {
	t.Setenv("JWT_SECRET", "test-secret-key-at-least-32-chars-long")
	t.Setenv("ENVIRONMENT", "")

	_, err := config.Load()
	if err == nil {
		t.Error("expected error when ENVIRONMENT is missing")
	}
}

func TestConfigLoadsSuccessfully(t *testing.T) {
	t.Setenv("JWT_SECRET", "test-secret-key-at-least-32-chars-long")
	t.Setenv("ENVIRONMENT", "dev")
	t.Setenv("PORT", "9090")

	cfg, err := config.Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cfg.JWTSecret != "test-secret-key-at-least-32-chars-long" {
		t.Errorf("unexpected JWT secret: %q", cfg.JWTSecret)
	}
	if cfg.Environment != "dev" {
		t.Errorf("unexpected environment: %q", cfg.Environment)
	}
	if cfg.Port != "9090" {
		t.Errorf("unexpected port: %q", cfg.Port)
	}
}

func TestConfigDefaultPort(t *testing.T) {
	t.Setenv("JWT_SECRET", "test-secret-key-at-least-32-chars-long")
	t.Setenv("ENVIRONMENT", "dev")
	t.Setenv("PORT", "")

	cfg, err := config.Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cfg.Port != "8080" {
		t.Errorf("expected default port 8080, got %q", cfg.Port)
	}
}

func TestConfigInvalidEnvironment(t *testing.T) {
	t.Setenv("JWT_SECRET", "test-secret-key-at-least-32-chars-long")
	t.Setenv("ENVIRONMENT", "invalid")

	_, err := config.Load()
	if err == nil {
		t.Error("expected error for invalid ENVIRONMENT value")
	}
}
