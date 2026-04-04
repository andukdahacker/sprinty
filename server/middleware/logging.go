package middleware

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/ducdo/sprinty/server/metrics"
)

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

// LogFields holds mutable fields that inner middleware can populate for logging.
type LogFields struct {
	DeviceID          string
	Tier              string
	Provider          string
	SafetyLevel       string
	Mode              string
	FailoverOccurred  bool
}

type logFieldsKeyType string

const logFieldsKey logFieldsKeyType = "logFields"

// LogFieldsFromContext retrieves the shared LogFields from the request context.
func LogFieldsFromContext(ctx context.Context) *LogFields {
	if fields, ok := ctx.Value(logFieldsKey).(*LogFields); ok {
		return fields
	}
	return nil
}

func LoggingMiddleware(collector *metrics.Collector) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()

			// Store mutable LogFields in context for inner middleware to populate.
			fields := &LogFields{}
			r = r.WithContext(context.WithValue(r.Context(), logFieldsKey, fields))

			slog.Info("request started",
				"method", r.Method,
				"path", r.URL.Path,
			)

			rw := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
			next.ServeHTTP(rw, r)

			duration := time.Since(start)
			durationMs := float64(duration.Milliseconds())
			attrs := []any{
				"method", r.Method,
				"path", r.URL.Path,
				"status", rw.statusCode,
				"duration_ms", durationMs,
			}

			if fields.DeviceID != "" {
				attrs = append(attrs, "deviceId", fields.DeviceID)
			}
			if fields.Tier != "" {
				attrs = append(attrs, "tier", fields.Tier)
			}
			if fields.Provider != "" {
				attrs = append(attrs, "provider", fields.Provider)
			}
			if fields.Mode != "" {
				attrs = append(attrs, "mode", fields.Mode)
			}
			if fields.SafetyLevel != "" {
				attrs = append(attrs, "safetyLevel", fields.SafetyLevel)
			}
			if fields.FailoverOccurred {
				attrs = append(attrs, "failoverOccurred", true)
			}

			if rw.statusCode >= 400 {
				slog.Warn("request completed", attrs...)
			} else {
				slog.Info("request completed", attrs...)
			}

			// Record metrics if collector is available
			if collector != nil && fields.Provider != "" {
				collector.RecordRequest(fields.Provider, fields.Tier, rw.statusCode, durationMs, fields.SafetyLevel)
			}
		})
	}
}
