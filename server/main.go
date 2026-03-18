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

	// Provider selection: real Anthropic if API key set, mock otherwise
	var provider providers.Provider
	if cfg.AnthropicAPIKey != "" {
		provider = providers.NewAnthropicProvider(cfg.AnthropicAPIKey)
		slog.Info("using Anthropic provider")
	} else {
		provider = providers.NewMockProvider()
		slog.Info("using mock provider (no ANTHROPIC_API_KEY set)")
	}

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

	authMW := middleware.AuthMiddleware(cfg.JWTSecret)

	mux := http.NewServeMux()

	// Public routes
	mux.HandleFunc("GET /health", handlers.HealthHandler)
	mux.HandleFunc("POST /v1/auth/register", handlers.RegisterHandler(cfg.JWTSecret))
	mux.HandleFunc("GET /v1/prompt/{version}", handlers.PromptVersionHandler(promptBuilder))

	// Protected routes
	mux.Handle("POST /v1/auth/refresh", authMW(http.HandlerFunc(handlers.RefreshHandler(cfg.JWTSecret))))
	mux.Handle("POST /v1/chat", authMW(http.HandlerFunc(handlers.ChatHandler(provider, promptBuilder))))

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
