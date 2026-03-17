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

	// Future — stubbed for later stories
	AnthropicAPIKey string
	OpenAIAPIKey    string
	SentryDSN       string
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

	cfg := &Config{
		JWTSecret:       jwtSecret,
		Environment:     env,
		Port:            port,
		AnthropicAPIKey: os.Getenv("ANTHROPIC_API_KEY"),
		OpenAIAPIKey:    os.Getenv("OPENAI_API_KEY"),
		SentryDSN:       os.Getenv("SENTRY_DSN"),
	}

	slog.Info("config loaded",
		"environment", cfg.Environment,
		"port", cfg.Port,
	)

	return cfg, nil
}
