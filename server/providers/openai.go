package providers

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"

	"github.com/openai/openai-go"
	"github.com/openai/openai-go/option"
)

// openaiJSONSchema is the JSON schema for structured output via response_format.
// It mirrors the Anthropic tool schema fields so both providers produce identical ChatEvent output.
var openaiJSONSchema = openai.ResponseFormatJSONSchemaJSONSchemaParam{
	Name:   "respond",
	Strict: openai.Bool(true),
	Schema: map[string]any{
		"type": "object",
		"properties": map[string]any{
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
				"description": "Domain tags for this response.",
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
				"description": "The coaching mode for this response.",
			},
			"challengerUsed": map[string]any{
				"type":        "boolean",
				"description": "Whether constructive pushback was used.",
			},
			"sprintProposal": map[string]any{
				"anyOf": []any{
					map[string]any{
						"type": "object",
						"properties": map[string]any{
							"name":          map[string]any{"type": "string"},
							"steps":         map[string]any{"type": "array", "items": map[string]any{"type": "object", "properties": map[string]any{"description": map[string]any{"type": "string"}, "order": map[string]any{"type": "integer"}, "coachContext": map[string]any{"type": "string"}}, "required": []string{"description", "order"}, "additionalProperties": false}},
							"durationWeeks": map[string]any{"type": "integer"},
						},
						"required":             []string{"name", "steps", "durationWeeks"},
						"additionalProperties": false,
					},
					map[string]any{"type": "null"},
				},
				"description": "Sprint proposal if applicable.",
			},
			"profileUpdate": map[string]any{
				"anyOf": []any{
					map[string]any{
						"type": "object",
						"properties": map[string]any{
							"values":            map[string]any{"type": "array", "items": map[string]any{"type": "string"}},
							"goals":             map[string]any{"type": "array", "items": map[string]any{"type": "string"}},
							"personalityTraits": map[string]any{"type": "array", "items": map[string]any{"type": "string"}},
							"domainStates":      map[string]any{"type": "object", "additionalProperties": true},
							"corrections":       map[string]any{"type": "array", "items": map[string]any{"type": "string"}},
						},
						"additionalProperties": false,
					},
					map[string]any{"type": "null"},
				},
				"description": "Profile update if user reveals new facts.",
			},
		},
		"required":             []string{"coaching", "safetyLevel", "domainTags", "mood", "memoryReferenced", "mode", "challengerUsed"},
		"additionalProperties": false,
	},
}

// openaiSummarizeSchema is the JSON schema for conversation summarization via OpenAI.
// Mirrors the Anthropic summarizeToolSchema.
var openaiSummarizeSchema = openai.ResponseFormatJSONSchemaJSONSchemaParam{
	Name:   "summarize_conversation",
	Strict: openai.Bool(true),
	Schema: map[string]any{
		"type": "object",
		"properties": map[string]any{
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
		"required":             []string{"summary", "keyMoments", "domainTags", "emotionalMarkers", "keyDecisions"},
		"additionalProperties": false,
	},
}

// OpenAIProvider implements Provider using the OpenAI API with structured output.
type OpenAIProvider struct {
	client *openai.Client
	model  openai.ChatModel
}

// NewOpenAIProvider creates a new OpenAI provider.
func NewOpenAIProvider(apiKey string, model openai.ChatModel) *OpenAIProvider {
	client := openai.NewClient(option.WithAPIKey(apiKey))
	return &OpenAIProvider{
		client: &client,
		model:  model,
	}
}

func (p *OpenAIProvider) Name() string {
	return "openai/" + string(p.model)
}

func (p *OpenAIProvider) StreamChat(ctx context.Context, req ChatRequest) (<-chan ChatEvent, error) {
	messages := make([]openai.ChatCompletionMessageParamUnion, 0, len(req.Messages)+1)

	// OpenAI: system prompt goes in the messages array
	if req.SystemPrompt != "" {
		messages = append(messages, openai.SystemMessage(req.SystemPrompt))
	}

	for _, m := range req.Messages {
		switch m.Role {
		case "user":
			messages = append(messages, openai.UserMessage(m.Content))
		case "assistant":
			messages = append(messages, openai.AssistantMessage(m.Content))
		}
	}

	// Select schema based on mode
	activeSchema := openaiJSONSchema
	isSummarize := req.Mode == "summarize"
	if isSummarize {
		activeSchema = openaiSummarizeSchema
	}

	params := openai.ChatCompletionNewParams{
		Model:    p.model,
		Messages: messages,
		ResponseFormat: openai.ChatCompletionNewParamsResponseFormatUnion{
			OfJSONSchema: &openai.ResponseFormatJSONSchemaParam{
				JSONSchema: activeSchema,
			},
		},
	}

	stream := p.client.Chat.Completions.NewStreaming(ctx, params)

	// Early error detection — same pattern as Anthropic provider
	if !stream.Next() {
		stream.Close()
		if err := stream.Err(); err != nil {
			return nil, fmt.Errorf("openai.StreamChat: %w", err)
		}
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

		processChunk := func(chunk openai.ChatCompletionChunk) {
			if len(chunk.Choices) == 0 {
				return
			}

			delta := chunk.Choices[0].Delta.Content
			if delta != "" {
				jsonBuf.WriteString(delta)

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

			// Check for stream finish
			if chunk.Choices[0].FinishReason == "stop" || chunk.Choices[0].FinishReason == "length" {
				fullJSON := jsonBuf.String()

				if isSummarize {
					var result summarizeResult
					if err := json.Unmarshal([]byte(fullJSON), &result); err != nil {
						slog.Warn("openai.StreamChat: failed to parse summarize JSON", "error", err)
						select {
						case <-ctx.Done():
							return
						case ch <- ChatEvent{Type: "done"}:
						}
						return
					}
					select {
					case <-ctx.Done():
						return
					case ch <- ChatEvent{
						Type:        "done",
						SummaryData: &result,
					}:
					}
					return
				}

				var result toolResult
				if err := json.Unmarshal([]byte(fullJSON), &result); err != nil {
					slog.Warn("openai.StreamChat: failed to parse final JSON", "error", err)
					result = toolResult{
						SafetyLevel: "green",
						Mood:        "welcoming",
						DomainTags:  []string{},
					}
				}

				// Validate required fields
				if result.SafetyLevel == "" {
					result.SafetyLevel = "green"
				}
				if result.Mood == "" {
					result.Mood = "welcoming"
				}
				if result.DomainTags == nil {
					result.DomainTags = []string{}
				}

				usage := &Usage{}
				if chunk.Usage.PromptTokens > 0 || chunk.Usage.CompletionTokens > 0 {
					usage.InputTokens = int(chunk.Usage.PromptTokens)
					usage.OutputTokens = int(chunk.Usage.CompletionTokens)
				}

				// Emit sprint_proposal event before done if present and valid
				if len(result.SprintProposal) > 0 {
					var proposal struct {
						Name          string `json:"name"`
						Steps         []any  `json:"steps"`
						DurationWeeks int    `json:"durationWeeks"`
					}
					if err := json.Unmarshal(result.SprintProposal, &proposal); err != nil {
						slog.Warn("openai: malformed sprint_proposal, skipping", "error", err)
					} else if proposal.Name != "" && len(proposal.Steps) > 0 && proposal.DurationWeeks > 0 {
						select {
						case <-ctx.Done():
							return
						case ch <- ChatEvent{Type: "sprint_proposal", SprintProposal: result.SprintProposal}:
						}
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

		// Process first chunk already read
		processChunk(stream.Current())

		for stream.Next() {
			select {
			case <-ctx.Done():
				return
			default:
			}
			processChunk(stream.Current())
		}

		if err := stream.Err(); err != nil {
			slog.Warn("openai.StreamChat: mid-stream error", "error", err)
			select {
			case <-ctx.Done():
			case ch <- ChatEvent{Type: "error", Err: fmt.Errorf("openai.StreamChat: %w", err)}:
			}
		}
	}()

	return ch, nil
}
