package handlers

import (
	"compress/flate"
	"compress/gzip"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"

	"github.com/anthropics/anthropic-sdk-go"

	"github.com/ducdo/sprinty/server/middleware"
	"github.com/ducdo/sprinty/server/prompts"
	"github.com/ducdo/sprinty/server/providers"
)

func ChatHandler(provider providers.Provider, promptBuilder *prompts.Builder) http.HandlerFunc {
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

		// Assemble system prompt
		coachName := ""
		if req.Profile != nil {
			coachName = req.Profile.CoachName
		}
		req.SystemPrompt = promptBuilder.Build(req.Mode, coachName)

		logArgs := []any{
			"mode", req.Mode,
			"messageCount", len(req.Messages),
			"promptVersion", req.PromptVersion,
		}
		if claims, ok := middleware.ClaimsFromContext(r.Context()); ok {
			logArgs = append(logArgs, "deviceId", claims.DeviceID, "tier", claims.Tier)
		}
		slog.Info("chat.request", logArgs...)

		ch, err := provider.StreamChat(r.Context(), req)
		if err != nil {
			handleProviderError(w, err)
			return
		}

		w.Header().Set("Content-Type", "text/event-stream")
		w.Header().Set("Cache-Control", "no-cache")
		w.Header().Set("Connection", "keep-alive")
		w.WriteHeader(http.StatusOK)

		flusher, ok := w.(http.Flusher)
		if !ok {
			slog.Warn("streaming not supported")
			return
		}

		for event := range ch {
			var eventType string
			var data []byte

			switch event.Type {
			case "token":
				eventType = "token"
				data, _ = json.Marshal(map[string]string{"text": event.Text})
			case "done":
				eventType = "done"
				data, _ = json.Marshal(map[string]any{
					"safetyLevel":    event.SafetyLevel,
					"domainTags":     event.DomainTags,
					"mood":           event.Mood,
					"mode":           event.Mode,
					"challengerUsed": event.ChallengerUsed,
					"usage":          event.Usage,
					"promptVersion":  promptBuilder.ContentHash(),
				})
			default:
				continue
			}

			fmt.Fprintf(w, "event: %s\ndata: %s\n\n", eventType, data)
			flusher.Flush()
		}
	}
}

// handleProviderError translates provider errors into warm user-facing JSON responses.
func handleProviderError(w http.ResponseWriter, err error) {
	type errorResponse struct {
		Error      string `json:"error"`
		Message    string `json:"message"`
		RetryAfter int    `json:"retryAfter,omitempty"`
	}

	var apiErr *anthropic.Error
	if errors.As(err, &apiErr) {
		slog.Warn("provider error", "status", apiErr.StatusCode)

		switch apiErr.StatusCode {
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
