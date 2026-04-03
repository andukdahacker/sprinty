package middleware

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/ducdo/sprinty/server/auth"
	"github.com/ducdo/sprinty/server/providers"
)

type namedMockProvider struct {
	name string
}

func (p *namedMockProvider) Name() string {
	return p.name
}

func (p *namedMockProvider) StreamChat(ctx context.Context, req providers.ChatRequest) (<-chan providers.ChatEvent, error) {
	ch := make(chan providers.ChatEvent)
	close(ch)
	return ch, nil
}

func TestTierMiddlewareFreeRouting(t *testing.T) {
	freeProvider := &namedMockProvider{name: "free"}
	premiumProvider := &namedMockProvider{name: "premium"}

	registry := NewProviderRegistry(freeProvider)
	registry.Register("free", freeProvider)
	registry.Register("premium", premiumProvider)
	tierMW := TierMiddleware(registry)

	var gotProvider providers.Provider
	handler := tierMW(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		p, ok := ProviderFromContext(r.Context())
		if !ok {
			t.Fatal("expected provider in context")
		}
		gotProvider = p
		w.WriteHeader(http.StatusOK)
	}))

	// Set up context with free tier claims
	claims := &auth.Claims{DeviceID: "test-device", Tier: "free"}
	ctx := context.WithValue(context.Background(), claimsKey, claims)

	req := httptest.NewRequest("GET", "/", nil).WithContext(ctx)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if gotProvider != freeProvider {
		t.Error("expected free tier provider")
	}
}

func TestTierMiddlewarePremiumRouting(t *testing.T) {
	freeProvider := &namedMockProvider{name: "free"}
	premiumProvider := &namedMockProvider{name: "premium"}

	registry := NewProviderRegistry(freeProvider)
	registry.Register("free", freeProvider)
	registry.Register("premium", premiumProvider)
	tierMW := TierMiddleware(registry)

	var gotProvider providers.Provider
	handler := tierMW(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		p, _ := ProviderFromContext(r.Context())
		gotProvider = p
		w.WriteHeader(http.StatusOK)
	}))

	claims := &auth.Claims{DeviceID: "test-device", Tier: "premium"}
	ctx := context.WithValue(context.Background(), claimsKey, claims)

	req := httptest.NewRequest("GET", "/", nil).WithContext(ctx)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if gotProvider != premiumProvider {
		t.Error("expected premium tier provider")
	}
}

func TestTierMiddlewareMissingTierDefaultsToFree(t *testing.T) {
	freeProvider := &namedMockProvider{name: "free"}
	premiumProvider := &namedMockProvider{name: "premium"}

	registry := NewProviderRegistry(freeProvider)
	registry.Register("free", freeProvider)
	registry.Register("premium", premiumProvider)
	tierMW := TierMiddleware(registry)

	var gotProvider providers.Provider
	handler := tierMW(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		p, _ := ProviderFromContext(r.Context())
		gotProvider = p
		w.WriteHeader(http.StatusOK)
	}))

	// Claims with empty tier
	claims := &auth.Claims{DeviceID: "test-device", Tier: ""}
	ctx := context.WithValue(context.Background(), claimsKey, claims)

	req := httptest.NewRequest("GET", "/", nil).WithContext(ctx)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if gotProvider != freeProvider {
		t.Error("expected fallback to free tier provider when tier is empty")
	}
}

func TestTierMiddlewareNoClaimsUsesFallback(t *testing.T) {
	freeProvider := &namedMockProvider{name: "free"}

	registry := NewProviderRegistry(freeProvider)
	registry.Register("free", freeProvider)
	tierMW := TierMiddleware(registry)

	var gotProvider providers.Provider
	handler := tierMW(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		p, _ := ProviderFromContext(r.Context())
		gotProvider = p
		w.WriteHeader(http.StatusOK)
	}))

	// No claims in context
	req := httptest.NewRequest("GET", "/", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if gotProvider != freeProvider {
		t.Error("expected fallback provider when no claims present")
	}
}

func TestProviderRegistryGet(t *testing.T) {
	fallback := &namedMockProvider{name: "fallback"}
	free := &namedMockProvider{name: "free"}
	premium := &namedMockProvider{name: "premium"}

	registry := NewProviderRegistry(fallback)
	registry.Register("free", free)
	registry.Register("premium", premium)

	if registry.Get("free") != free {
		t.Error("expected free provider")
	}
	if registry.Get("premium") != premium {
		t.Error("expected premium provider")
	}
	if registry.Get("unknown") != fallback {
		t.Error("expected fallback for unknown tier")
	}
}

// --- Story 10.1 Tests ---

func TestProviderRegistryChainOrdering(t *testing.T) {
	primary := &namedMockProvider{name: "primary"}
	fallbackProvider := &namedMockProvider{name: "fallback"}
	defaultProvider := &namedMockProvider{name: "default"}

	registry := NewProviderRegistry(defaultProvider)
	registry.RegisterChain("free", []providers.Provider{primary, fallbackProvider})

	chain := registry.GetChain("free")
	if len(chain) != 2 {
		t.Fatalf("expected chain length 2, got %d", len(chain))
	}
	if chain[0] != primary {
		t.Error("expected primary provider first in chain")
	}
	if chain[1] != fallbackProvider {
		t.Error("expected fallback provider second in chain")
	}

	// Get should return first in chain
	if registry.Get("free") != primary {
		t.Error("expected Get to return first provider in chain")
	}
}

func TestProviderRegistryDefaultProviderChain(t *testing.T) {
	defaultProvider := &namedMockProvider{name: "default"}

	registry := NewProviderRegistry(defaultProvider)

	chain := registry.GetChain("unknown")
	if len(chain) != 1 {
		t.Fatalf("expected chain length 1 for unknown tier, got %d", len(chain))
	}
	if chain[0] != defaultProvider {
		t.Error("expected default provider for unknown tier")
	}
}

func TestTierMiddlewareAttachesChainToContext(t *testing.T) {
	primary := &namedMockProvider{name: "primary"}
	fallbackProvider := &namedMockProvider{name: "fallback"}

	registry := NewProviderRegistry(primary)
	registry.RegisterChain("free", []providers.Provider{primary, fallbackProvider})
	tierMW := TierMiddleware(registry)

	var gotChain []providers.Provider
	handler := tierMW(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		chain, ok := ProviderChainFromContext(r.Context())
		if !ok {
			t.Fatal("expected provider chain in context")
		}
		gotChain = chain
		w.WriteHeader(http.StatusOK)
	}))

	claims := &auth.Claims{DeviceID: "test-device", Tier: "free"}
	ctx := context.WithValue(context.Background(), claimsKey, claims)

	req := httptest.NewRequest("GET", "/", nil).WithContext(ctx)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if len(gotChain) != 2 {
		t.Fatalf("expected chain length 2, got %d", len(gotChain))
	}
	if gotChain[0] != primary {
		t.Error("expected primary first in chain")
	}
	if gotChain[1] != fallbackProvider {
		t.Error("expected fallback second in chain")
	}
}
