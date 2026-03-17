package providers

import "context"

type MockProvider struct{}

func NewMockProvider() *MockProvider {
	return &MockProvider{}
}

func (m *MockProvider) StreamChat(ctx context.Context, req ChatRequest) (<-chan ChatEvent, error) {
	ch := make(chan ChatEvent)

	go func() {
		defer close(ch)

		tokens := []string{"I hear you. ", "Let's explore that together."}
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
			Usage:       &Usage{InputTokens: 50, OutputTokens: 12},
		}:
		}
	}()

	return ch, nil
}
