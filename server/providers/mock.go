package providers

import (
	"context"
	"fmt"
)

type MockProvider struct {
	StubbedMode           string
	StubbedChallengerUsed bool
	StubbedSafetyLevel    string

	// Error injection for failover testing
	StubbedError     error
	FailAfterNTokens int
}

func NewMockProvider() *MockProvider {
	return &MockProvider{}
}

func (m *MockProvider) Name() string {
	return "mock"
}

func (m *MockProvider) StreamChat(ctx context.Context, req ChatRequest) (<-chan ChatEvent, error) {
	// Immediate error — simulates provider returning error before streaming
	if m.StubbedError != nil && m.FailAfterNTokens <= 0 {
		return nil, fmt.Errorf("mock.StreamChat: %w", m.StubbedError)
	}

	ch := make(chan ChatEvent)

	go func() {
		defer close(ch)

		// Handle check_in mode with brief response
		if req.Mode == "check_in" {
			checkInTokens := []string{
				"You're showing up, and that matters. ",
				"Keep that momentum going.",
			}
			for _, text := range checkInTokens {
				select {
				case <-ctx.Done():
					return
				case ch <- ChatEvent{Type: "token", Text: text}:
				}
			}
			select {
			case <-ctx.Done():
				return
			case ch <- ChatEvent{
				Type:        "done",
				SafetyLevel: "green",
				DomainTags:  []string{},
				Mood:        "supportive",
				Mode:        "check_in",
				Usage:       &Usage{InputTokens: 30, OutputTokens: 15},
			}:
			}
			return
		}

		// Handle sprint_retro mode with streaming tokens
		if req.Mode == "sprint_retro" {
			retroTokens := []string{
				"Here's the chapter we just finished... ",
				"You set out to grow, and that's exactly what happened. ",
				"Each step built on the last, and now you can see how far you've come.",
			}
			for _, text := range retroTokens {
				select {
				case <-ctx.Done():
					return
				case ch <- ChatEvent{Type: "token", Text: text}:
				}
			}
			select {
			case <-ctx.Done():
				return
			case ch <- ChatEvent{
				Type:        "done",
				SafetyLevel: "green",
				DomainTags:  []string{},
				Usage:       &Usage{InputTokens: 30, OutputTokens: 25},
			}:
			}
			return
		}

		// Handle summarize mode with a direct JSON response
		if req.Mode == "summarize" {
			select {
			case <-ctx.Done():
				return
			case ch <- ChatEvent{
				Type: "done",
				SummaryData: map[string]any{
					"summary":          "The user explored career concerns and identified a pattern of avoiding difficult conversations.",
					"keyMoments":       []string{"realized avoidance pattern", "committed to having the conversation"},
					"domainTags":       []string{"career", "personal-growth"},
					"emotionalMarkers": []string{"anxious", "determined"},
					"keyDecisions":     []string{"will schedule the meeting this week"},
				},
			}:
			}
			return
		}

		tokens := []string{
			"Hey there — I'm your coach, not your therapist. ",
			"Everything we talk about stays right here on your device, just between us. ",
			"I'm here to help you figure things out, push back when you need it, and keep you moving. ",
			"So... what's on your mind? Or if nothing specific, tell me a little about what brought you here.",
		}

		// Mid-stream error injection: send N tokens then error
		if m.FailAfterNTokens > 0 && m.StubbedError != nil {
			for i := 0; i < m.FailAfterNTokens && i < len(tokens); i++ {
				select {
				case <-ctx.Done():
					return
				case ch <- ChatEvent{Type: "token", Text: tokens[i]}:
				}
			}
			select {
			case <-ctx.Done():
				return
			case ch <- ChatEvent{Type: "error", Err: m.StubbedError}:
			}
			return
		}

		for _, text := range tokens {
			select {
			case <-ctx.Done():
				return
			case ch <- ChatEvent{Type: "token", Text: text}:
			}
		}

		select {
		case <-ctx.Done():
			return
		case ch <- ChatEvent{
			Type:           "done",
			SafetyLevel:    func() string { if m.StubbedSafetyLevel != "" { return m.StubbedSafetyLevel }; return "green" }(),
			DomainTags:     []string{},
			Mood:           "welcoming",
			Mode:           func() string { if m.StubbedMode != "" { return m.StubbedMode }; return req.Mode }(),
			ChallengerUsed: m.StubbedChallengerUsed,
			Usage:          &Usage{InputTokens: 50, OutputTokens: 12},
		}:
		}
	}()

	return ch, nil
}
