package handlers

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"

	"github.com/ducdo/ai-life-coach/server/providers"
)

func ChatHandler(provider providers.Provider) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req providers.ChatRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			WriteError(w, http.StatusBadRequest, "malformed_request", "Request body must be valid JSON.")
			return
		}

		ch, err := provider.StreamChat(r.Context(), req)
		if err != nil {
			slog.Warn("provider error", "error", err)
			WriteError(w, http.StatusBadGateway, "provider_unavailable", "Coaching service is temporarily unavailable.")
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
					"safetyLevel": event.SafetyLevel,
					"domainTags":  event.DomainTags,
					"usage":       event.Usage,
				})
			default:
				continue
			}

			fmt.Fprintf(w, "event: %s\ndata: %s\n\n", eventType, data)
			flusher.Flush()
		}
	}
}
