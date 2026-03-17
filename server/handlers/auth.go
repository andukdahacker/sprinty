package handlers

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/ducdo/ai-life-coach/server/auth"
	"github.com/ducdo/ai-life-coach/server/middleware"
)

type registerRequest struct {
	DeviceID string `json:"deviceId"`
}

type tokenResponse struct {
	Token string `json:"token"`
}

func RegisterHandler(jwtSecret string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req registerRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			WriteError(w, http.StatusBadRequest, "malformed_request", "Request body must be valid JSON.")
			return
		}

		req.DeviceID = strings.TrimSpace(req.DeviceID)
		if req.DeviceID == "" {
			WriteError(w, http.StatusBadRequest, "missing_device_id", "deviceId is required.")
			return
		}

		token, err := auth.CreateToken(jwtSecret, req.DeviceID, "free", nil)
		if err != nil {
			WriteError(w, http.StatusServiceUnavailable, "internal_error", "Failed to create token.")
			return
		}

		WriteJSON(w, http.StatusOK, tokenResponse{Token: token})
	}
}

func RefreshHandler(jwtSecret string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		claims, ok := middleware.ClaimsFromContext(r.Context())
		if !ok {
			WriteError(w, http.StatusUnauthorized, "invalid_jwt", "Authentication required.")
			return
		}

		token, err := auth.CreateToken(jwtSecret, claims.DeviceID, claims.Tier, claims.UserID)
		if err != nil {
			WriteError(w, http.StatusServiceUnavailable, "internal_error", "Failed to refresh token.")
			return
		}

		WriteJSON(w, http.StatusOK, tokenResponse{Token: token})
	}
}
