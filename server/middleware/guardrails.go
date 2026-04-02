package middleware

import (
	"context"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"github.com/ducdo/sprinty/server/config"
)

const guardrailKey contextKey = "guardrailActive"

// GuardrailActiveFromContext returns whether the guardrail is active for this request.
func GuardrailActiveFromContext(ctx context.Context) bool {
	active, _ := ctx.Value(guardrailKey).(bool)
	return active
}

// SessionTracker tracks per-device session counts in memory using filter-on-access
// to only count timestamps from the current UTC day.
type SessionTracker struct {
	mu       sync.RWMutex
	sessions map[string][]time.Time
}

// NewSessionTracker creates a new in-memory session tracker.
func NewSessionTracker() *SessionTracker {
	return &SessionTracker{
		sessions: make(map[string][]time.Time),
	}
}

// Count returns the number of sessions for the given deviceID today (UTC).
func (st *SessionTracker) Count(deviceID string) int {
	st.mu.RLock()
	defer st.mu.RUnlock()

	timestamps := st.sessions[deviceID]
	today := todayUTC()
	count := 0
	for _, ts := range timestamps {
		if sameUTCDay(ts, today) {
			count++
		}
	}
	return count
}

// RecordSession appends a new session timestamp for the given deviceID
// and filters out stale (non-today) entries.
func (st *SessionTracker) RecordSession(deviceID string) {
	st.mu.Lock()
	defer st.mu.Unlock()

	now := time.Now().UTC()
	today := todayUTC()

	// Filter to today's entries only (lazy cleanup)
	existing := st.sessions[deviceID]
	filtered := make([]time.Time, 0, len(existing))
	for _, ts := range existing {
		if sameUTCDay(ts, today) {
			filtered = append(filtered, ts)
		}
	}
	filtered = append(filtered, now)
	st.sessions[deviceID] = filtered
}

func todayUTC() time.Time {
	now := time.Now().UTC()
	return time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
}

func sameUTCDay(ts, today time.Time) bool {
	y, m, d := ts.UTC().Date()
	ty, tm, td := today.Date()
	return y == ty && m == tm && d == td
}

// GuardrailsMiddleware checks per-device session count and sets a guardrail
// context flag if the daily limit is reached. Never blocks requests.
func GuardrailsMiddleware(tracker *SessionTracker, cfg *config.Config) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := ClaimsFromContext(r.Context())
			if !ok {
				// No claims — pass through (should not happen behind auth middleware)
				next.ServeHTTP(w, r)
				return
			}

			deviceID := claims.DeviceID
			tier := claims.Tier
			if tier == "" {
				tier = "free"
			}

			// Determine limit for this tier
			limit := cfg.FreeTierDailySessionLimit
			if tier == "premium" {
				limit = cfg.PremiumTierDailySessionLimit
			}

			count := tracker.Count(deviceID)

			if limit == 0 || count < limit {
				// Under limit or unlimited — record session and pass through
				tracker.RecordSession(deviceID)
				next.ServeHTTP(w, r)
				return
			}

			// Limit reached — set guardrail flag, do NOT record additional session
			slog.Info("guardrail.activated", "deviceId", deviceID, "tier", tier, "sessionCount", count)

			ctx := context.WithValue(r.Context(), guardrailKey, true)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
