package providers

import (
	"context"
	"encoding/json"
)

type ChatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type DomainState struct {
	Status            string `json:"status,omitempty"`
	ConversationCount int    `json:"conversationCount,omitempty"`
	LastUpdated       string `json:"lastUpdated,omitempty"`
}

type ChatProfile struct {
	CoachName        string                  `json:"coachName"`
	Values           []string                `json:"values,omitempty"`
	Goals            []string                `json:"goals,omitempty"`
	PersonalityTraits []string               `json:"personalityTraits,omitempty"`
	DomainStates     map[string]DomainState  `json:"domainStates,omitempty"`
}

type UserState struct {
	EngagementLevel        string   `json:"engagementLevel"`
	RecentMoods            []string `json:"recentMoods"`
	AvgMessageLength       string   `json:"avgMessageLength"`
	SessionCount           int      `json:"sessionCount"`
	LastSessionGapHours    *int     `json:"lastSessionGapHours,omitempty"`
	RecentSessionIntensity string   `json:"recentSessionIntensity"`
}

type ChatRequest struct {
	Messages      []ChatMessage `json:"messages"`
	Mode          string        `json:"mode"`
	PromptVersion string        `json:"promptVersion"`
	SystemPrompt  string        `json:"systemPrompt,omitempty"`
	Profile       *ChatProfile  `json:"profile,omitempty"`
	UserState     *UserState    `json:"userState,omitempty"`
}

type Usage struct {
	InputTokens  int `json:"inputTokens"`
	OutputTokens int `json:"outputTokens"`
}

type ChatEvent struct {
	Type             string          `json:"type"`
	Text             string          `json:"text,omitempty"`
	SafetyLevel      string          `json:"safetyLevel,omitempty"`
	DomainTags       []string        `json:"domainTags,omitempty"`
	Mood             string          `json:"mood,omitempty"`
	Mode             string          `json:"mode,omitempty"`
	MemoryReferenced bool            `json:"memoryReferenced,omitempty"`
	ChallengerUsed   bool            `json:"challengerUsed,omitempty"`
	Usage            *Usage          `json:"usage,omitempty"`
	SummaryData      any             `json:"summaryData,omitempty"`
	ProfileUpdate    json.RawMessage `json:"profileUpdate,omitempty"`
}

type Provider interface {
	StreamChat(ctx context.Context, req ChatRequest) (<-chan ChatEvent, error)
}
