package providers

import "context"

type MockProvider struct {
	StubbedMode string
}

func NewMockProvider() *MockProvider {
	return &MockProvider{}
}

func (m *MockProvider) StreamChat(ctx context.Context, req ChatRequest) (<-chan ChatEvent, error) {
	ch := make(chan ChatEvent)

	go func() {
		defer close(ch)

		tokens := []string{
			"Hey there — I'm your coach, not your therapist. ",
			"Everything we talk about stays right here on your device, just between us. ",
			"I'm here to help you figure things out, push back when you need it, and keep you moving. ",
			"So... what's on your mind? Or if nothing specific, tell me a little about what brought you here.",
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
			Type:        "done",
			SafetyLevel: "green",
			DomainTags:  []string{},
			Mood:        "welcoming",
			Mode:        func() string { if m.StubbedMode != "" { return m.StubbedMode }; return req.Mode }(),
			Usage:       &Usage{InputTokens: 50, OutputTokens: 12},
		}:
		}
	}()

	return ch, nil
}
