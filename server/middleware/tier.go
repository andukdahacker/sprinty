package middleware

import (
	"context"
	"log/slog"
	"net/http"

	"github.com/ducdo/sprinty/server/providers"
)

const providerKey contextKey = "provider"

// ProviderRegistry maps tier names to Provider instances.
type ProviderRegistry struct {
	providers map[string]providers.Provider
	fallback  providers.Provider
}

// NewProviderRegistry creates a registry with a fallback provider.
func NewProviderRegistry(fallback providers.Provider) *ProviderRegistry {
	return &ProviderRegistry{
		providers: make(map[string]providers.Provider),
		fallback:  fallback,
	}
}

// Register adds a provider for a given tier.
func (r *ProviderRegistry) Register(tier string, p providers.Provider) {
	r.providers[tier] = p
}

// Get returns the provider for a tier, falling back to the default.
func (r *ProviderRegistry) Get(tier string) providers.Provider {
	if p, ok := r.providers[tier]; ok {
		return p
	}
	return r.fallback
}

// ProviderFromContext retrieves the tier-selected provider from request context.
func ProviderFromContext(ctx context.Context) (providers.Provider, bool) {
	p, ok := ctx.Value(providerKey).(providers.Provider)
	return p, ok
}

// TierMiddleware reads the JWT tier claim and attaches the appropriate provider to the request context.
func TierMiddleware(registry *ProviderRegistry) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := ClaimsFromContext(r.Context())
			if !ok {
				// No claims = no tier info; use fallback (free tier)
				ctx := context.WithValue(r.Context(), providerKey, registry.fallback)
				next.ServeHTTP(w, r.WithContext(ctx))
				return
			}

			tier := claims.Tier
			if tier == "" {
				tier = "free"
			}

			provider := registry.Get(tier)

			slog.Debug("tier.routing", "tier", tier)

			ctx := context.WithValue(r.Context(), providerKey, provider)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
