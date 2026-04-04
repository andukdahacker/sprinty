package middleware

import (
	"context"
	"log/slog"
	"net/http"

	"github.com/ducdo/sprinty/server/providers"
)

const providerKey contextKey = "provider"
const providerChainKey contextKey = "providerChain"

// ProviderRegistry maps tier names to ordered provider chains for failover.
type ProviderRegistry struct {
	chains          map[string][]providers.Provider
	defaultProvider providers.Provider
}

// NewProviderRegistry creates a registry with a default provider used when tier is not found.
func NewProviderRegistry(defaultProvider providers.Provider) *ProviderRegistry {
	return &ProviderRegistry{
		chains:          make(map[string][]providers.Provider),
		defaultProvider: defaultProvider,
	}
}

// Register adds a single provider for a given tier (backward compat — creates a chain of one).
func (r *ProviderRegistry) Register(tier string, p providers.Provider) {
	r.chains[tier] = []providers.Provider{p}
}

// RegisterChain adds an ordered provider chain for a given tier.
func (r *ProviderRegistry) RegisterChain(tier string, chain []providers.Provider) {
	r.chains[tier] = chain
}

// Get returns the first provider for a tier, falling back to the default.
func (r *ProviderRegistry) Get(tier string) providers.Provider {
	if chain, ok := r.chains[tier]; ok && len(chain) > 0 {
		return chain[0]
	}
	return r.defaultProvider
}

// GetChain returns the full provider chain for a tier.
func (r *ProviderRegistry) GetChain(tier string) []providers.Provider {
	if chain, ok := r.chains[tier]; ok && len(chain) > 0 {
		return chain
	}
	return []providers.Provider{r.defaultProvider}
}

// ProviderFromContext retrieves the tier-selected provider (first in chain) from request context.
func ProviderFromContext(ctx context.Context) (providers.Provider, bool) {
	p, ok := ctx.Value(providerKey).(providers.Provider)
	return p, ok
}

// ProviderChainFromContext retrieves the full provider chain from request context.
func ProviderChainFromContext(ctx context.Context) ([]providers.Provider, bool) {
	chain, ok := ctx.Value(providerChainKey).([]providers.Provider)
	return chain, ok
}

// TierMiddleware reads the JWT tier claim and attaches the appropriate provider chain to the request context.
func TierMiddleware(registry *ProviderRegistry) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := ClaimsFromContext(r.Context())
			if !ok {
				// No claims = no tier info; use default (free tier)
				chain := registry.GetChain("free")
				if logFields := LogFieldsFromContext(r.Context()); logFields != nil {
					logFields.Provider = chain[0].Name()
				}
				ctx := context.WithValue(r.Context(), providerKey, chain[0])
				ctx = context.WithValue(ctx, providerChainKey, chain)
				next.ServeHTTP(w, r.WithContext(ctx))
				return
			}

			tier := claims.Tier
			if tier == "" {
				tier = "free"
			}

			chain := registry.GetChain(tier)

			slog.Debug("tier.routing", "tier", tier, "chainLen", len(chain))

			if logFields := LogFieldsFromContext(r.Context()); logFields != nil {
				logFields.Provider = chain[0].Name()
			}

			ctx := context.WithValue(r.Context(), providerKey, chain[0])
			ctx = context.WithValue(ctx, providerChainKey, chain)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
