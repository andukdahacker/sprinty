package tests

import (
	"bufio"
	"bytes"
	"compress/flate"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/ducdo/sprinty/server/auth"
	"github.com/ducdo/sprinty/server/handlers"
	"github.com/ducdo/sprinty/server/middleware"
	"github.com/ducdo/sprinty/server/prompts"
	"github.com/ducdo/sprinty/server/providers"
)

const testSecret = "test-secret-key-at-least-32-chars-long"

func createTestPromptBuilder(t *testing.T) *prompts.Builder {
	t.Helper()
	dir := t.TempDir()
	sectionsDir := filepath.Join(dir, "sections")
	os.MkdirAll(sectionsDir, 0o755)
	files := map[string]string{
		"base-persona.md":      "You are {{coach_name}}, a coach.",
		"mode-discovery.md":    "Discovery mode.",
		"mode-directive.md":    "Directive.",
		"safety.md":            "Safety classification.",
		"mood.md":              "Mood selection.",
		"tagging.md":           "Domain tagging.",
		"cultural.md":          "Cultural.",
		"context-injection.md": "{{sprint_context}} {{retrieved_memories}} Coach: {{coach_name}}. Values: {{user_values}}. Goals: {{user_goals}}. Traits: {{user_traits}}. Domains: {{domain_states}}. Engagement: {{engagement_level}}. Moods: {{recent_moods}}. MsgLen: {{avg_message_length}}. Sessions: {{session_count}}. Gap: {{last_session_gap}}. Intensity: {{recent_session_intensity}}.",
		"mode-transitions.md": "Mode transitions: analyze user intent.",
		"challenger.md":       "Challenger capability: push back constructively.",
		"summarize.md":        "Summarize the coaching conversation.",
		"sprint-retro.md":     "Generate a narrative retrospective.",
		"check-in.md":         "Check-in mode: brief response.",
	}
	for name, content := range files {
		os.WriteFile(filepath.Join(sectionsDir, name), []byte(content), 0o644)
	}
	b, err := prompts.NewBuilder(sectionsDir)
	if err != nil {
		t.Fatalf("failed to create prompt builder: %v", err)
	}
	return b
}

func setupMux() *http.ServeMux {
	return setupMuxWithBuilder(nil)
}

func setupMuxWithBuilder(builder *prompts.Builder) *http.ServeMux {
	mockProvider := providers.NewMockProvider()
	authMW := middleware.AuthMiddleware(testSecret)

	// If no builder provided, create a minimal one for tests
	if builder == nil {
		dir, _ := os.MkdirTemp("", "prompts-test-*")
		sectionsDir := filepath.Join(dir, "sections")
		os.MkdirAll(sectionsDir, 0o755)
		files := map[string]string{
			"base-persona.md":      "You are {{coach_name}}, a coach.",
			"mode-discovery.md":    "Discovery mode.",
			"mode-directive.md":    "Directive.",
			"safety.md":            "Safety.",
			"mood.md":              "Mood.",
			"tagging.md":           "Tags.",
			"cultural.md":          "Cultural.",
			"context-injection.md": "{{retrieved_memories}} Coach: {{coach_name}}. Values: {{user_values}}. Goals: {{user_goals}}. Traits: {{user_traits}}. Domains: {{domain_states}}. Engagement: {{engagement_level}}. Moods: {{recent_moods}}. MsgLen: {{avg_message_length}}. Sessions: {{session_count}}. Gap: {{last_session_gap}}. Intensity: {{recent_session_intensity}}.",
			"mode-transitions.md": "Mode transitions: analyze user intent.",
			"challenger.md":       "Challenger capability: push back constructively.",
			"summarize.md":        "Summarize the coaching conversation.",
			"sprint-retro.md":     "Generate a narrative retrospective.",
			"check-in.md":         "Check-in mode: brief response.",
		}
		for name, content := range files {
			os.WriteFile(filepath.Join(sectionsDir, name), []byte(content), 0o644)
		}
		builder, _ = prompts.NewBuilder(sectionsDir)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", handlers.HealthHandler)
	mux.HandleFunc("POST /v1/auth/register", handlers.RegisterHandler(testSecret))
	mux.Handle("POST /v1/auth/refresh", authMW(http.HandlerFunc(handlers.RefreshHandler(testSecret))))
	mux.Handle("POST /v1/chat", authMW(http.HandlerFunc(handlers.ChatHandler(mockProvider, builder))))
	return mux
}

func createValidToken(t *testing.T) string {
	t.Helper()
	token, err := auth.CreateToken(testSecret, "550e8400-e29b-41d4-a716-446655440000", "free", nil)
	if err != nil {
		t.Fatalf("failed to create token: %v", err)
	}
	return token
}

func createExpiredToken(t *testing.T) string {
	t.Helper()
	claims := auth.Claims{
		DeviceID: "test-device",
		Tier:     "free",
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(time.Now().Add(-31 * 24 * time.Hour)),
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(-1 * time.Hour)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(testSecret))
	if err != nil {
		t.Fatalf("failed to create expired token: %v", err)
	}
	return signed
}

func TestHealthEndpoint(t *testing.T) {
	mux := setupMux()
	req := httptest.NewRequest("GET", "/health", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	var body map[string]string
	if err := json.NewDecoder(w.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if body["status"] != "ok" {
		t.Errorf("expected status ok, got %q", body["status"])
	}
}

func TestRegisterWithValidUUID(t *testing.T) {
	mux := setupMux()
	payload := `{"deviceId": "550e8400-e29b-41d4-a716-446655440000"}`
	req := httptest.NewRequest("POST", "/v1/auth/register", strings.NewReader(payload))
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	var body map[string]string
	if err := json.NewDecoder(w.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	token := body["token"]
	if token == "" {
		t.Fatal("expected non-empty token")
	}

	// Validate JWT claims
	claims, err := auth.ValidateToken(testSecret, token)
	if err != nil {
		t.Fatalf("token validation failed: %v", err)
	}
	if claims.DeviceID != "550e8400-e29b-41d4-a716-446655440000" {
		t.Errorf("expected deviceId 550e8400..., got %q", claims.DeviceID)
	}
	if claims.Tier != "free" {
		t.Errorf("expected tier free, got %q", claims.Tier)
	}
	if claims.UserID != nil {
		t.Errorf("expected userId nil, got %v", claims.UserID)
	}

	// Check 30-day expiry
	expiry := claims.ExpiresAt.Time
	expected := time.Now().Add(30 * 24 * time.Hour)
	diff := expected.Sub(expiry)
	if diff < -time.Minute || diff > time.Minute {
		t.Errorf("expiry not ~30 days: got %v", expiry)
	}
}

func TestRegisterResponseMatchesFixture(t *testing.T) {
	// Validate register response matches shared fixture format (auth-register-response.json)
	fixture := loadFixture(t, "auth-register-response.json")
	var fixtureBody map[string]any
	if err := json.Unmarshal(fixture, &fixtureBody); err != nil {
		t.Fatalf("fixture parse failed: %v", err)
	}

	mux := setupMux()
	payload := `{"deviceId": "550e8400-e29b-41d4-a716-446655440000"}`
	req := httptest.NewRequest("POST", "/v1/auth/register", strings.NewReader(payload))
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	var body map[string]any
	json.NewDecoder(w.Body).Decode(&body)

	// Response must have the same keys as the fixture
	for key := range fixtureBody {
		if _, ok := body[key]; !ok {
			t.Errorf("register response missing key %q present in fixture", key)
		}
	}
}

func TestRegisterMissingDeviceID(t *testing.T) {
	mux := setupMux()
	payload := `{"deviceId": ""}`
	req := httptest.NewRequest("POST", "/v1/auth/register", strings.NewReader(payload))
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}

	var body map[string]any
	if err := json.NewDecoder(w.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode error response: %v", err)
	}
	if body["error"] != "missing_device_id" {
		t.Errorf("expected error missing_device_id, got %q", body["error"])
	}
}

func TestRegisterNoBody(t *testing.T) {
	mux := setupMux()
	req := httptest.NewRequest("POST", "/v1/auth/register", strings.NewReader(""))
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestRegisterIdempotent(t *testing.T) {
	mux := setupMux()
	payload := `{"deviceId": "550e8400-e29b-41d4-a716-446655440000"}`

	req1 := httptest.NewRequest("POST", "/v1/auth/register", strings.NewReader(payload))
	w1 := httptest.NewRecorder()
	mux.ServeHTTP(w1, req1)

	req2 := httptest.NewRequest("POST", "/v1/auth/register", strings.NewReader(payload))
	w2 := httptest.NewRecorder()
	mux.ServeHTTP(w2, req2)

	if w1.Code != http.StatusOK || w2.Code != http.StatusOK {
		t.Errorf("expected both 200, got %d and %d", w1.Code, w2.Code)
	}

	var body1, body2 map[string]string
	json.NewDecoder(w1.Body).Decode(&body1)
	json.NewDecoder(w2.Body).Decode(&body2)

	if body1["token"] == "" || body2["token"] == "" {
		t.Error("expected non-empty tokens from both calls")
	}

	_, err1 := auth.ValidateToken(testSecret, body1["token"])
	_, err2 := auth.ValidateToken(testSecret, body2["token"])
	if err1 != nil || err2 != nil {
		t.Errorf("both tokens should be valid: err1=%v, err2=%v", err1, err2)
	}
}

func TestRefreshReturnsNewJWT(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	req := httptest.NewRequest("POST", "/v1/auth/refresh", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	var body map[string]string
	if err := json.NewDecoder(w.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	newToken := body["token"]
	if newToken == "" {
		t.Fatal("expected non-empty refreshed token")
	}

	claims, err := auth.ValidateToken(testSecret, newToken)
	if err != nil {
		t.Fatalf("refreshed token validation failed: %v", err)
	}
	if claims.DeviceID != "550e8400-e29b-41d4-a716-446655440000" {
		t.Errorf("expected deviceId preserved, got %q", claims.DeviceID)
	}
}

func TestProtectedEndpointWithoutJWT(t *testing.T) {
	mux := setupMux()
	req := httptest.NewRequest("POST", "/v1/auth/refresh", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", w.Code)
	}

	var body map[string]any
	if err := json.NewDecoder(w.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode error: %v", err)
	}
	if body["error"] != "invalid_jwt" {
		t.Errorf("expected error invalid_jwt, got %q", body["error"])
	}
}

func TestProtectedEndpointWithExpiredJWT(t *testing.T) {
	mux := setupMux()
	token := createExpiredToken(t)

	req := httptest.NewRequest("POST", "/v1/auth/refresh", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", w.Code)
	}

	var body map[string]any
	json.NewDecoder(w.Body).Decode(&body)
	if body["error"] != "token_expired" {
		t.Errorf("expected error token_expired, got %q", body["error"])
	}
}

func TestProtectedEndpointWithMalformedJWT(t *testing.T) {
	mux := setupMux()
	req := httptest.NewRequest("POST", "/v1/auth/refresh", nil)
	req.Header.Set("Authorization", "Bearer not-a-valid-jwt")
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", w.Code)
	}

	var body map[string]any
	json.NewDecoder(w.Body).Decode(&body)
	if body["error"] != "invalid_jwt" {
		t.Errorf("expected error invalid_jwt, got %q", body["error"])
	}
}

func TestProtectedEndpointWithValidJWT(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	chatPayload := `{"messages":[{"role":"user","content":"hello"}],"mode":"discovery","promptVersion":"1.0"}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(chatPayload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	body := w.Body.String()
	if !strings.Contains(body, "event: token") {
		t.Error("expected SSE token events")
	}
	if !strings.Contains(body, "event: done") {
		t.Error("expected SSE done event")
	}
}

func TestChatWithFixtureRequest(t *testing.T) {
	// Use chat-request-sample.json fixture as the request payload
	fixture := loadFixture(t, "chat-request-sample.json")

	mux := setupMux()
	token := createValidToken(t)

	req := httptest.NewRequest("POST", "/v1/chat", bytes.NewReader(fixture))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d. Body: %s", w.Code, w.Body.String())
	}

	body := w.Body.String()
	if !strings.Contains(body, "event: token") {
		t.Error("expected SSE token events from fixture request")
	}
	if !strings.Contains(body, "event: done") {
		t.Error("expected SSE done event from fixture request")
	}
}

func TestSSETokenEventMatchesFixtureFormat(t *testing.T) {
	// Validate that SSE token events match the format in sse-token-event.txt
	fixture := loadFixture(t, "sse-token-event.txt")
	fixtureStr := string(fixture)

	// Fixture should have "event: token" lines
	if !strings.Contains(fixtureStr, "event: token") {
		t.Fatal("fixture sse-token-event.txt missing 'event: token'")
	}

	// Parse fixture to extract expected JSON structure
	scanner := bufio.NewScanner(strings.NewReader(fixtureStr))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "data: ") {
			data := strings.TrimPrefix(line, "data: ")
			var tokenData map[string]string
			if err := json.Unmarshal([]byte(data), &tokenData); err != nil {
				t.Errorf("fixture token data invalid JSON: %v", err)
			}
			if _, ok := tokenData["text"]; !ok {
				t.Error("fixture token data missing 'text' field")
			}
		}
	}
}

func TestSSEDoneEventMatchesFixtureFormat(t *testing.T) {
	// Validate that SSE done events match the format in sse-done-event.txt
	fixture := loadFixture(t, "sse-done-event.txt")
	fixtureStr := string(fixture)

	if !strings.Contains(fixtureStr, "event: done") {
		t.Fatal("fixture sse-done-event.txt missing 'event: done'")
	}

	scanner := bufio.NewScanner(strings.NewReader(fixtureStr))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "data: ") {
			data := strings.TrimPrefix(line, "data: ")
			var doneData map[string]any
			if err := json.Unmarshal([]byte(data), &doneData); err != nil {
				t.Fatalf("fixture done data invalid JSON: %v", err)
			}
			// Verify expected fields from fixture
			for _, field := range []string{"safetyLevel", "domainTags", "mood", "mode", "challengerUsed", "usage", "promptVersion"} {
				if _, ok := doneData[field]; !ok {
					t.Errorf("fixture done data missing field %q", field)
				}
			}
		}
	}
}

func TestChatSSEMatchesFixtureFormat(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	chatPayload := `{"messages":[{"role":"user","content":"hello"}],"mode":"discovery","promptVersion":"1.0"}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(chatPayload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	type sseEvent struct {
		eventType string
		data      string
	}

	var events []sseEvent
	var current sseEvent
	scanner := bufio.NewScanner(w.Body)

	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "event: ") {
			current.eventType = strings.TrimPrefix(line, "event: ")
		} else if strings.HasPrefix(line, "data: ") {
			current.data = strings.TrimPrefix(line, "data: ")
		} else if line == "" && current.eventType != "" {
			events = append(events, current)
			current = sseEvent{}
		}
	}

	if len(events) < 3 {
		t.Fatalf("expected at least 3 SSE events, got %d", len(events))
	}

	// Token events have text field
	for i := 0; i < len(events)-1; i++ {
		if events[i].eventType != "token" {
			t.Errorf("event %d: expected type token, got %q", i, events[i].eventType)
		}
		var tokenData map[string]string
		if err := json.Unmarshal([]byte(events[i].data), &tokenData); err != nil {
			t.Errorf("event %d: invalid JSON: %v", i, err)
		}
		if _, ok := tokenData["text"]; !ok {
			t.Errorf("event %d: missing text field", i)
		}
	}

	// Done event
	doneEvent := events[len(events)-1]
	if doneEvent.eventType != "done" {
		t.Errorf("last event: expected type done, got %q", doneEvent.eventType)
	}

	var doneData map[string]any
	if err := json.Unmarshal([]byte(doneEvent.data), &doneData); err != nil {
		t.Fatalf("done event: invalid JSON: %v", err)
	}
	if doneData["safetyLevel"] != "green" {
		t.Errorf("expected safetyLevel green, got %v", doneData["safetyLevel"])
	}
	if _, ok := doneData["domainTags"]; !ok {
		t.Error("missing domainTags in done event")
	}
	if _, ok := doneData["usage"]; !ok {
		t.Error("missing usage in done event")
	}
	if doneData["mood"] != "welcoming" {
		t.Errorf("expected mood welcoming, got %v", doneData["mood"])
	}
	if _, ok := doneData["mode"]; !ok {
		t.Error("missing mode in done event")
	}
}

func TestResponseContentType(t *testing.T) {
	mux := setupMux()

	req := httptest.NewRequest("GET", "/health", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)
	ct := w.Header().Get("Content-Type")
	if !strings.HasPrefix(ct, "application/json") {
		t.Errorf("health: expected application/json, got %q", ct)
	}

	payload := `{"deviceId": "test-uuid"}`
	req2 := httptest.NewRequest("POST", "/v1/auth/register", strings.NewReader(payload))
	w2 := httptest.NewRecorder()
	mux.ServeHTTP(w2, req2)
	ct2 := w2.Header().Get("Content-Type")
	if !strings.HasPrefix(ct2, "application/json") {
		t.Errorf("register: expected application/json, got %q", ct2)
	}
}

// --- Story 1.6 Integration Tests ---

// errorProvider is a test provider that returns errors.
type errorProvider struct {
	err error
}

func (p *errorProvider) StreamChat(ctx context.Context, req providers.ChatRequest) (<-chan providers.ChatEvent, error) {
	return nil, p.err
}

func TestChatGzipRequestDecompression(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	// Compress the payload using deflate (matching iOS NSData.compressed(using: .zlib))
	payload := `{"messages":[{"role":"user","content":"hello"}],"mode":"discovery","promptVersion":"1.0"}`
	var compressed bytes.Buffer
	w, err := flate.NewWriter(&compressed, flate.DefaultCompression)
	if err != nil {
		t.Fatalf("failed to create flate writer: %v", err)
	}
	w.Write([]byte(payload))
	w.Close()

	req := httptest.NewRequest("POST", "/v1/chat", &compressed)
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Encoding", "deflate")
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d. Body: %s", rec.Code, rec.Body.String())
	}

	body := rec.Body.String()
	if !strings.Contains(body, "event: token") {
		t.Error("expected SSE token events from deflate-compressed request")
	}
	if !strings.Contains(body, "event: done") {
		t.Error("expected SSE done event from deflate-compressed request")
	}
}

func TestChatWithProfileContext(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	payload := `{"messages":[{"role":"user","content":"hello"}],"mode":"discovery","promptVersion":"1.0","profile":{"coachName":"Luna"}}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(payload))
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rec.Code)
	}

	body := rec.Body.String()
	if !strings.Contains(body, "event: done") {
		t.Error("expected SSE done event")
	}
}

func TestChatProviderError502(t *testing.T) {
	builder := createTestPromptBuilder(t)

	// Create a provider that returns an anthropic-like error
	errProvider := &errorProvider{err: errors.New("provider error")}
	authMW := middleware.AuthMiddleware(testSecret)

	mux := http.NewServeMux()
	mux.Handle("POST /v1/chat", authMW(http.HandlerFunc(handlers.ChatHandler(errProvider, builder))))

	token := createValidToken(t)
	payload := `{"messages":[{"role":"user","content":"hello"}],"mode":"discovery","promptVersion":"1.0"}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(payload))
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadGateway {
		t.Errorf("expected 502, got %d", rec.Code)
	}

	// Validate response matches error-response-502.json fixture
	fixture := loadFixture(t, "error-response-502.json")
	var expected map[string]any
	json.Unmarshal(fixture, &expected)

	var body map[string]any
	json.NewDecoder(rec.Body).Decode(&body)
	if body["error"] != expected["error"] {
		t.Errorf("expected error %v, got %v", expected["error"], body["error"])
	}
	if body["message"] != expected["message"] {
		t.Errorf("expected message %v, got %v", expected["message"], body["message"])
	}
	if body["retryAfter"].(float64) != expected["retryAfter"].(float64) {
		t.Errorf("expected retryAfter %v, got %v", expected["retryAfter"], body["retryAfter"])
	}
}

func TestPromptVersionEndpoint(t *testing.T) {
	builder := createTestPromptBuilder(t)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /v1/prompt/{version}", handlers.PromptVersionHandler(builder))

	req := httptest.NewRequest("GET", "/v1/prompt/current", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rec.Code)
	}

	var body map[string]string
	json.NewDecoder(rec.Body).Decode(&body)
	if body["version"] == "" {
		t.Error("expected non-empty version hash")
	}
}

// --- Story 2.1 Tests ---

func TestChatHandler_DoneEvent_IncludesMode(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	chatPayload := `{"messages":[{"role":"user","content":"hello"}],"mode":"discovery","promptVersion":"1.0"}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(chatPayload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	// Parse SSE events to find the done event
	var doneData map[string]any
	scanner := bufio.NewScanner(w.Body)
	var currentType string
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "event: ") {
			currentType = strings.TrimPrefix(line, "event: ")
		} else if strings.HasPrefix(line, "data: ") && currentType == "done" {
			data := strings.TrimPrefix(line, "data: ")
			json.Unmarshal([]byte(data), &doneData)
		}
	}

	if doneData == nil {
		t.Fatal("no done event found in SSE output")
	}
	if doneData["mode"] != "discovery" {
		t.Errorf("expected mode 'discovery', got %v", doneData["mode"])
	}
}

// --- Story 2.3 Tests ---

func TestChatHandler_DoneEvent_ModeTransition(t *testing.T) {
	builder := createTestPromptBuilder(t)
	mockProvider := &providers.MockProvider{StubbedMode: "directive"}
	authMW := middleware.AuthMiddleware(testSecret)

	mux := http.NewServeMux()
	mux.Handle("POST /v1/chat", authMW(http.HandlerFunc(handlers.ChatHandler(mockProvider, builder))))

	token := createValidToken(t)
	chatPayload := `{"messages":[{"role":"user","content":"I want a plan"}],"mode":"discovery","promptVersion":"1.0"}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(chatPayload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var doneData map[string]any
	scanner := bufio.NewScanner(w.Body)
	var currentType string
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "event: ") {
			currentType = strings.TrimPrefix(line, "event: ")
		} else if strings.HasPrefix(line, "data: ") && currentType == "done" {
			json.Unmarshal([]byte(strings.TrimPrefix(line, "data: ")), &doneData)
		}
	}

	if doneData == nil {
		t.Fatal("no done event found in SSE output")
	}
	if doneData["mode"] != "directive" {
		t.Errorf("expected mode 'directive' from stubbed provider, got %v", doneData["mode"])
	}
}

func TestChatHandler_DoneEvent_ChallengerUsed(t *testing.T) {
	builder := createTestPromptBuilder(t)
	mockProvider := &providers.MockProvider{StubbedChallengerUsed: true}
	authMW := middleware.AuthMiddleware(testSecret)

	mux := http.NewServeMux()
	mux.Handle("POST /v1/chat", authMW(http.HandlerFunc(handlers.ChatHandler(mockProvider, builder))))

	token := createValidToken(t)
	chatPayload := `{"messages":[{"role":"user","content":"I'm going to quit my job tomorrow"}],"mode":"discovery","promptVersion":"1.0"}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(chatPayload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var doneData map[string]any
	scanner := bufio.NewScanner(w.Body)
	var currentType string
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "event: ") {
			currentType = strings.TrimPrefix(line, "event: ")
		} else if strings.HasPrefix(line, "data: ") && currentType == "done" {
			json.Unmarshal([]byte(strings.TrimPrefix(line, "data: ")), &doneData)
		}
	}

	if doneData == nil {
		t.Fatal("no done event found in SSE output")
	}
	if doneData["challengerUsed"] != true {
		t.Errorf("expected challengerUsed true, got %v", doneData["challengerUsed"])
	}
}

func TestChatHandler_DoneEvent_ModeFallbackWhenEmpty(t *testing.T) {
	builder := createTestPromptBuilder(t)
	mockProvider := &providers.MockProvider{} // StubbedMode empty, should fall back to req.Mode
	authMW := middleware.AuthMiddleware(testSecret)

	mux := http.NewServeMux()
	mux.Handle("POST /v1/chat", authMW(http.HandlerFunc(handlers.ChatHandler(mockProvider, builder))))

	token := createValidToken(t)
	chatPayload := `{"messages":[{"role":"user","content":"hello"}],"mode":"directive","promptVersion":"1.0"}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(chatPayload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var doneData map[string]any
	scanner := bufio.NewScanner(w.Body)
	var currentType string
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "event: ") {
			currentType = strings.TrimPrefix(line, "event: ")
		} else if strings.HasPrefix(line, "data: ") && currentType == "done" {
			json.Unmarshal([]byte(strings.TrimPrefix(line, "data: ")), &doneData)
		}
	}

	if doneData == nil {
		t.Fatal("no done event found in SSE output")
	}
	if doneData["mode"] != "directive" {
		t.Errorf("expected mode 'directive' (fallback to req.Mode), got %v", doneData["mode"])
	}
}

// --- Story 2.5 Tests ---

func TestChatHandler_ValidRequest_WithUserState(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	payload := `{"messages":[{"role":"user","content":"hello"}],"mode":"discovery","promptVersion":"1.0","userState":{"engagementLevel":"high","recentMoods":["warm","focused"],"avgMessageLength":"medium","sessionCount":5,"lastSessionGapHours":12,"recentSessionIntensity":"moderate"}}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(payload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d. Body: %s", w.Code, w.Body.String())
	}

	body := w.Body.String()
	if !strings.Contains(body, "event: token") {
		t.Error("expected SSE token events with userState request")
	}
	if !strings.Contains(body, "event: done") {
		t.Error("expected SSE done event with userState request")
	}
}

// --- Story 3.1 Tests ---

func TestChatHandler_SummarizeMode_ReturnsJSON(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	payload := `{"messages":[{"role":"user","content":"I'm stressed about my job"},{"role":"assistant","content":"What's driving that stress?"}],"mode":"summarize","promptVersion":"1.0"}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(payload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d. Body: %s", w.Code, w.Body.String())
	}

	ct := w.Header().Get("Content-Type")
	if !strings.HasPrefix(ct, "application/json") {
		t.Errorf("expected application/json content type, got %q", ct)
	}

	var body map[string]any
	if err := json.NewDecoder(w.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if body["summary"] == nil || body["summary"] == "" {
		t.Error("expected non-empty summary in response")
	}
	if body["keyMoments"] == nil {
		t.Error("expected keyMoments in response")
	}
	if body["domainTags"] == nil {
		t.Error("expected domainTags in response")
	}
}

func TestChatHandler_SummarizeMode_EmptyMessages(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	payload := `{"messages":[],"mode":"summarize","promptVersion":"1.0"}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(payload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var body map[string]any
	if err := json.NewDecoder(w.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	// Should still return a valid response structure
	if body["summary"] == nil {
		t.Error("expected summary field in response")
	}
}

func TestChatHandler_ValidRequest_WithoutUserState(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	payload := `{"messages":[{"role":"user","content":"hello"}],"mode":"discovery","promptVersion":"1.0"}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(payload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	body := w.Body.String()
	if !strings.Contains(body, "event: done") {
		t.Error("expected SSE done event without userState")
	}
}

// --- Story 3.4 Tests ---

func TestChatHandler_WithRagContext_ParsesAndStreams(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	payload := `{"messages":[{"role":"user","content":"hello"}],"mode":"discovery","promptVersion":"1.0","ragContext":"## Past Conversations\n**2026-03-20** — career\nSummary: Discussed goals"}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(payload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	body := w.Body.String()
	if !strings.Contains(body, "event: done") {
		t.Error("expected SSE done event with ragContext present")
	}
}

func TestChatHandler_WithoutRagContext_StreamsNormally(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	payload := `{"messages":[{"role":"user","content":"hello"}],"mode":"discovery","promptVersion":"1.0"}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(payload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	body := w.Body.String()
	if !strings.Contains(body, "event: done") {
		t.Error("expected SSE done event without ragContext")
	}
}

func TestChatHandler_WithEmptyRagContext_StreamsNormally(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	payload := `{"messages":[{"role":"user","content":"hello"}],"mode":"discovery","promptVersion":"1.0","ragContext":""}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(payload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	body := w.Body.String()
	if !strings.Contains(body, "event: done") {
		t.Error("expected SSE done event with empty ragContext")
	}
}

func TestChatHandler_DoneEvent_IncludesMemoryReferenced(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	payload := `{"messages":[{"role":"user","content":"hello"}],"mode":"discovery","promptVersion":"1.0"}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(payload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	body := w.Body.String()
	if !strings.Contains(body, "memoryReferenced") {
		t.Error("expected memoryReferenced field in done event")
	}
}

// --- Story 5.3 Tests ---

func TestSprintRetroHandler(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	payload := `{
		"messages":[{"role":"user","content":"Generate sprint retrospective"}],
		"mode":"sprint_retro",
		"promptVersion":"1.0",
		"sprintContext":{
			"activeSprint":{"name":"Career Growth","status":"active","stepsCompleted":3,"stepsTotal":3,"dayNumber":14,"totalDays":14,"sprintJustCompleted":true},
			"retroSteps":[
				{"description":"Step 1: Research roles","coachContext":"Exploring career options"},
				{"description":"Step 2: Update resume"},
				{"description":"Step 3: Apply"}
			]
		}
	}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(payload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d. Body: %s", w.Code, w.Body.String())
	}

	ct := w.Header().Get("Content-Type")
	if !strings.HasPrefix(ct, "text/event-stream") {
		t.Errorf("expected text/event-stream content type, got %q", ct)
	}

	body := w.Body.String()
	// Should have token events
	if !strings.Contains(body, "event: token") {
		t.Error("expected token events in sprint_retro response")
	}
	// Should have done event
	if !strings.Contains(body, "event: done") {
		t.Error("expected done event in sprint_retro response")
	}
	// Mock provider returns retro-specific text
	if !strings.Contains(body, "chapter we just finished") {
		t.Error("expected retro narrative text in response")
	}
}

func TestSprintRetroHandler_EmptyContext_Returns400(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	payload := `{
		"messages":[{"role":"user","content":"Generate sprint retrospective"}],
		"mode":"sprint_retro",
		"promptVersion":"1.0"
	}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(payload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for empty retroSteps, got %d. Body: %s", w.Code, w.Body.String())
	}

	body := w.Body.String()
	if !strings.Contains(body, "invalid_request") {
		t.Error("expected invalid_request error code")
	}
}

// --- Story 5.4 Tests ---

func TestCheckInModeStreamsTokensAndDone(t *testing.T) {
	mux := setupMux()
	token := createValidToken(t)

	payload := `{
		"messages":[{"role":"user","content":"Quick check-in: here's where I am on my sprint"}],
		"mode":"check_in",
		"promptVersion":"1.0"
	}`
	req := httptest.NewRequest("POST", "/v1/chat", strings.NewReader(payload))
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d. Body: %s", w.Code, w.Body.String())
	}

	ct := w.Header().Get("Content-Type")
	if !strings.HasPrefix(ct, "text/event-stream") {
		t.Errorf("expected text/event-stream content type, got %q", ct)
	}

	body := w.Body.String()
	if !strings.Contains(body, "event: token") {
		t.Error("expected token events in check_in response")
	}
	if !strings.Contains(body, "event: done") {
		t.Error("expected done event in check_in response")
	}
	if !strings.Contains(body, "showing up") {
		t.Error("expected check-in specific text in response")
	}
}

func TestCheckInModePromptAssembly(t *testing.T) {
	builder := createTestPromptBuilder(t)
	prompt := builder.Build("check_in", "Sage", nil, nil, "", nil)

	if !strings.Contains(prompt, "Check-in mode") {
		t.Error("expected check-in section in assembled prompt")
	}
	if strings.Contains(prompt, "Discovery mode") {
		t.Error("check_in should not include discovery section")
	}
}

func TestSprintContextMilestoneFields(t *testing.T) {
	builder := createTestPromptBuilder(t)

	lastStep := "2026-03-25T10:00:00Z"
	justCompleted := true
	sprintCtx := &providers.SprintContext{
		ActiveSprint: &providers.ActiveSprintInfo{
			Name:                "Career Growth",
			Status:              "complete",
			StepsCompleted:      3,
			StepsTotal:          3,
			DayNumber:           14,
			TotalDays:           14,
			LastStepCompletedAt: &lastStep,
			SprintJustCompleted: &justCompleted,
		},
	}

	result := builder.Build("discovery", "Coach", nil, nil, "", sprintCtx)

	if !strings.Contains(result, "recently completed a sprint step") {
		t.Error("expected milestone context for lastStepCompletedAt")
	}
	if !strings.Contains(result, "just completed their entire sprint") {
		t.Error("expected sprint completion context for sprintJustCompleted")
	}
	if !strings.Contains(result, "No Challenger this session") {
		t.Error("expected Challenger suppression in milestone context")
	}
}
