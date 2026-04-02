package handlers

import (
	"compress/flate"
	"compress/gzip"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"strings"

	"github.com/ducdo/sprinty/server/appstore"
	"github.com/ducdo/sprinty/server/auth"
	"github.com/ducdo/sprinty/server/middleware"
)

type registerRequest struct {
	DeviceID      string  `json:"deviceId"`
	TransactionID *uint64 `json:"transactionId,omitempty"`
}

type refreshRequest struct {
	TransactionID *uint64 `json:"transactionId,omitempty"`
}

type tokenResponse struct {
	Token string `json:"token"`
}

func RegisterHandler(jwtSecret string, appStoreClient *appstore.Client) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		body := decompressBody(w, r)
		if body == nil {
			return
		}
		defer body.Close()

		var req registerRequest
		if err := json.NewDecoder(body).Decode(&req); err != nil {
			WriteError(w, http.StatusBadRequest, "malformed_request", "Request body must be valid JSON.")
			return
		}

		req.DeviceID = strings.TrimSpace(req.DeviceID)
		if req.DeviceID == "" {
			WriteError(w, http.StatusBadRequest, "missing_device_id", "deviceId is required.")
			return
		}

		tier := "free"
		if req.TransactionID != nil && appStoreClient != nil {
			validatedTier, err := appStoreClient.ValidateTransaction(*req.TransactionID)
			if err != nil {
				slog.Warn("appstore.validation_failed", "error", err, "transactionId", *req.TransactionID)
				// Fail-open: keep free tier
			} else {
				tier = validatedTier
			}
		}

		token, err := auth.CreateToken(jwtSecret, req.DeviceID, tier, nil)
		if err != nil {
			WriteError(w, http.StatusServiceUnavailable, "internal_error", "Failed to create token.")
			return
		}

		WriteJSON(w, http.StatusOK, tokenResponse{Token: token})
	}
}

func RefreshHandler(jwtSecret string, appStoreClient *appstore.Client) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		claims, ok := middleware.ClaimsFromContext(r.Context())
		if !ok {
			WriteError(w, http.StatusUnauthorized, "invalid_jwt", "Authentication required.")
			return
		}

		tier := claims.Tier

		if r.ContentLength > 0 {
			body := decompressBody(w, r)
			if body == nil {
				return
			}
			defer body.Close()

			var req refreshRequest
			if err := json.NewDecoder(body).Decode(&req); err == nil && req.TransactionID != nil && appStoreClient != nil {
				validatedTier, err := appStoreClient.ValidateTransaction(*req.TransactionID)
				if err != nil {
					slog.Warn("appstore.validation_failed", "error", err, "transactionId", *req.TransactionID)
					// Fail-open: keep existing tier from claims
				} else {
					tier = validatedTier
				}
			}
			// When appStoreClient is nil (dev mode), existing tier from claims is preserved
		}

		token, err := auth.CreateToken(jwtSecret, claims.DeviceID, tier, claims.UserID)
		if err != nil {
			WriteError(w, http.StatusServiceUnavailable, "internal_error", "Failed to refresh token.")
			return
		}

		WriteJSON(w, http.StatusOK, tokenResponse{Token: token})
	}
}

// decompressBody handles gzip/deflate Content-Encoding.
// Returns nil and writes error response if decompression fails.
// Caller must defer body.Close() on the returned ReadCloser.
func decompressBody(w http.ResponseWriter, r *http.Request) io.ReadCloser {
	switch r.Header.Get("Content-Encoding") {
	case "gzip":
		gr, err := gzip.NewReader(r.Body)
		if err != nil {
			WriteError(w, http.StatusBadRequest, "malformed_request", "Invalid gzip encoding.")
			return nil
		}
		return gr
	case "deflate":
		return flate.NewReader(r.Body)
	}
	return r.Body
}
