package tests

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/ducdo/sprinty/server/auth"
	"github.com/ducdo/sprinty/server/middleware"
)

func TestAuthMiddlewareStoresClaimsInContext(t *testing.T) {
	token, err := auth.CreateToken(testSecret, "device-123", "free", nil)
	if err != nil {
		t.Fatalf("failed to create token: %v", err)
	}

	var extractedClaims *auth.Claims
	handler := middleware.AuthMiddleware(testSecret)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims, ok := middleware.ClaimsFromContext(r.Context())
		if !ok {
			t.Error("expected claims in context")
			return
		}
		extractedClaims = claims
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest("GET", "/test", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	if extractedClaims == nil {
		t.Fatal("claims not extracted")
	}
	if extractedClaims.DeviceID != "device-123" {
		t.Errorf("expected deviceId device-123, got %q", extractedClaims.DeviceID)
	}
}

func TestAuthMiddlewareRejects_NoBearerPrefix(t *testing.T) {
	token, _ := auth.CreateToken(testSecret, "device-123", "free", nil)

	handler := middleware.AuthMiddleware(testSecret)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("handler should not be called")
	}))

	req := httptest.NewRequest("GET", "/test", nil)
	req.Header.Set("Authorization", token) // Missing "Bearer " prefix
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", w.Code)
	}
}
