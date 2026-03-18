package providers

import "context"

type ChatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ChatRequest struct {
	Messages      []ChatMessage `json:"messages"`
	Mode          string        `json:"mode"`
	PromptVersion string        `json:"promptVersion"`
}

type Usage struct {
	InputTokens  int `json:"inputTokens"`
	OutputTokens int `json:"outputTokens"`
}

type ChatEvent struct {
	Type        string   `json:"type"`
	Text        string   `json:"text,omitempty"`
	SafetyLevel string   `json:"safetyLevel,omitempty"`
	DomainTags  []string `json:"domainTags,omitempty"`
	Mood        string   `json:"mood,omitempty"`
	Usage       *Usage   `json:"usage,omitempty"`
}

type Provider interface {
	StreamChat(ctx context.Context, req ChatRequest) (<-chan ChatEvent, error)
}
