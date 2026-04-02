package config

import (
	"fmt"
	"log/slog"
	"os"
)

type Config struct {
	JWTSecret   string
	Environment string
	Port        string

	AnthropicAPIKey string
	OpenAIAPIKey    string
	SentryDSN       string

	// Apple App Store Server API credentials (optional in dev, required in staging/production)
	AppleKeyID      string
	AppleIssuerID   string
	AppleBundleID   string
	ApplePrivateKey string
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

	cfg := &Config{
		JWTSecret:       jwtSecret,
		Environment:     env,
		Port:            port,
		AnthropicAPIKey: anthropicKey,
		OpenAIAPIKey:    os.Getenv("OPENAI_API_KEY"),
		SentryDSN:       os.Getenv("SENTRY_DSN"),
		AppleKeyID:      appleKeyID,
		AppleIssuerID:   appleIssuerID,
		AppleBundleID:   appleBundleID,
		ApplePrivateKey: applePrivateKey,
	}

	slog.Info("config loaded",
		"environment", cfg.Environment,
		"port", cfg.Port,
		"hasAnthropicKey", cfg.AnthropicAPIKey != "",
	)

	return cfg, nil
}
