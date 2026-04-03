package handlers

import (
	"compress/flate"
	"compress/gzip"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/anthropics/anthropic-sdk-go"
	"github.com/openai/openai-go"

	"github.com/ducdo/sprinty/server/middleware"
	"github.com/ducdo/sprinty/server/prompts"
	"github.com/ducdo/sprinty/server/providers"
)

// failoverResult holds the output from streamWithFailover.
type failoverResult struct {
	events   []providers.ChatEvent
	degraded bool
	err      error
}

// streamWithFailover tries providers in chain order, handling initial and mid-stream failures.
// Returns collected events (for non-streaming paths) or streams directly to eventCh (for streaming paths).
// When eventCh is non-nil, token events are forwarded in real time; when nil, all events are collected and returned.
func streamWithFailover(ctx context.Context, chain []providers.Provider, req providers.ChatRequest, eventCh chan<- providers.ChatEvent) failoverResult {
	var accumulatedTokens strings.Builder
	var accumulatedUsage providers.Usage
	degraded := false

	for i, p := range chain {
		attemptReq := req

		// If resuming after mid-stream failure, build continuation request
		if accumulatedTokens.Len() > 0 {
			attemptReq.Messages = append(append([]providers.ChatMessage{}, req.Messages...), providers.ChatMessage{
				Role:    "assistant",
				Content: accumulatedTokens.String(),
			})
			attemptReq.SystemPrompt = req.SystemPrompt + "\n\nContinue the response seamlessly from where it was interrupted. Do not repeat any prior content."
		}

		// Per-provider timeout: ~4s for primary, ~4s for fallback
		attemptCtx, cancel := context.WithTimeout(ctx, 4*time.Second)

		ch, err := p.StreamChat(attemptCtx, attemptReq)
		if err != nil {
			cancel()

			// Rate limit: do NOT failover — return immediately
			if isRateLimitError(err) {
				return failoverResult{err: err}
			}

			if i < len(chain)-1 {
				slog.Warn("provider.failover", "from", p.Name(), "to", chain[i+1].Name(), "reason", err)
				degraded = true
				continue
			}
			return failoverResult{err: err}
		}

		// Stream events from this provider
		midStreamErr := false
		var collectedEvents []providers.ChatEvent

		for event := range ch {
			if event.Type == "error" && event.Err != nil {
				// Rate limit mid-stream: unlikely but handle it
				if isRateLimitError(event.Err) {
					cancel()
					return failoverResult{err: event.Err}
				}

				midStreamErr = true
				if i < len(chain)-1 {
					slog.Warn("provider.failover", "from", p.Name(), "to", chain[i+1].Name(), "reason", event.Err)
					degraded = true
				}
				break
			}

			if event.Type == "token" {
				accumulatedTokens.WriteString(event.Text)
			}

			if event.Type == "done" && event.Usage != nil {
				accumulatedUsage.InputTokens += event.Usage.InputTokens
				accumulatedUsage.OutputTokens += event.Usage.OutputTokens
			}

			if eventCh != nil && (event.Type == "token" || event.Type == "sprint_proposal") {
				select {
				case <-ctx.Done():
					cancel()
					return failoverResult{err: ctx.Err()}
				case eventCh <- event:
				}
			} else {
				collectedEvents = append(collectedEvents, event)
			}
		}

		cancel()

		if midStreamErr {
			if i < len(chain)-1 {
				continue
			}
			return failoverResult{err: fmt.Errorf("all providers failed")}
		}

		// Success — apply degraded flag and merged usage to done events
		for j := range collectedEvents {
			if collectedEvents[j].Type == "done" {
				if degraded {
					collectedEvents[j].Degraded = true
				}
				if accumulatedUsage.InputTokens > 0 || accumulatedUsage.OutputTokens > 0 {
					collectedEvents[j].Usage = &providers.Usage{
						InputTokens:  accumulatedUsage.InputTokens,
						OutputTokens: accumulatedUsage.OutputTokens,
					}
				}
			}
		}

		// Streaming path: forward remaining collected events (done, etc.) to caller
		if eventCh != nil {
			for _, event := range collectedEvents {
				select {
				case <-ctx.Done():
					return failoverResult{err: ctx.Err()}
				case eventCh <- event:
				}
			}
			return failoverResult{degraded: degraded}
		}

		return failoverResult{events: collectedEvents, degraded: degraded}
	}

	return failoverResult{err: fmt.Errorf("all providers failed")}
}

// isRateLimitError checks if an error is a 429 rate limit from any provider SDK.
func isRateLimitError(err error) bool {
	var anthropicErr *anthropic.Error
	if errors.As(err, &anthropicErr) && anthropicErr.StatusCode == 429 {
		return true
	}
	var openaiErr *openai.Error
	if errors.As(err, &openaiErr) && openaiErr.StatusCode == 429 {
		return true
	}
	return false
}

func ChatHandler(promptBuilder *prompts.Builder) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Gzip/deflate request body decompression
		body := r.Body
		switch r.Header.Get("Content-Encoding") {
		case "gzip":
			gr, err := gzip.NewReader(r.Body)
			if err != nil {
				WriteError(w, http.StatusBadRequest, "malformed_request", "Invalid gzip encoding.")
				return
			}
			defer gr.Close()
			body = gr
		case "deflate":
			body = flate.NewReader(r.Body)
			defer body.Close()
		}

		var req providers.ChatRequest
		if err := json.NewDecoder(body).Decode(&req); err != nil {
			WriteError(w, http.StatusBadRequest, "malformed_request", "Request body must be valid JSON.")
			return
		}

		// Get provider chain from context
		chain, ok := middleware.ProviderChainFromContext(r.Context())
		if !ok {
			// Fallback to single provider for backward compatibility
			provider, pOk := middleware.ProviderFromContext(r.Context())
			if !pOk {
				WriteError(w, http.StatusInternalServerError, "provider_unavailable", "Your coach needs a moment. Try again shortly.")
				return
			}
			chain = []providers.Provider{provider}
		}

		// Route summarize mode to non-streaming handler
		if req.Mode == "summarize" {
			handleSummarize(w, r, req, chain, promptBuilder)
			return
		}

		// Route sprint_retro mode to streaming retro handler
		if req.Mode == "sprint_retro" {
			handleSprintRetro(w, r, req, chain, promptBuilder)
			return
		}

		// Assemble system prompt
		coachName := ""
		if req.Profile != nil {
			coachName = req.Profile.CoachName
		}
		req.SystemPrompt = promptBuilder.Build(req.Mode, coachName, req.Profile, req.UserState, req.RagContext, req.SprintContext)

		// Check guardrail flag from middleware
		guardrailActive := middleware.GuardrailActiveFromContext(r.Context())
		if guardrailActive {
			req.SystemPrompt += prompts.GuardrailAddendum
		}

		logArgs := []any{
			"mode", req.Mode,
			"messageCount", len(req.Messages),
			"promptVersion", req.PromptVersion,
			"provider", chain[0].Name(),
			"chainLen", len(chain),
		}
		if claims, ok := middleware.ClaimsFromContext(r.Context()); ok {
			logArgs = append(logArgs, "deviceId", claims.DeviceID, "tier", claims.Tier)
		}
		slog.Info("chat.request", logArgs...)

		// Stream with failover — use event channel for real-time streaming to client
		eventCh := make(chan providers.ChatEvent, 16)

		// Start failover in background
		resultCh := make(chan failoverResult, 1)
		go func() {
			resultCh <- streamWithFailover(r.Context(), chain, req, eventCh)
			close(eventCh)
		}()

		// Wait for first event or error to decide whether to write SSE headers
		headerWritten := false

		for event := range eventCh {
			if !headerWritten {
				w.Header().Set("Content-Type", "text/event-stream")
				w.Header().Set("Cache-Control", "no-cache")
				w.Header().Set("Connection", "keep-alive")
				w.WriteHeader(http.StatusOK)
				headerWritten = true
			}

			flusher, ok := w.(http.Flusher)
			if !ok {
				slog.Warn("streaming not supported")
				return
			}

			var eventType string
			var data []byte

			switch event.Type {
			case "token":
				eventType = "token"
				data, _ = json.Marshal(map[string]string{"text": event.Text})
			case "sprint_proposal":
				eventType = "sprint_proposal"
				if !json.Valid(event.SprintProposal) {
					slog.Warn("invalid JSON in sprint_proposal event, skipping")
					continue
				}
				data = event.SprintProposal
			case "done":
				eventType = "done"
				donePayload := map[string]any{
					"safetyLevel":      event.SafetyLevel,
					"domainTags":       event.DomainTags,
					"mood":             event.Mood,
					"mode":             event.Mode,
					"memoryReferenced": event.MemoryReferenced,
					"challengerUsed":   event.ChallengerUsed,
					"usage":            event.Usage,
					"promptVersion":    promptBuilder.ContentHash(),
				}
				if event.Degraded {
					donePayload["degraded"] = true
				}
				if guardrailActive && (event.SafetyLevel == "green" || event.SafetyLevel == "") {
					donePayload["guardrail"] = true
				}
				if len(event.ProfileUpdate) > 0 {
					donePayload["profileUpdate"] = json.RawMessage(event.ProfileUpdate)
				}
				data, _ = json.Marshal(donePayload)

				// Compliance logging: non-green safety levels
				if event.SafetyLevel != "green" && event.SafetyLevel != "" {
					deviceID := ""
					tier := ""
					if claims, ok := middleware.ClaimsFromContext(r.Context()); ok {
						deviceID = claims.DeviceID
						tier = claims.Tier
					}
					slog.Info("compliance.safety_boundary",
						"safetyLevel", event.SafetyLevel,
						"deviceId", deviceID,
						"tier", tier,
						"mode", req.Mode,
					)
				}
			default:
				continue
			}

			fmt.Fprintf(w, "event: %s\ndata: %s\n\n", eventType, data)
			flusher.Flush()
		}

		// Check failover result for errors (only matters if no events were sent)
		result := <-resultCh
		if result.err != nil && !headerWritten {
			handleProviderError(w, result.err)
		}
	}
}

// handleSummarize processes summarize mode requests, returning a single JSON response.
func handleSummarize(w http.ResponseWriter, r *http.Request, req providers.ChatRequest, chain []providers.Provider, promptBuilder *prompts.Builder) {
	req.SystemPrompt = promptBuilder.SummarizePrompt()
	req.Mode = "summarize"

	logArgs := []any{
		"mode", "summarize",
		"messageCount", len(req.Messages),
	}
	if claims, ok := middleware.ClaimsFromContext(r.Context()); ok {
		logArgs = append(logArgs, "deviceId", claims.DeviceID)
	}
	slog.Info("chat.summarize", logArgs...)

	result := streamWithFailover(r.Context(), chain, req, nil)
	if result.err != nil {
		handleProviderError(w, result.err)
		return
	}

	// Find the done event with summary data
	for _, event := range result.events {
		if event.Type == "done" && event.SummaryData != nil {
			WriteJSON(w, http.StatusOK, event.SummaryData)
			return
		}
	}

	// Fallback: return empty summary
	WriteJSON(w, http.StatusOK, map[string]any{
		"summary":    "",
		"keyMoments": []string{},
		"domainTags": []string{},
	})
}

// handleSprintRetro processes sprint_retro mode requests, streaming the narrative retro.
func handleSprintRetro(w http.ResponseWriter, r *http.Request, req providers.ChatRequest, chain []providers.Provider, promptBuilder *prompts.Builder) {
	sprintName := ""
	durationDays := 0
	var retroSteps []prompts.SprintRetroStep

	if req.SprintContext != nil {
		if req.SprintContext.ActiveSprint != nil {
			sprintName = req.SprintContext.ActiveSprint.Name
			durationDays = req.SprintContext.ActiveSprint.TotalDays
		}
		for _, s := range req.SprintContext.RetroSteps {
			retroSteps = append(retroSteps, prompts.SprintRetroStep{
				Description:  s.Description,
				CoachContext: s.CoachContext,
			})
		}
	}

	if len(retroSteps) == 0 {
		WriteError(w, http.StatusBadRequest, "invalid_request", "Sprint retro requires step descriptions.")
		return
	}

	req.SystemPrompt = promptBuilder.SprintRetroPrompt(sprintName, durationDays, retroSteps)
	req.Mode = "sprint_retro"

	logArgs := []any{
		"mode", "sprint_retro",
		"sprintName", sprintName,
		"stepCount", len(retroSteps),
	}
	if claims, ok := middleware.ClaimsFromContext(r.Context()); ok {
		logArgs = append(logArgs, "deviceId", claims.DeviceID)
	}
	slog.Info("chat.sprint_retro", logArgs...)

	// Stream with failover
	eventCh := make(chan providers.ChatEvent, 16)

	resultCh := make(chan failoverResult, 1)
	go func() {
		resultCh <- streamWithFailover(r.Context(), chain, req, eventCh)
		close(eventCh)
	}()

	headerWritten := false

	for event := range eventCh {
		if !headerWritten {
			w.Header().Set("Content-Type", "text/event-stream")
			w.Header().Set("Cache-Control", "no-cache")
			w.Header().Set("Connection", "keep-alive")
			w.WriteHeader(http.StatusOK)
			headerWritten = true
		}

		flusher, ok := w.(http.Flusher)
		if !ok {
			slog.Warn("streaming not supported")
			return
		}

		var eventType string
		var data []byte

		switch event.Type {
		case "token":
			eventType = "token"
			data, _ = json.Marshal(map[string]string{"text": event.Text})
		case "done":
			eventType = "done"
			data, _ = json.Marshal(map[string]any{
				"safetyLevel": "green",
				"domainTags":  []string{},
				"usage":       event.Usage,
			})
		default:
			continue
		}

		fmt.Fprintf(w, "event: %s\ndata: %s\n\n", eventType, data)
		flusher.Flush()
	}

	result := <-resultCh
	if result.err != nil && !headerWritten {
		handleProviderError(w, result.err)
	}
}

// handleProviderError translates provider errors into warm user-facing JSON responses.
func handleProviderError(w http.ResponseWriter, err error) {
	type errorResponse struct {
		Error      string `json:"error"`
		Message    string `json:"message"`
		RetryAfter int    `json:"retryAfter,omitempty"`
	}

	// Check for Anthropic errors
	var anthropicErr *anthropic.Error
	if errors.As(err, &anthropicErr) {
		slog.Warn("provider error", "provider", "anthropic", "status", anthropicErr.StatusCode)

		switch anthropicErr.StatusCode {
		case 429:
			WriteJSON(w, http.StatusTooManyRequests, errorResponse{
				Error:      "rate_limited",
				Message:    "Your coach needs a moment. Try again shortly.",
				RetryAfter: 30,
			})
		default:
			WriteJSON(w, http.StatusBadGateway, errorResponse{
				Error:      "provider_unavailable",
				Message:    "Your coach needs a moment. Try again shortly.",
				RetryAfter: 10,
			})
		}
		return
	}

	// Check for OpenAI errors
	var openaiErr *openai.Error
	if errors.As(err, &openaiErr) {
		slog.Warn("provider error", "provider", "openai", "status", openaiErr.StatusCode)

		switch openaiErr.StatusCode {
		case 429:
			WriteJSON(w, http.StatusTooManyRequests, errorResponse{
				Error:      "rate_limited",
				Message:    "Your coach needs a moment. Try again shortly.",
				RetryAfter: 30,
			})
		default:
			WriteJSON(w, http.StatusBadGateway, errorResponse{
				Error:      "provider_unavailable",
				Message:    "Your coach needs a moment. Try again shortly.",
				RetryAfter: 10,
			})
		}
		return
	}

	slog.Warn("provider error", "error", err)
	WriteJSON(w, http.StatusBadGateway, errorResponse{
		Error:      "provider_unavailable",
		Message:    "Your coach needs a moment. Try again shortly.",
		RetryAfter: 10,
	})
}

// Ensure body is an io.ReadCloser for flate reader compatibility.
var _ io.ReadCloser = flate.NewReader(nil)
