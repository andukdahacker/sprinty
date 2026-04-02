package middleware

import (
	"context"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/ducdo/sprinty/server/auth"
	"github.com/ducdo/sprinty/server/config"
)

// --- Story 8.3 Tests: SessionTracker ---

func TestSessionTrackerCountEmpty(t *testing.T) {
	tracker := NewSessionTracker()
	if count := tracker.Count("device-1"); count != 0 {
		t.Errorf("expected 0, got %d", count)
	}
}

func TestSessionTrackerRecordAndCount(t *testing.T) {
	tracker := NewSessionTracker()
	tracker.RecordSession("device-1")
	tracker.RecordSession("device-1")
	tracker.RecordSession("device-2")

	if count := tracker.Count("device-1"); count != 2 {
		t.Errorf("expected 2 for device-1, got %d", count)
	}
	if count := tracker.Count("device-2"); count != 1 {
		t.Errorf("expected 1 for device-2, got %d", count)
	}
}

func TestSessionTrackerDailyReset(t *testing.T) {
	tracker := NewSessionTracker()

	// Manually insert a yesterday timestamp
	yesterday := time.Now().UTC().Add(-25 * time.Hour)
	tracker.mu.Lock()
	tracker.sessions["device-1"] = []time.Time{yesterday}
	tracker.mu.Unlock()

	// Yesterday's entry should not count
	if count := tracker.Count("device-1"); count != 0 {
		t.Errorf("expected 0 (stale entry), got %d", count)
	}

	// Recording today should work and clean up stale
	tracker.RecordSession("device-1")
	if count := tracker.Count("device-1"); count != 1 {
		t.Errorf("expected 1 after recording today, got %d", count)
	}

	// Verify stale entry was cleaned up
	tracker.mu.RLock()
	entries := tracker.sessions["device-1"]
	tracker.mu.RUnlock()
	if len(entries) != 1 {
		t.Errorf("expected stale entries cleaned to 1, got %d", len(entries))
	}
}

func TestSessionTrackerConcurrentAccess(t *testing.T) {
	tracker := NewSessionTracker()
	var wg sync.WaitGroup

	// Concurrent writes
	for i := 0; i < 100; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			tracker.RecordSession("device-concurrent")
		}()
	}

	// Concurrent reads
	for i := 0; i < 100; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			tracker.Count("device-concurrent")
		}()
	}

	wg.Wait()

	count := tracker.Count("device-concurrent")
	if count != 100 {
		t.Errorf("expected 100 after concurrent writes, got %d", count)
	}
}

// --- Story 8.3 Tests: GuardrailsMiddleware ---

func makeTestCfg(freeLimit, premiumLimit int) *config.Config {
	return &config.Config{
		FreeTierDailySessionLimit:    freeLimit,
		PremiumTierDailySessionLimit: premiumLimit,
	}
}

func requestWithClaims(deviceID, tier string) *http.Request {
	claims := &auth.Claims{DeviceID: deviceID, Tier: tier}
	ctx := context.WithValue(context.Background(), claimsKey, claims)
	return httptest.NewRequest("POST", "/v1/chat", nil).WithContext(ctx)
}

func TestGuardrailsMiddlewareFreeTierLimitHit(t *testing.T) {
	tracker := NewSessionTracker()
	cfg := makeTestCfg(3, 0)
	mw := GuardrailsMiddleware(tracker, cfg)

	handler := mw(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if GuardrailActiveFromContext(r.Context()) {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("guardrailed"))
		} else {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("normal"))
		}
	}))

	// First 3 requests: normal (count goes 0→1, 1→2, 2→3)
	for i := 0; i < 3; i++ {
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, requestWithClaims("device-free", "free"))
		if w.Body.String() != "normal" {
			t.Errorf("request %d: expected normal, got %s", i+1, w.Body.String())
		}
	}

	// 4th request: guardrailed (count is 3 >= limit 3)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, requestWithClaims("device-free", "free"))
	if w.Body.String() != "guardrailed" {
		t.Errorf("4th request: expected guardrailed, got %s", w.Body.String())
	}

	// Verify count stayed at 3 (guardrailed requests don't record)
	if count := tracker.Count("device-free"); count != 3 {
		t.Errorf("expected count 3 (no increment for guardrailed), got %d", count)
	}
}

func TestGuardrailsMiddlewarePremiumUnlimited(t *testing.T) {
	tracker := NewSessionTracker()
	cfg := makeTestCfg(3, 0) // 0 = unlimited for premium
	mw := GuardrailsMiddleware(tracker, cfg)

	handler := mw(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if GuardrailActiveFromContext(r.Context()) {
			w.Write([]byte("guardrailed"))
		} else {
			w.Write([]byte("normal"))
		}
	}))

	// 10 premium requests — all should be normal
	for i := 0; i < 10; i++ {
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, requestWithClaims("device-premium", "premium"))
		if w.Body.String() != "normal" {
			t.Errorf("premium request %d: expected normal, got %s", i+1, w.Body.String())
		}
	}
}

func TestGuardrailsMiddlewareBelowLimitPassThrough(t *testing.T) {
	tracker := NewSessionTracker()
	cfg := makeTestCfg(5, 0)
	mw := GuardrailsMiddleware(tracker, cfg)

	guardrailed := false
	handler := mw(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		guardrailed = GuardrailActiveFromContext(r.Context())
	}))

	w := httptest.NewRecorder()
	handler.ServeHTTP(w, requestWithClaims("device-new", "free"))

	if guardrailed {
		t.Error("expected no guardrail for first request")
	}
	if count := tracker.Count("device-new"); count != 1 {
		t.Errorf("expected session recorded, count = %d", count)
	}
}

func TestGuardrailsMiddlewareMissingClaimsFallback(t *testing.T) {
	tracker := NewSessionTracker()
	cfg := makeTestCfg(3, 0)
	mw := GuardrailsMiddleware(tracker, cfg)

	called := false
	handler := mw(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
	}))

	// Request with no claims in context
	w := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/v1/chat", nil)
	handler.ServeHTTP(w, req)

	if !called {
		t.Error("expected handler to be called even without claims")
	}
}

func TestGuardrailsMiddlewareEmptyTierDefaultsFree(t *testing.T) {
	tracker := NewSessionTracker()
	cfg := makeTestCfg(2, 0)
	mw := GuardrailsMiddleware(tracker, cfg)

	handler := mw(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if GuardrailActiveFromContext(r.Context()) {
			w.Write([]byte("guardrailed"))
		} else {
			w.Write([]byte("normal"))
		}
	}))

	// Claims with empty tier
	claims := &auth.Claims{DeviceID: "device-empty-tier", Tier: ""}
	ctx := context.WithValue(context.Background(), claimsKey, claims)

	// 2 normal, 3rd guardrailed (free limit = 2)
	for i := 0; i < 2; i++ {
		w := httptest.NewRecorder()
		req := httptest.NewRequest("POST", "/v1/chat", nil).WithContext(ctx)
		handler.ServeHTTP(w, req)
		if w.Body.String() != "normal" {
			t.Errorf("request %d: expected normal, got %s", i+1, w.Body.String())
		}
	}

	w := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/v1/chat", nil).WithContext(ctx)
	handler.ServeHTTP(w, req)
	if w.Body.String() != "guardrailed" {
		t.Errorf("3rd request: expected guardrailed, got %s", w.Body.String())
	}
}

func TestGuardrailActiveFromContextDefault(t *testing.T) {
	ctx := context.Background()
	if GuardrailActiveFromContext(ctx) {
		t.Error("expected false for empty context")
	}
}
