package config

import (
	"os"
	"testing"
)

// --- Story 10.1 Tests ---

func setRequiredEnv(t *testing.T) {
	t.Helper()
	t.Setenv("JWT_SECRET", "test-secret-key-at-least-32-chars-long")
	t.Setenv("ENVIRONMENT", "dev")
	t.Setenv("ANTHROPIC_API_KEY", "sk-test")
}

func TestLoadFallbackProviderConfig(t *testing.T) {
	setRequiredEnv(t)
	t.Setenv("FREE_TIER_FALLBACK_PROVIDER", "openai")
	t.Setenv("FREE_TIER_FALLBACK_MODEL", "gpt-4.1-mini")
	t.Setenv("PREMIUM_TIER_FALLBACK_PROVIDER", "openai")
	t.Setenv("PREMIUM_TIER_FALLBACK_MODEL", "gpt-4.1")
	t.Setenv("OPENAI_API_KEY", "sk-openai-test")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if cfg.FreeTierFallbackProvider != "openai" {
		t.Errorf("expected FreeTierFallbackProvider=openai, got %q", cfg.FreeTierFallbackProvider)
	}
	if cfg.FreeTierFallbackModel != "gpt-4.1-mini" {
		t.Errorf("expected FreeTierFallbackModel=gpt-4.1-mini, got %q", cfg.FreeTierFallbackModel)
	}
	if cfg.PremiumTierFallbackProvider != "openai" {
		t.Errorf("expected PremiumTierFallbackProvider=openai, got %q", cfg.PremiumTierFallbackProvider)
	}
	if cfg.PremiumTierFallbackModel != "gpt-4.1" {
		t.Errorf("expected PremiumTierFallbackModel=gpt-4.1, got %q", cfg.PremiumTierFallbackModel)
	}
}

func TestLoadFallbackProviderDefaultsEmpty(t *testing.T) {
	setRequiredEnv(t)

	// Ensure fallback env vars are NOT set
	os.Unsetenv("FREE_TIER_FALLBACK_PROVIDER")
	os.Unsetenv("FREE_TIER_FALLBACK_MODEL")
	os.Unsetenv("PREMIUM_TIER_FALLBACK_PROVIDER")
	os.Unsetenv("PREMIUM_TIER_FALLBACK_MODEL")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if cfg.FreeTierFallbackProvider != "" {
		t.Errorf("expected empty FreeTierFallbackProvider, got %q", cfg.FreeTierFallbackProvider)
	}
	if cfg.FreeTierFallbackModel != "" {
		t.Errorf("expected empty FreeTierFallbackModel, got %q", cfg.FreeTierFallbackModel)
	}
	if cfg.PremiumTierFallbackProvider != "" {
		t.Errorf("expected empty PremiumTierFallbackProvider, got %q", cfg.PremiumTierFallbackProvider)
	}
	if cfg.PremiumTierFallbackModel != "" {
		t.Errorf("expected empty PremiumTierFallbackModel, got %q", cfg.PremiumTierFallbackModel)
	}
}
