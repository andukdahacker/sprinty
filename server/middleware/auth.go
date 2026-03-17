package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/ducdo/ai-life-coach/server/auth"
	"github.com/ducdo/ai-life-coach/server/httputil"
)

type contextKey string

const claimsKey contextKey = "claims"

func ClaimsFromContext(ctx context.Context) (*auth.Claims, bool) {
	claims, ok := ctx.Value(claimsKey).(*auth.Claims)
	return claims, ok
}

func AuthMiddleware(jwtSecret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := r.Header.Get("Authorization")
			if header == "" {
				httputil.WriteError(w, http.StatusUnauthorized, "invalid_jwt", "Authentication required.")
				return
			}

			parts := strings.SplitN(header, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
				httputil.WriteError(w, http.StatusUnauthorized, "invalid_jwt", "Malformed authorization header.")
				return
			}

			claims, err := auth.ValidateToken(jwtSecret, parts[1])
			if err != nil {
				errMsg := err.Error()
				if strings.Contains(errMsg, "expired") {
					httputil.WriteError(w, http.StatusUnauthorized, "token_expired", "Your session has expired. Please reconnect.")
				} else {
					httputil.WriteError(w, http.StatusUnauthorized, "invalid_jwt", "Invalid authentication token.")
				}
				return
			}

			// Populate logging fields for the outer logging middleware
			if logFields := LogFieldsFromContext(r.Context()); logFields != nil {
				logFields.DeviceID = claims.DeviceID
			}

			ctx := context.WithValue(r.Context(), claimsKey, claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
