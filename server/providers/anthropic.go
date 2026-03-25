package providers

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"

	"github.com/anthropics/anthropic-sdk-go"
	"github.com/anthropics/anthropic-sdk-go/option"
)

// toolSchema defines the structured output schema the model "calls" as a tool.
var toolSchema = anthropic.ToolParam{
	Name:        "respond",
	Description: anthropic.String("Respond to the user with coaching content and metadata."),
	InputSchema: anthropic.ToolInputSchemaParam{
		Properties: map[string]any{
			"coaching": map[string]any{
				"type":        "string",
				"description": "The coaching response text to send to the user.",
			},
			"safetyLevel": map[string]any{
				"type":        "string",
				"enum":        []string{"green", "yellow", "orange", "red"},
				"description": "Safety classification of the conversation.",
			},
			"domainTags": map[string]any{
				"type": "array",
				"items": map[string]any{
					"type": "string",
				},
				"description": "Domain tags for this response (career, finance, relationships, etc.).",
			},
			"mood": map[string]any{
				"type":        "string",
				"enum":        []string{"welcoming", "warm", "focused", "gentle"},
				"description": "Coach expression for this response.",
			},
			"memoryReferenced": map[string]any{
				"type":        "boolean",
				"description": "Whether prior memory/context was referenced.",
			},
			"mode": map[string]any{
				"type":        "string",
				"enum":        []string{"discovery", "directive"},
				"description": "The coaching mode for this response. Set to 'discovery' when user is exploring or uncertain, 'directive' when user has clear goals or wants action steps. Default to current mode if unclear.",
			},
			"challengerUsed": map[string]any{
				"type":        "boolean",
				"description": "Set to true when this response includes constructive pushback, alternative perspectives, or stress-testing of the user's assumptions. Set to false for normal coaching responses.",
			},
			"sprintProposal": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"name":          map[string]any{"type": "string", "description": "A short, motivating name for the sprint."},
					"steps":         map[string]any{"type": "array", "items": map[string]any{"type": "object", "properties": map[string]any{"description": map[string]any{"type": "string"}, "order": map[string]any{"type": "integer"}}, "required": []string{"description", "order"}}},
					"durationWeeks": map[string]any{"type": "integer", "description": "Sprint duration in weeks (1-4)."},
				},
				"required":    []string{"name", "steps", "durationWeeks"},
				"description": "Propose a sprint when the user has discussed clear goals and would benefit from an action plan. Do NOT propose sprints when safety level is elevated (orange/red). Only propose when the conversation naturally leads to it.",
			},
			"profileUpdate": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"values":            map[string]any{"type": "array", "items": map[string]any{"type": "string"}, "description": "New or updated user values to add to profile."},
					"goals":             map[string]any{"type": "array", "items": map[string]any{"type": "string"}, "description": "New or updated user goals to add to profile."},
					"personalityTraits": map[string]any{"type": "array", "items": map[string]any{"type": "string"}, "description": "New personality traits observed."},
					"domainStates":      map[string]any{"type": "object", "description": "Domain state updates as {domain: {key: value}}."},
					"corrections":       map[string]any{"type": "array", "items": map[string]any{"type": "string"}, "description": "Explicit corrections the user made about their situation."},
				},
				"description": "Only emit when the user reveals new facts about themselves or corrects your understanding. Do NOT emit for normal conversation.",
			},
		},
		Required: []string{"coaching", "safetyLevel", "domainTags", "mood", "memoryReferenced", "mode", "challengerUsed"},
	},
}

// summarizeToolSchema defines the structured output schema for conversation summarization.
var summarizeToolSchema = anthropic.ToolParam{
	Name:        "summarize_conversation",
	Description: anthropic.String("Extract a structured summary from a coaching conversation."),
	InputSchema: anthropic.ToolInputSchemaParam{
		Properties: map[string]any{
			"summary": map[string]any{
				"type":        "string",
				"description": "2-4 sentence substantive summary capturing the essence of the exchange.",
			},
			"keyMoments": map[string]any{
				"type":        "array",
				"items":       map[string]any{"type": "string"},
				"description": "1-5 turning points, breakthroughs, or important realizations.",
			},
			"domainTags": map[string]any{
				"type": "array",
				"items": map[string]any{
					"type": "string",
					"enum": []string{
						"career", "relationships", "health", "finance",
						"personal-growth", "creativity", "education", "family",
					},
				},
				"description": "1-3 life domains this conversation touches.",
			},
			"emotionalMarkers": map[string]any{
				"type":        "array",
				"items":       map[string]any{"type": "string"},
				"description": "Emotional trajectory markers (e.g., frustrated, hopeful, relieved).",
			},
			"keyDecisions": map[string]any{
				"type":        "array",
				"items":       map[string]any{"type": "string"},
				"description": "Decisions or commitments the user made during the session.",
			},
		},
		Required: []string{"summary", "keyMoments", "domainTags"},
	},
}

// summarizeResult is the parsed output from the summarize tool call.
type summarizeResult struct {
	Summary          string   `json:"summary"`
	KeyMoments       []string `json:"keyMoments"`
	DomainTags       []string `json:"domainTags"`
	EmotionalMarkers []string `json:"emotionalMarkers,omitempty"`
	KeyDecisions     []string `json:"keyDecisions,omitempty"`
}

// toolResult is the parsed structured output from the model's tool call.
type toolResult struct {
	Coaching         string           `json:"coaching"`
	SafetyLevel      string           `json:"safetyLevel"`
	DomainTags       []string         `json:"domainTags"`
	Mood             string           `json:"mood"`
	MemoryReferenced bool             `json:"memoryReferenced"`
	Mode             string           `json:"mode"`
	ChallengerUsed   bool             `json:"challengerUsed"`
	SprintProposal   json.RawMessage  `json:"sprintProposal,omitempty"`
	ProfileUpdate    json.RawMessage  `json:"profileUpdate,omitempty"`
}

// AnthropicProvider implements Provider using the Anthropic API.
type AnthropicProvider struct {
	client *anthropic.Client
	model  anthropic.Model
}

// NewAnthropicProvider creates a new Anthropic provider with auto-retries disabled.
func NewAnthropicProvider(apiKey string) *AnthropicProvider {
	client := anthropic.NewClient(
		option.WithAPIKey(apiKey),
		option.WithMaxRetries(0),
	)
	return &AnthropicProvider{
		client: &client,
		model:  anthropic.ModelClaudeHaiku4_5,
	}
}

func (p *AnthropicProvider) StreamChat(ctx context.Context, req ChatRequest) (<-chan ChatEvent, error) {
	messages := make([]anthropic.MessageParam, 0, len(req.Messages))
	for _, m := range req.Messages {
		switch m.Role {
		case "user":
			messages = append(messages, anthropic.NewUserMessage(
				anthropic.NewTextBlock(m.Content),
			))
		case "assistant":
			messages = append(messages, anthropic.NewAssistantMessage(
				anthropic.NewTextBlock(m.Content),
			))
		}
	}

	// Select tool schema based on mode
	activeToolSchema := toolSchema
	activeToolName := "respond"
	if req.Mode == "summarize" {
		activeToolSchema = summarizeToolSchema
		activeToolName = "summarize_conversation"
	}

	params := anthropic.MessageNewParams{
		Model:     p.model,
		MaxTokens: int64(1024),
		Messages:  messages,
		Tools:     []anthropic.ToolUnionParam{{OfTool: &activeToolSchema}},
		ToolChoice: anthropic.ToolChoiceUnionParam{
			OfTool: &anthropic.ToolChoiceToolParam{
				Name: activeToolName,
			},
		},
	}

	if req.SystemPrompt != "" {
		params.System = []anthropic.TextBlockParam{
			{Text: req.SystemPrompt},
		}
	}

	isSummarize := req.Mode == "summarize"
	stream := p.client.Messages.NewStreaming(ctx, params)

	// Check for immediate errors (e.g. 429, 500) before starting the goroutine.
	// If the first Next() call fails, return the error to the caller so the
	// handler can translate it into a warm user-facing response.
	if !stream.Next() {
		stream.Close()
		if err := stream.Err(); err != nil {
			return nil, fmt.Errorf("anthropic.StreamChat: %w", err)
		}
		// Stream completed with zero events — return empty channel
		ch := make(chan ChatEvent)
		close(ch)
		return ch, nil
	}

	ch := make(chan ChatEvent)

	go func() {
		defer close(ch)
		defer stream.Close()

		var jsonBuf strings.Builder
		var lastCoachingLen int
		message := anthropic.Message{}

		// Process the first event that was already read above
		processEvent := func(event anthropic.MessageStreamEventUnion) {
			message.Accumulate(event)

			switch event.AsAny().(type) {
			case anthropic.ContentBlockDeltaEvent:
				delta := event.AsAny().(anthropic.ContentBlockDeltaEvent)
				if delta.Delta.PartialJSON != "" {
					jsonBuf.WriteString(delta.Delta.PartialJSON)

					if !isSummarize {
						text := extractCoachingChunk(jsonBuf.String(), &lastCoachingLen)
						if text != "" {
							select {
							case <-ctx.Done():
								return
							case ch <- ChatEvent{Type: "token", Text: text}:
							}
						}
					}
				}

			case anthropic.MessageStopEvent:
				if isSummarize {
					summaryData := parseSummarizeResult(&message)

					select {
					case <-ctx.Done():
						return
					case ch <- ChatEvent{
						Type:        "done",
						SummaryData: summaryData,
					}:
					}
				} else {
					result := parseFinalResult(&message)

					usage := &Usage{}
					if message.Usage.InputTokens > 0 || message.Usage.OutputTokens > 0 {
						usage.InputTokens = int(message.Usage.InputTokens)
						usage.OutputTokens = int(message.Usage.OutputTokens)
					}

					// Emit sprint_proposal event before done if present and valid
					if len(result.SprintProposal) > 0 {
						var proposal struct {
							Name          string `json:"name"`
							Steps         []any  `json:"steps"`
							DurationWeeks int    `json:"durationWeeks"`
						}
						if err := json.Unmarshal(result.SprintProposal, &proposal); err != nil {
							slog.Warn("malformed sprint_proposal in response, skipping", "error", err)
						} else if proposal.Name != "" && len(proposal.Steps) > 0 && proposal.DurationWeeks > 0 {
							select {
							case <-ctx.Done():
								return
							case ch <- ChatEvent{Type: "sprint_proposal", SprintProposal: result.SprintProposal}:
							}
						} else {
							slog.Warn("incomplete sprint_proposal, skipping", "name", proposal.Name, "steps", len(proposal.Steps), "weeks", proposal.DurationWeeks)
						}
					}

					select {
					case <-ctx.Done():
						return
					case ch <- ChatEvent{
						Type:             "done",
						SafetyLevel:      result.SafetyLevel,
						DomainTags:       result.DomainTags,
						Mood:             result.Mood,
						Mode:             func() string { if result.Mode != "" { return result.Mode }; return req.Mode }(),
						MemoryReferenced: result.MemoryReferenced,
						ChallengerUsed:   result.ChallengerUsed,
						Usage:            usage,
						ProfileUpdate:    result.ProfileUpdate,
					}:
					}
				}
			}
		}

		// Process the first event
		processEvent(stream.Current())

		for stream.Next() {
			select {
			case <-ctx.Done():
				return
			default:
			}
			processEvent(stream.Current())
		}

		if err := stream.Err(); err != nil {
			slog.Warn("anthropic.StreamChat: mid-stream error", "error", err)
		}
	}()

	return ch, nil
}

// parseSummarizeResult extracts structured summary output from the final accumulated message.
func parseSummarizeResult(message *anthropic.Message) *summarizeResult {
	for _, block := range message.Content {
		if block.Type == "tool_use" {
			var result summarizeResult
			if err := json.Unmarshal(block.Input, &result); err != nil {
				slog.Warn("anthropic.parseSummarizeResult: failed to parse tool result", "error", err)
				return nil
			}
			return &result
		}
	}

	slog.Warn("anthropic.parseSummarizeResult: no tool_use block found in response")
	return nil
}

// extractCoachingChunk extracts new coaching text from the partial JSON buffer.
// It tracks how much coaching text was previously emitted via lastLen.
func extractCoachingChunk(partialJSON string, lastLen *int) string {
	// Look for the coaching value in the partial JSON
	// The JSON builds up progressively: {"coaching":"Hello, let's talk..."
	const prefix = `"coaching":"`

	idx := strings.Index(partialJSON, prefix)
	if idx == -1 {
		return ""
	}

	// Start of the coaching value
	valueStart := idx + len(prefix)
	rest := partialJSON[valueStart:]

	// Find the end of the coaching string value
	// Walk through the string handling escape sequences
	var coachingText strings.Builder
	i := 0
	for i < len(rest) {
		if rest[i] == '\\' && i+1 < len(rest) {
			// Handle escape sequences
			switch rest[i+1] {
			case '"':
				coachingText.WriteByte('"')
			case '\\':
				coachingText.WriteByte('\\')
			case 'n':
				coachingText.WriteByte('\n')
			case 'r':
				coachingText.WriteByte('\r')
			case 't':
				coachingText.WriteByte('\t')
			default:
				coachingText.WriteByte(rest[i])
				coachingText.WriteByte(rest[i+1])
			}
			i += 2
		} else if rest[i] == '"' {
			// End of string value
			break
		} else {
			coachingText.WriteByte(rest[i])
			i++
		}
	}

	full := coachingText.String()
	if len(full) > *lastLen {
		chunk := full[*lastLen:]
		*lastLen = len(full)
		return chunk
	}
	return ""
}

// parseFinalResult extracts structured output from the final accumulated message.
// Falls back to safe defaults on malformed output.
func parseFinalResult(message *anthropic.Message) toolResult {
	defaults := toolResult{
		SafetyLevel:      "green",
		Mood:             "welcoming",
		MemoryReferenced: false,
		DomainTags:       []string{},
	}

	for _, block := range message.Content {
		if block.Type == "tool_use" {
			var result toolResult
			if err := json.Unmarshal(block.Input, &result); err != nil {
				slog.Warn("anthropic.parseFinalResult: failed to parse tool result", "error", err)
				return defaults
			}

			// Validate required fields, fall back to defaults
			if result.SafetyLevel == "" {
				result.SafetyLevel = defaults.SafetyLevel
			}
			if result.Mood == "" {
				result.Mood = defaults.Mood
			}
			if result.DomainTags == nil {
				result.DomainTags = defaults.DomainTags
			}

			return result
		}
	}

	slog.Warn("anthropic.parseFinalResult: no tool_use block found in response")
	return defaults
}
