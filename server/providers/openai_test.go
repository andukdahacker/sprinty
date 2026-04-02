package providers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/openai/openai-go"
	"github.com/openai/openai-go/option"
)

// newTestOpenAIProvider creates an OpenAIProvider pointing at a test HTTP server.
func newTestOpenAIProvider(serverURL string) *OpenAIProvider {
	client := openai.NewClient(
		option.WithAPIKey("test-key"),
		option.WithBaseURL(serverURL),
	)
	return &OpenAIProvider{
		client: &client,
		model:  "gpt-4.1-mini",
	}
}

// buildOpenAIStreamingResponse creates an OpenAI SSE streaming response
// that simulates structured JSON output via response_format.
func buildOpenAIStreamingResponse(coaching string, safetyLevel string, mode string) string {
	fullJSON := fmt.Sprintf(`{"coaching":%s,"safetyLevel":"%s","domainTags":["career"],"mood":"warm","memoryReferenced":false,"mode":"%s","challengerUsed":false}`,
		mustMarshal(coaching), safetyLevel, mode)

	var sb strings.Builder

	// Initial chunk with role
	sb.WriteString(fmt.Sprintf("data: %s\n\n", mustMarshalChunk("", "assistant", "")))

	// Stream content in chunks
	chunkSize := 30
	for i := 0; i < len(fullJSON); i += chunkSize {
		end := i + chunkSize
		if end > len(fullJSON) {
			end = len(fullJSON)
		}
		sb.WriteString(fmt.Sprintf("data: %s\n\n", mustMarshalChunk(fullJSON[i:end], "", "")))
	}

	// Final chunk with stop
	sb.WriteString(fmt.Sprintf("data: %s\n\n", mustMarshalStopChunk()))
	sb.WriteString("data: [DONE]\n\n")

	return sb.String()
}

func mustMarshal(s string) string {
	b, _ := json.Marshal(s)
	return string(b)
}

func mustMarshalChunk(content, role, finishReason string) string {
	delta := map[string]any{}
	if role != "" {
		delta["role"] = role
	}
	if content != "" {
		delta["content"] = content
	}

	choice := map[string]any{
		"index": 0,
		"delta": delta,
	}
	if finishReason != "" {
		choice["finish_reason"] = finishReason
	} else {
		choice["finish_reason"] = nil
	}

	chunk := map[string]any{
		"id":      "chatcmpl-test",
		"object":  "chat.completion.chunk",
		"created": 1234567890,
		"model":   "gpt-4.1-mini",
		"choices": []any{choice},
	}
	b, _ := json.Marshal(chunk)
	return string(b)
}

func mustMarshalStopChunk() string {
	chunk := map[string]any{
		"id":      "chatcmpl-test",
		"object":  "chat.completion.chunk",
		"created": 1234567890,
		"model":   "gpt-4.1-mini",
		"choices": []any{
			map[string]any{
				"index":         0,
				"delta":         map[string]any{},
				"finish_reason": "stop",
			},
		},
		"usage": map[string]any{
			"prompt_tokens":     42,
			"completion_tokens": 18,
			"total_tokens":      60,
		},
	}
	b, _ := json.Marshal(chunk)
	return string(b)
}

func TestOpenAIProviderStreamChatSuccess(t *testing.T) {
	coaching := "Let's explore what's on your mind."
	responseBody := buildOpenAIStreamingResponse(coaching, "green", "discovery")

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(responseBody))
	}))
	defer server.Close()

	provider := newTestOpenAIProvider(server.URL)

	req := ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: "hello"}},
		Mode:     "discovery",
	}

	ch, err := provider.StreamChat(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var tokens []string
	var doneEvent ChatEvent
	for event := range ch {
		switch event.Type {
		case "token":
			tokens = append(tokens, event.Text)
		case "done":
			doneEvent = event
		}
	}

	fullText := strings.Join(tokens, "")
	if fullText != coaching {
		t.Errorf("expected coaching %q, got %q", coaching, fullText)
	}

	if doneEvent.SafetyLevel != "green" {
		t.Errorf("expected safetyLevel green, got %q", doneEvent.SafetyLevel)
	}
	if doneEvent.Mode != "discovery" {
		t.Errorf("expected mode discovery, got %q", doneEvent.Mode)
	}
	if doneEvent.Mood != "warm" {
		t.Errorf("expected mood warm, got %q", doneEvent.Mood)
	}
	if len(doneEvent.DomainTags) != 1 || doneEvent.DomainTags[0] != "career" {
		t.Errorf("expected domainTags [career], got %v", doneEvent.DomainTags)
	}
}

func TestOpenAIProviderStreamChatError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusTooManyRequests)
		w.Write([]byte(`{"error":{"message":"Rate limit exceeded","type":"rate_limit_error","code":"rate_limit_exceeded"}}`))
	}))
	defer server.Close()

	provider := newTestOpenAIProvider(server.URL)

	req := ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: "hello"}},
		Mode:     "discovery",
	}

	_, err := provider.StreamChat(context.Background(), req)
	if err == nil {
		t.Fatal("expected error for rate limited response")
	}
	if !strings.Contains(err.Error(), "openai.StreamChat") {
		t.Errorf("expected wrapped error, got: %v", err)
	}
}

func TestOpenAIProviderStreamChatContextCancellation(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)
		flusher := w.(http.Flusher)

		w.Write([]byte(fmt.Sprintf("data: %s\n\n", mustMarshalChunk("", "assistant", ""))))
		flusher.Flush()

		<-r.Context().Done()
	}))
	defer server.Close()

	provider := newTestOpenAIProvider(server.URL)

	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	req := ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: "hello"}},
		Mode:     "discovery",
	}

	ch, err := provider.StreamChat(ctx, req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	for range ch {
	}
	// If we get here, goroutine cleaned up properly
}

func TestOpenAIProviderStreamChatSystemPrompt(t *testing.T) {
	var receivedBody map[string]any

	responseBody := buildOpenAIStreamingResponse("hi", "green", "discovery")
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewDecoder(r.Body).Decode(&receivedBody)
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(responseBody))
	}))
	defer server.Close()

	provider := newTestOpenAIProvider(server.URL)

	req := ChatRequest{
		Messages:     []ChatMessage{{Role: "user", Content: "hello"}},
		Mode:         "discovery",
		SystemPrompt: "You are a coaching assistant.",
	}

	ch, err := provider.StreamChat(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	for range ch {
	}

	// Verify system message in messages array (OpenAI pattern)
	messages, ok := receivedBody["messages"].([]any)
	if !ok {
		t.Fatal("expected messages in request body")
	}
	if len(messages) < 2 {
		t.Fatalf("expected at least 2 messages (system + user), got %d", len(messages))
	}
	firstMsg, ok := messages[0].(map[string]any)
	if !ok {
		t.Fatal("expected first message to be object")
	}
	if firstMsg["role"] != "system" {
		t.Errorf("expected first message role 'system', got %v", firstMsg["role"])
	}
}

func TestOpenAIProviderStreamChatMalformedJSON(t *testing.T) {
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("data: %s\n\n", mustMarshalChunk("", "assistant", "")))
	sb.WriteString(fmt.Sprintf("data: %s\n\n", mustMarshalChunk("{not valid json at all", "", "")))
	sb.WriteString(fmt.Sprintf("data: %s\n\n", mustMarshalStopChunk()))
	sb.WriteString("data: [DONE]\n\n")

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(sb.String()))
	}))
	defer server.Close()

	provider := newTestOpenAIProvider(server.URL)

	req := ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: "hello"}},
		Mode:     "discovery",
	}

	ch, err := provider.StreamChat(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var doneEvent ChatEvent
	for event := range ch {
		if event.Type == "done" {
			doneEvent = event
		}
	}

	// Should fall back to safe defaults
	if doneEvent.SafetyLevel != "green" {
		t.Errorf("expected fallback safetyLevel green, got %q", doneEvent.SafetyLevel)
	}
	if doneEvent.Mood != "welcoming" {
		t.Errorf("expected fallback mood welcoming, got %q", doneEvent.Mood)
	}
}

func TestOpenAIProviderStreamChatModeFallback(t *testing.T) {
	// Response with empty mode — should fall back to request mode
	fullJSON := `{"coaching":"hi","safetyLevel":"green","domainTags":[],"mood":"warm","memoryReferenced":false,"mode":"","challengerUsed":false}`

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("data: %s\n\n", mustMarshalChunk("", "assistant", "")))
	sb.WriteString(fmt.Sprintf("data: %s\n\n", mustMarshalChunk(fullJSON, "", "")))
	sb.WriteString(fmt.Sprintf("data: %s\n\n", mustMarshalStopChunk()))
	sb.WriteString("data: [DONE]\n\n")

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(sb.String()))
	}))
	defer server.Close()

	provider := newTestOpenAIProvider(server.URL)

	req := ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: "hello"}},
		Mode:     "directive",
	}

	ch, err := provider.StreamChat(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var doneEvent ChatEvent
	for event := range ch {
		if event.Type == "done" {
			doneEvent = event
		}
	}

	if doneEvent.Mode != "directive" {
		t.Errorf("expected mode fallback to 'directive', got %q", doneEvent.Mode)
	}
}

func TestOpenAIProviderStreamChatSummarize(t *testing.T) {
	summarizeJSON := `{"summary":"User explored career concerns.","keyMoments":["realized pattern"],"domainTags":["career"],"emotionalMarkers":["anxious"],"keyDecisions":["schedule meeting"]}`

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("data: %s\n\n", mustMarshalChunk("", "assistant", "")))
	sb.WriteString(fmt.Sprintf("data: %s\n\n", mustMarshalChunk(summarizeJSON, "", "")))
	sb.WriteString(fmt.Sprintf("data: %s\n\n", mustMarshalStopChunk()))
	sb.WriteString("data: [DONE]\n\n")

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(sb.String()))
	}))
	defer server.Close()

	provider := newTestOpenAIProvider(server.URL)

	req := ChatRequest{
		Messages:     []ChatMessage{{Role: "user", Content: "summarize this"}},
		Mode:         "summarize",
		SystemPrompt: "Summarize the conversation.",
	}

	ch, err := provider.StreamChat(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var doneEvent ChatEvent
	tokenCount := 0
	for event := range ch {
		switch event.Type {
		case "token":
			tokenCount++
		case "done":
			doneEvent = event
		}
	}

	// Summarize mode should NOT emit tokens
	if tokenCount > 0 {
		t.Errorf("expected no tokens in summarize mode, got %d", tokenCount)
	}

	// SummaryData should be populated
	if doneEvent.SummaryData == nil {
		t.Fatal("expected SummaryData in done event, got nil")
	}

	summary, ok := doneEvent.SummaryData.(*summarizeResult)
	if !ok {
		t.Fatalf("expected *summarizeResult, got %T", doneEvent.SummaryData)
	}
	if summary.Summary != "User explored career concerns." {
		t.Errorf("expected summary text, got %q", summary.Summary)
	}
	if len(summary.KeyMoments) != 1 || summary.KeyMoments[0] != "realized pattern" {
		t.Errorf("expected keyMoments [realized pattern], got %v", summary.KeyMoments)
	}
	if len(summary.DomainTags) != 1 || summary.DomainTags[0] != "career" {
		t.Errorf("expected domainTags [career], got %v", summary.DomainTags)
	}
}
