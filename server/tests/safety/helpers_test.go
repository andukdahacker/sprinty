//go:build safety

package safety

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/ducdo/sprinty/server/prompts"
	"github.com/ducdo/sprinty/server/providers"
)

const (
	perPromptTimeout = 10 * time.Second
	testCoachName    = "Coach"
	testMode         = "discovery"
)

// skipIfNoAPIKey skips the test if ANTHROPIC_API_KEY is not set.
func skipIfNoAPIKey(t *testing.T) string {
	t.Helper()
	key := os.Getenv("ANTHROPIC_API_KEY")
	if key == "" {
		t.Skip("ANTHROPIC_API_KEY not set — skipping safety regression tests")
	}
	return key
}

// newProvider creates a real AnthropicProvider for safety testing.
func newProvider(t *testing.T, apiKey string) *providers.AnthropicProvider {
	t.Helper()
	return providers.NewAnthropicProvider(apiKey)
}

// newPromptBuilder creates a prompt builder using the real section files.
func newPromptBuilder(t *testing.T) *prompts.Builder {
	t.Helper()
	builder, err := prompts.NewBuilder("../../prompts/sections")
	if err != nil {
		t.Fatalf("failed to create prompt builder: %v", err)
	}
	return builder
}

// buildSystemPrompt assembles a system prompt for safety testing using discovery mode.
func buildSystemPrompt(t *testing.T, builder *prompts.Builder) string {
	t.Helper()
	return builder.Build(testMode, testCoachName, nil, nil, "", nil)
}

// buildChatRequest creates a ChatRequest for a single user message in discovery mode.
func buildChatRequest(userMessage string, systemPrompt string) providers.ChatRequest {
	return providers.ChatRequest{
		Messages: []providers.ChatMessage{
			{Role: "user", Content: userMessage},
		},
		Mode:         testMode,
		SystemPrompt: systemPrompt,
	}
}

// classifyPrompt sends a prompt to the Anthropic provider and returns the safety level from the done event.
// Returns the safety level string and any error encountered.
func classifyPrompt(t *testing.T, provider *providers.AnthropicProvider, req providers.ChatRequest) (string, error) {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), perPromptTimeout)
	defer cancel()

	ch, err := provider.StreamChat(ctx, req)
	if err != nil {
		return "", err
	}

	for event := range ch {
		if event.Type == "done" {
			return event.SafetyLevel, nil
		}
	}

	return "", context.DeadlineExceeded
}

// classifyPromptFull sends a prompt and returns the safety level and sprint proposal from the done event.
func classifyPromptFull(t *testing.T, provider *providers.AnthropicProvider, req providers.ChatRequest) (string, []byte, error) {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), perPromptTimeout)
	defer cancel()

	ch, err := provider.StreamChat(ctx, req)
	if err != nil {
		return "", nil, err
	}

	for event := range ch {
		if event.Type == "done" {
			return event.SafetyLevel, event.SprintProposal, nil
		}
	}

	return "", nil, context.DeadlineExceeded
}
