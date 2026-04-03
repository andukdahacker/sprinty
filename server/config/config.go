package config

import (
	"fmt"
	"log/slog"
	"os"
	"strconv"
)

type Config struct {
	JWTSecret   string
	Environment string
	Port        string

	AnthropicAPIKey string
	OpenAIAPIKey    string
	SentryDSN       string

	// Tier-based model routing
	FreeTierProvider    string
	FreeTierModel       string
	PremiumTierProvider string
	PremiumTierModel    string

	// Failover providers (optional — if set, used as fallback when primary fails)
	FreeTierFallbackProvider    string
	FreeTierFallbackModel       string
	PremiumTierFallbackProvider string
	PremiumTierFallbackModel    string

	// Apple App Store Server API credentials (optional in dev, required in staging/production)
	AppleKeyID      string
	AppleIssuerID   string
	AppleBundleID   string
	ApplePrivateKey string

	// Soft guardrail daily session limits
	FreeTierDailySessionLimit    int
	PremiumTierDailySessionLimit int
}

func Load() (*Config, error) {
	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		return nil, fmt.Errorf("config: JWT_SECRET is required")
	}

	env := os.Getenv("ENVIRONMENT")
	if env == "" {
		return nil, fmt.Errorf("config: ENVIRONMENT is required (dev|staging|production)")
	}
	if env != "dev" && env != "staging" && env != "production" {
		return nil, fmt.Errorf("config: ENVIRONMENT must be dev, staging, or production, got %q", env)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	anthropicKey := os.Getenv("ANTHROPIC_API_KEY")
	if anthropicKey == "" && (env == "staging" || env == "production") {
		return nil, fmt.Errorf("config: ANTHROPIC_API_KEY is required in %s environment", env)
	}

	appleKeyID := os.Getenv("APPLE_KEY_ID")
	appleIssuerID := os.Getenv("APPLE_ISSUER_ID")
	appleBundleID := os.Getenv("APPLE_BUNDLE_ID")
	applePrivateKey := os.Getenv("APPLE_PRIVATE_KEY")

	if (env == "staging" || env == "production") && (appleKeyID == "" || appleIssuerID == "" || appleBundleID == "" || applePrivateKey == "") {
		slog.Warn("Apple App Store credentials not fully configured — subscription validation will be disabled",
			"environment", env,
			"hasKeyID", appleKeyID != "",
			"hasIssuerID", appleIssuerID != "",
			"hasBundleID", appleBundleID != "",
			"hasPrivateKey", applePrivateKey != "",
		)
	}

	// Tier-based model routing with sensible defaults
	freeTierProvider := os.Getenv("FREE_TIER_PROVIDER")
	if freeTierProvider == "" {
		freeTierProvider = "anthropic"
	}
	freeTierModel := os.Getenv("FREE_TIER_MODEL")
	if freeTierModel == "" {
		freeTierModel = "claude-haiku-4-5-20251001"
	}
	premiumTierProvider := os.Getenv("PREMIUM_TIER_PROVIDER")
	if premiumTierProvider == "" {
		premiumTierProvider = "anthropic"
	}
	premiumTierModel := os.Getenv("PREMIUM_TIER_MODEL")
	if premiumTierModel == "" {
		premiumTierModel = "claude-sonnet-4-6-20250514"
	}

	// Failover provider configuration (optional)
	freeTierFallbackProvider := os.Getenv("FREE_TIER_FALLBACK_PROVIDER")
	freeTierFallbackModel := os.Getenv("FREE_TIER_FALLBACK_MODEL")
	premiumTierFallbackProvider := os.Getenv("PREMIUM_TIER_FALLBACK_PROVIDER")
	premiumTierFallbackModel := os.Getenv("PREMIUM_TIER_FALLBACK_MODEL")

	openaiKey := os.Getenv("OPENAI_API_KEY")

	// Validate: warn if OpenAI configured as tier provider but key is missing
	if openaiKey == "" {
		if freeTierProvider == "openai" {
			slog.Warn("FREE_TIER_PROVIDER is 'openai' but OPENAI_API_KEY is not set")
		}
		if premiumTierProvider == "openai" {
			slog.Warn("PREMIUM_TIER_PROVIDER is 'openai' but OPENAI_API_KEY is not set")
		}
		if freeTierFallbackProvider == "openai" {
			slog.Warn("FREE_TIER_FALLBACK_PROVIDER is 'openai' but OPENAI_API_KEY is not set")
		}
		if premiumTierFallbackProvider == "openai" {
			slog.Warn("PREMIUM_TIER_FALLBACK_PROVIDER is 'openai' but OPENAI_API_KEY is not set")
		}
	}

	// Validate: at least one provider API key must be configured (non-dev)
	if (env == "staging" || env == "production") && anthropicKey == "" && openaiKey == "" {
		return nil, fmt.Errorf("config: at least one provider API key (ANTHROPIC_API_KEY or OPENAI_API_KEY) is required in %s environment", env)
	}

	// Soft guardrail daily session limits
	freeTierDailySessionLimit := 5
	if v := os.Getenv("FREE_TIER_DAILY_SESSION_LIMIT"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			freeTierDailySessionLimit = n
		}
	}
	premiumTierDailySessionLimit := 0
	if v := os.Getenv("PREMIUM_TIER_DAILY_SESSION_LIMIT"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			premiumTierDailySessionLimit = n
		}
	}

	cfg := &Config{
		JWTSecret:                    jwtSecret,
		Environment:                  env,
		Port:                         port,
		AnthropicAPIKey:              anthropicKey,
		OpenAIAPIKey:                 openaiKey,
		SentryDSN:                    os.Getenv("SENTRY_DSN"),
		FreeTierProvider:             freeTierProvider,
		FreeTierModel:                freeTierModel,
		PremiumTierProvider:          premiumTierProvider,
		PremiumTierModel:             premiumTierModel,
		FreeTierFallbackProvider:     freeTierFallbackProvider,
		FreeTierFallbackModel:        freeTierFallbackModel,
		PremiumTierFallbackProvider:  premiumTierFallbackProvider,
		PremiumTierFallbackModel:     premiumTierFallbackModel,
		AppleKeyID:                   appleKeyID,
		AppleIssuerID:                appleIssuerID,
		AppleBundleID:                appleBundleID,
		ApplePrivateKey:              applePrivateKey,
		FreeTierDailySessionLimit:    freeTierDailySessionLimit,
		PremiumTierDailySessionLimit: premiumTierDailySessionLimit,
	}

	logArgs := []any{
		"environment", cfg.Environment,
		"port", cfg.Port,
		"hasAnthropicKey", cfg.AnthropicAPIKey != "",
		"hasOpenAIKey", cfg.OpenAIAPIKey != "",
		"freeTier", cfg.FreeTierProvider + "/" + cfg.FreeTierModel,
		"premiumTier", cfg.PremiumTierProvider + "/" + cfg.PremiumTierModel,
	}
	if cfg.FreeTierFallbackProvider != "" {
		logArgs = append(logArgs, "freeTierFallback", cfg.FreeTierFallbackProvider+"/"+cfg.FreeTierFallbackModel)
	}
	if cfg.PremiumTierFallbackProvider != "" {
		logArgs = append(logArgs, "premiumTierFallback", cfg.PremiumTierFallbackProvider+"/"+cfg.PremiumTierFallbackModel)
	}
	slog.Info("config loaded", logArgs...)

	return cfg, nil
}
