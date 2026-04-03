package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/anthropics/anthropic-sdk-go"
	"github.com/openai/openai-go"

	"github.com/ducdo/sprinty/server/appstore"
	"github.com/ducdo/sprinty/server/config"
	"github.com/ducdo/sprinty/server/handlers"
	"github.com/ducdo/sprinty/server/middleware"
	"github.com/ducdo/sprinty/server/prompts"
	"github.com/ducdo/sprinty/server/providers"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	cfg, err := config.Load()
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	// Build provider registry for tier-based routing
	registry := buildProviderRegistry(cfg)


	// Prompt builder
	execPath, err := os.Executable()
	if err != nil {
		slog.Error("failed to get executable path", "error", err)
		os.Exit(1)
	}
	sectionsPath := filepath.Join(filepath.Dir(execPath), "prompts", "sections")

	// Try relative to working directory if executable-relative path doesn't exist
	if _, err := os.Stat(sectionsPath); os.IsNotExist(err) {
		sectionsPath = filepath.Join("prompts", "sections")
	}

	promptBuilder, err := prompts.NewBuilder(sectionsPath)
	if err != nil {
		slog.Error("failed to initialize prompt builder", "error", err)
		os.Exit(1)
	}

	appStoreClient := appstore.NewClient(cfg.AppleKeyID, cfg.AppleIssuerID, cfg.AppleBundleID, cfg.ApplePrivateKey)
	if appStoreClient == nil {
		slog.Info("appstore client not configured — subscription validation disabled (dev mode)")
	}

	authMW := middleware.AuthMiddleware(cfg.JWTSecret)
	tierMW := middleware.TierMiddleware(registry)
	sessionTracker := middleware.NewSessionTracker()
	guardrailsMW := middleware.GuardrailsMiddleware(sessionTracker, cfg)

	mux := http.NewServeMux()

	// Public routes
	mux.HandleFunc("GET /health", handlers.HealthHandler)
	mux.HandleFunc("POST /v1/auth/register", handlers.RegisterHandler(cfg.JWTSecret, appStoreClient))
	mux.HandleFunc("GET /v1/prompt/{version}", handlers.PromptVersionHandler(promptBuilder))

	// Protected routes: logging(auth(tier(handler)))
	mux.Handle("POST /v1/auth/refresh", authMW(http.HandlerFunc(handlers.RefreshHandler(cfg.JWTSecret, appStoreClient))))
	mux.Handle("POST /v1/chat", authMW(tierMW(guardrailsMW(http.HandlerFunc(handlers.ChatHandler(promptBuilder))))))

	handler := middleware.LoggingMiddleware(mux)

	srv := &http.Server{
		Addr:    "0.0.0.0:" + cfg.Port,
		Handler: handler,
	}

	// Graceful shutdown
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer stop()

	go func() {
		slog.Info("server starting", "addr", srv.Addr, "promptVersion", promptBuilder.ContentHash())
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	slog.Info("shutdown signal received, draining connections")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Error("shutdown error", "error", err)
		os.Exit(1)
	}

	slog.Info("server stopped cleanly")
}

func buildProviderRegistry(cfg *config.Config) *middleware.ProviderRegistry {
	providerMap := make(map[string]providers.Provider)

	makeProvider := func(providerName, model string) providers.Provider {
		key := providerName + "/" + model
		if p, ok := providerMap[key]; ok {
			return p
		}

		var p providers.Provider
		switch providerName {
		case "anthropic":
			if cfg.AnthropicAPIKey == "" {
				slog.Warn("anthropic provider requested but ANTHROPIC_API_KEY not set, using mock", "model", model)
				p = providers.NewMockProvider()
			} else {
				p = providers.NewAnthropicProvider(cfg.AnthropicAPIKey, anthropic.Model(model))
				slog.Info("created anthropic provider", "model", model)
			}
		case "openai":
			if cfg.OpenAIAPIKey == "" {
				slog.Warn("openai provider requested but OPENAI_API_KEY not set, using mock", "model", model)
				p = providers.NewMockProvider()
			} else {
				p = providers.NewOpenAIProvider(cfg.OpenAIAPIKey, openai.ChatModel(model))
				slog.Info("created openai provider", "model", model)
			}
		default:
			slog.Warn("unknown provider, using mock", "provider", providerName)
			p = providers.NewMockProvider()
		}

		providerMap[key] = p
		return p
	}

	freeProvider := makeProvider(cfg.FreeTierProvider, cfg.FreeTierModel)
	premiumProvider := makeProvider(cfg.PremiumTierProvider, cfg.PremiumTierModel)

	// Build failover chains
	freeChain := []providers.Provider{freeProvider}
	if cfg.FreeTierFallbackProvider != "" && cfg.FreeTierFallbackModel != "" {
		freeChain = append(freeChain, makeProvider(cfg.FreeTierFallbackProvider, cfg.FreeTierFallbackModel))
	}

	premiumChain := []providers.Provider{premiumProvider}
	if cfg.PremiumTierFallbackProvider != "" && cfg.PremiumTierFallbackModel != "" {
		premiumChain = append(premiumChain, makeProvider(cfg.PremiumTierFallbackProvider, cfg.PremiumTierFallbackModel))
	}

	registry := middleware.NewProviderRegistry(freeProvider)
	registry.RegisterChain("free", freeChain)
	registry.RegisterChain("premium", premiumChain)

	return registry
}
