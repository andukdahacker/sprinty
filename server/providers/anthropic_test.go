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

	"github.com/anthropics/anthropic-sdk-go"
	"github.com/anthropics/anthropic-sdk-go/option"
)

// newTestProvider creates an AnthropicProvider pointing at a test HTTP server.
func newTestProvider(serverURL string) *AnthropicProvider {
	client := anthropic.NewClient(
		option.WithAPIKey("test-key"),
		option.WithMaxRetries(0),
		option.WithBaseURL(serverURL),
	)
	return &AnthropicProvider{
		client: &client,
		model:  anthropic.ModelClaudeHaiku4_5,
	}
}

// sseChunk builds a single SSE data line for the Anthropic streaming protocol.
func sseChunk(eventType, data string) string {
	return fmt.Sprintf("event: %s\ndata: %s\n\n", eventType, data)
}

// buildStreamingResponse returns a full Anthropic streaming response body
// that simulates a tool_use streaming flow with the given coaching text and metadata.
func buildStreamingResponse(coaching, safetyLevel, mood string, domainTags []string) string {
	var b strings.Builder

	// message_start
	b.WriteString(sseChunk("message_start", `{"type":"message_start","message":{"id":"msg_test","type":"message","role":"assistant","content":[],"model":"claude-haiku-4-5","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":50,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}`))

	// content_block_start (tool_use)
	b.WriteString(sseChunk("content_block_start", `{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_test","name":"respond","input":{}}}`))

	// Stream partial JSON chunks for the tool input
	// Build the JSON progressively
	tagsJSON := `[]`
	if len(domainTags) > 0 {
		parts := make([]string, len(domainTags))
		for i, t := range domainTags {
			parts[i] = fmt.Sprintf(`"%s"`, t)
		}
		tagsJSON = fmt.Sprintf("[%s]", strings.Join(parts, ","))
	}

	fullJSON := fmt.Sprintf(`{"coaching":"%s","safetyLevel":"%s","domainTags":%s,"mood":"%s","memoryReferenced":false}`,
		coaching, safetyLevel, tagsJSON, mood)

	// Send in chunks
	chunkSize := 20
	for i := 0; i < len(fullJSON); i += chunkSize {
		end := i + chunkSize
		if end > len(fullJSON) {
			end = len(fullJSON)
		}
		chunk := fullJSON[i:end]
		// Escape for JSON string
		chunk = strings.ReplaceAll(chunk, `\`, `\\`)
		chunk = strings.ReplaceAll(chunk, `"`, `\"`)
		b.WriteString(sseChunk("content_block_delta", fmt.Sprintf(`{"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"%s"}}`, chunk)))
	}

	// content_block_stop
	b.WriteString(sseChunk("content_block_stop", `{"type":"content_block_stop","index":0}`))

	// message_delta
	b.WriteString(sseChunk("message_delta", `{"type":"message_delta","delta":{"stop_reason":"tool_use","stop_sequence":null},"usage":{"output_tokens":42}}`))

	// message_stop
	b.WriteString(sseChunk("message_stop", `{"type":"message_stop"}`))

	return b.String()
}

func TestAnthropicProvider_StreamChat_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)

		body := buildStreamingResponse(
			"Hello! I'm here to help you explore what matters most.",
			"green", "welcoming", []string{"general"},
		)
		w.Write([]byte(body))
	}))
	defer server.Close()

	provider := newTestProvider(server.URL)

	req := ChatRequest{
		Messages:     []ChatMessage{{Role: "user", Content: "Hi"}},
		Mode:         "discovery",
		SystemPrompt: "You are a coach.",
	}

	ch, err := provider.StreamChat(context.Background(), req)
	if err != nil {
		t.Fatalf("StreamChat returned error: %v", err)
	}

	var tokens []string
	var doneEvent *ChatEvent

	timeout := time.After(5 * time.Second)
	for {
		select {
		case event, ok := <-ch:
			if !ok {
				goto done
			}
			switch event.Type {
			case "token":
				tokens = append(tokens, event.Text)
			case "done":
				doneEvent = &event
			}
		case <-timeout:
			t.Fatal("timeout waiting for events")
		}
	}
done:

	if len(tokens) == 0 {
		t.Error("expected at least one token event")
	}

	// Verify all token text concatenated contains the coaching text
	fullText := strings.Join(tokens, "")
	if !strings.Contains(fullText, "Hello!") {
		t.Errorf("expected coaching text to contain 'Hello!', got %q", fullText)
	}

	if doneEvent == nil {
		t.Fatal("expected done event")
	}
	if doneEvent.SafetyLevel != "green" {
		t.Errorf("expected safetyLevel green, got %q", doneEvent.SafetyLevel)
	}
	if doneEvent.Mood != "welcoming" {
		t.Errorf("expected mood welcoming, got %q", doneEvent.Mood)
	}
	if doneEvent.Usage == nil {
		t.Error("expected usage in done event")
	}
}

func TestAnthropicProvider_StreamChat_ContextCancellation(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)
		// Send a slow stream - first chunk then hang
		w.Write([]byte(sseChunk("message_start", `{"type":"message_start","message":{"id":"msg_test","type":"message","role":"assistant","content":[],"model":"claude-haiku-4-5","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}`)))
		w.(http.Flusher).Flush()
		// Block until client disconnects
		<-r.Context().Done()
	}))
	defer server.Close()

	provider := newTestProvider(server.URL)

	ctx, cancel := context.WithCancel(context.Background())

	ch, err := provider.StreamChat(ctx, ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: "Hi"}},
		Mode:     "discovery",
	})
	if err != nil {
		t.Fatalf("StreamChat returned error: %v", err)
	}

	// Cancel context after a short delay
	go func() {
		time.Sleep(100 * time.Millisecond)
		cancel()
	}()

	// Channel should close without hanging
	timeout := time.After(2 * time.Second)
	for {
		select {
		case _, ok := <-ch:
			if !ok {
				return // success — channel closed
			}
		case <-timeout:
			t.Fatal("timeout: channel did not close after context cancellation")
		}
	}
}

func TestAnthropicProvider_StreamChat_APIError500(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(`{"type":"error","error":{"type":"api_error","message":"Internal server error"}}`))
	}))
	defer server.Close()

	provider := newTestProvider(server.URL)

	ch, err := provider.StreamChat(context.Background(), ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: "Hi"}},
		Mode:     "discovery",
	})
	// The SDK may return an error directly or close the channel
	if err != nil {
		// Error returned directly — this is acceptable
		return
	}

	// If no error, channel should close (mid-stream error handling)
	timeout := time.After(5 * time.Second)
	for {
		select {
		case _, ok := <-ch:
			if !ok {
				return // channel closed, success
			}
		case <-timeout:
			t.Fatal("timeout waiting for channel close on error")
		}
	}
}

func TestAnthropicProvider_StreamChat_APIError429(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Retry-After", "30")
		w.WriteHeader(http.StatusTooManyRequests)
		w.Write([]byte(`{"type":"error","error":{"type":"rate_limit_error","message":"Rate limit exceeded"}}`))
	}))
	defer server.Close()

	provider := newTestProvider(server.URL)

	ch, err := provider.StreamChat(context.Background(), ChatRequest{
		Messages: []ChatMessage{{Role: "user", Content: "Hi"}},
		Mode:     "discovery",
	})
	if err != nil {
		return // Error returned directly — acceptable
	}

	timeout := time.After(5 * time.Second)
	for {
		select {
		case _, ok := <-ch:
			if !ok {
				return
			}
		case <-timeout:
			t.Fatal("timeout waiting for channel close on rate limit")
		}
	}
}

func TestExtractCoachingChunk(t *testing.T) {
	tests := []struct {
		name     string
		json     string
		lastLen  int
		expected string
		newLen   int
	}{
		{
			name:     "no coaching key yet",
			json:     `{"safety`,
			lastLen:  0,
			expected: "",
			newLen:   0,
		},
		{
			name:     "coaching value starts",
			json:     `{"coaching":"Hello`,
			lastLen:  0,
			expected: "Hello",
			newLen:   5,
		},
		{
			name:     "coaching value grows",
			json:     `{"coaching":"Hello, world`,
			lastLen:  5,
			expected: ", world",
			newLen:   12,
		},
		{
			name:     "no new content",
			json:     `{"coaching":"Hello`,
			lastLen:  5,
			expected: "",
			newLen:   5,
		},
		{
			name:     "escaped newline in coaching",
			json:     `{"coaching":"line1\nline2`,
			lastLen:  0,
			expected: "line1\nline2",
			newLen:   11,
		},
		{
			name:     "coaching value complete",
			json:     `{"coaching":"Hello","safetyLevel":"green"`,
			lastLen:  0,
			expected: "Hello",
			newLen:   5,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			lastLen := tt.lastLen
			got := extractCoachingChunk(tt.json, &lastLen)
			if got != tt.expected {
				t.Errorf("expected %q, got %q", tt.expected, got)
			}
			if lastLen != tt.newLen {
				t.Errorf("expected lastLen %d, got %d", tt.newLen, lastLen)
			}
		})
	}
}

func mustJSON(v any) []byte {
	b, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return b
}

func TestParseFinalResult_ValidToolUse(t *testing.T) {
	msg := &anthropic.Message{
		Content: []anthropic.ContentBlockUnion{
			{
				Type: "tool_use",
				Input: mustJSON(map[string]any{
					"coaching":         "Test response",
					"safetyLevel":      "green",
					"domainTags":       []any{"career"},
					"mood":             "warm",
					"memoryReferenced": false,
				}),
			},
		},
	}

	result := parseFinalResult(msg)

	if result.Coaching != "Test response" {
		t.Errorf("expected coaching 'Test response', got %q", result.Coaching)
	}
	if result.SafetyLevel != "green" {
		t.Errorf("expected safetyLevel green, got %q", result.SafetyLevel)
	}
	if result.Mood != "warm" {
		t.Errorf("expected mood warm, got %q", result.Mood)
	}
	if len(result.DomainTags) != 1 || result.DomainTags[0] != "career" {
		t.Errorf("expected domainTags [career], got %v", result.DomainTags)
	}
}

func TestParseFinalResult_MalformedOutput(t *testing.T) {
	// No tool_use block at all
	msg := &anthropic.Message{
		Content: []anthropic.ContentBlockUnion{
			{
				Type: "text",
			},
		},
	}

	result := parseFinalResult(msg)

	// Should return safe defaults
	if result.SafetyLevel != "green" {
		t.Errorf("expected default safetyLevel green, got %q", result.SafetyLevel)
	}
	if result.Mood != "welcoming" {
		t.Errorf("expected default mood welcoming, got %q", result.Mood)
	}
	if result.MemoryReferenced != false {
		t.Error("expected default memoryReferenced false")
	}
	if result.DomainTags == nil {
		t.Error("expected non-nil domainTags default")
	}
}

func TestParseFinalResult_MissingSafetyLevel(t *testing.T) {
	msg := &anthropic.Message{
		Content: []anthropic.ContentBlockUnion{
			{
				Type: "tool_use",
				Input: mustJSON(map[string]any{
					"coaching":         "Response",
					"safetyLevel":      "",
					"domainTags":       []any{},
					"mood":             "",
					"memoryReferenced": false,
				}),
			},
		},
	}

	result := parseFinalResult(msg)

	if result.SafetyLevel != "green" {
		t.Errorf("expected fallback safetyLevel green, got %q", result.SafetyLevel)
	}
	if result.Mood != "welcoming" {
		t.Errorf("expected fallback mood welcoming, got %q", result.Mood)
	}
}
